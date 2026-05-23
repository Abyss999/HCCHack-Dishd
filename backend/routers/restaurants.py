import asyncio
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status

from config import get_settings
from deps import get_current_user
from models.restaurant import Restaurant
from models.user import User
from schemas.personalized_fit import PersonalizedFitOut
from schemas.restaurant import RestaurantOut
from security import limiter
from services.gemini_service import GeminiService, get_gemini_service
from services.places_service import GroupFilter, PRICE_LEVEL_BY_TIER, PlacesService, get_places_service
from services.session_service import SessionService, get_session_service

# Houston metro bounding box — sessions inside this box serve the curated seed
# instead of hitting Google Places. Tight enough to keep Dallas / Austin / San
# Antonio out, loose enough to cover Galleria, Heights, Montrose, Midtown, EaDo,
# Museum District, Bellaire, Sugar Land.
_HOUSTON_BBOX = (29.55, -95.65, 29.95, -95.10)  # (min_lat, min_lng, max_lat, max_lng)


def _in_houston(lat: float, lng: float) -> bool:
    return _HOUSTON_BBOX[0] <= lat <= _HOUSTON_BBOX[2] and _HOUSTON_BBOX[1] <= lng <= _HOUSTON_BBOX[3]

router = APIRouter(prefix="/restaurants", tags=["restaurants"])
_settings = get_settings()

_MOCK_RESTAURANTS = [
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000001"), google_place_id="mock_1", name="Joe's Pizza", cuisine_tags=["italian","pizza"], price_tier="$", rating=4.7, photo_url=None, address="7 Carmine St, New York, NY", lat=40.7301, lng=-74.0023, description=None),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000002"), google_place_id="mock_2", name="Xi'an Famous Foods", cuisine_tags=["chinese","noodles"], price_tier="$", rating=4.5, photo_url=None, address="81 St Marks Pl, New York, NY", lat=40.7282, lng=-73.9842, description=None),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000003"), google_place_id="mock_3", name="Katz's Delicatessen", cuisine_tags=["deli","american"], price_tier="$$", rating=4.4, photo_url=None, address="205 E Houston St, New York, NY", lat=40.7223, lng=-73.9873, description=None),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000004"), google_place_id="mock_4", name="Shake Shack", cuisine_tags=["burgers","american"], price_tier="$$", rating=4.3, photo_url=None, address="Madison Square Park, New York, NY", lat=40.7408, lng=-73.9882, description=None),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000005"), google_place_id="mock_5", name="Momofuku Noodle Bar", cuisine_tags=["japanese","ramen"], price_tier="$$", rating=4.4, photo_url=None, address="171 1st Ave, New York, NY", lat=40.7267, lng=-73.9815, description=None),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000006"), google_place_id="mock_6", name="Tacombi", cuisine_tags=["mexican","tacos"], price_tier="$$", rating=4.3, photo_url=None, address="267 Elizabeth St, New York, NY", lat=40.7241, lng=-73.9948, description=None),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000007"), google_place_id="mock_7", name="Gramercy Tavern", cuisine_tags=["american","fine dining"], price_tier="$$$$", rating=4.6, photo_url=None, address="42 E 20th St, New York, NY", lat=40.7386, lng=-73.9886, description=None),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000008"), google_place_id="mock_8", name="Sushi Nakazawa", cuisine_tags=["japanese","sushi"], price_tier="$$$$", rating=4.7, photo_url=None, address="23 Commerce St, New York, NY", lat=40.7302, lng=-74.0031, description=None),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000009"), google_place_id="mock_9", name="Roberta's Pizza", cuisine_tags=["italian","pizza"], price_tier="$$", rating=4.5, photo_url=None, address="261 Moore St, Brooklyn, NY", lat=40.7054, lng=-73.9334, description=None),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000010"), google_place_id="mock_10", name="The Halal Guys", cuisine_tags=["middle eastern","halal"], price_tier="$", rating=4.2, photo_url=None, address="W 53rd St & 6th Ave, New York, NY", lat=40.7614, lng=-73.9797, description=None),
]


async def _ensure_mocks_persisted() -> None:
    """Upsert mock restaurants so swipe endpoint can look them up by ID."""
    for r in _MOCK_RESTAURANTS:
        existing = await Restaurant.find_one(Restaurant.id == r.id)
        if existing is None:
            await Restaurant(
                id=r.id,
                google_place_id=r.google_place_id,
                name=r.name,
                cuisine_tags=r.cuisine_tags,
                price_tier=r.price_tier,
                rating=r.rating,
                photo_url=r.photo_url,
                address=r.address,
                lat=r.lat,
                lng=r.lng,
            ).insert()


def _apply_overrides_to_seed(
    rows: list[Restaurant], session
) -> list[Restaurant]:
    """Filter seeded restaurants by cuisine/budget overrides on the session.
    Budget is treated as a ceiling — a $$ budget shows $, $$ but not $$$.
    Keeps rows with unknown price_tier so the stack never empties."""
    cuisines = [c.lower() for c in (session.cuisine_overrides or [])]
    budget_overrides = session.budget_overrides or []
    max_price_level = (
        max(PRICE_LEVEL_BY_TIER[b] for b in budget_overrides if b in PRICE_LEVEL_BY_TIER)
        if budget_overrides else None
    )

    out = []
    for r in rows:
        if cuisines:
            tags = {t.lower() for t in r.cuisine_tags}
            if not any(c in tags or any(c in t for t in tags) for c in cuisines):
                continue
        if max_price_level is not None and r.price_tier is not None:
            if PRICE_LEVEL_BY_TIER.get(r.price_tier, 0) > max_price_level:
                continue
        out.append(r)
    return out


@router.get("", response_model=list[RestaurantOut])
@limiter.limit(_settings.rate_limit_restaurants)
async def list_restaurants(
    request: Request,
    response: Response,
    session_id: UUID,
    mock: bool = False,
    current: User = Depends(get_current_user),
    sessions: SessionService = Depends(get_session_service),
    places: PlacesService = Depends(get_places_service),
) -> list[RestaurantOut]:
    session = await sessions.get_by_id(session_id)
    if not sessions.is_member(session, current.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a session member")

    if mock or _settings.use_mock_restaurants or not _settings.google_places_api_key:
        await _ensure_mocks_persisted()
        return _MOCK_RESTAURANTS

    if session.location_lat is None or session.location_lng is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session has no location set",
        )

    # Demo path: when the session is inside the Houston bounding box, serve the
    # curated seed (is_seed=True) and skip Google Places entirely. Scoped to seed
    # rows so it cannot accidentally serve Google-upserted restaurants from another
    # session in a nearby city.
    if _in_houston(session.location_lat, session.location_lng):
        seeded = await Restaurant.find(Restaurant.is_seed == True).to_list()  # noqa: E712
        filtered = _apply_overrides_to_seed(seeded, session)
        if filtered:
            return [RestaurantOut(**r.model_dump()) for r in filtered]
        # If overrides filtered everything out, fall back to the full seed rather
        # than going to Google — the user picked Houston, they want Houston.
        if seeded:
            return [RestaurantOut(**r.model_dump()) for r in seeded]

    # Override branch fires when ANY override is set (cuisine, radius, or budgets).
    has_overrides = (
        session.cuisine_overrides is not None
        or session.radius_km_override is not None
        or session.budget_overrides is not None
    )
    if has_overrides:
        radius_m = max(500, int((session.radius_km_override or 10.0) * 1000))
        budget_levels = (
            sorted({PRICE_LEVEL_BY_TIER[b] for b in session.budget_overrides if b in PRICE_LEVEL_BY_TIER})
            if session.budget_overrides else []
        )
        group_filter = GroupFilter(
            radius_m=radius_m,
            cuisines=session.cuisine_overrides or [],
            dietary_restrictions=[],
            max_price_level=max(budget_levels) if budget_levels else None,
        )
    else:
        member_users = await asyncio.gather(*(User.get(m.user_id) for m in session.members))
        prefs = [u.preferences for u in member_users if u is not None]
        group_filter = places.derive_group_filter(prefs)
        budget_levels = []

    restaurants = await places.nearby_search(
        session.location_lat,
        session.location_lng,
        group_filter,
    )

    if budget_levels:
        ceiling = max(budget_levels)
        restaurants = [
            r for r in restaurants
            if r.price_tier is None or PRICE_LEVEL_BY_TIER.get(r.price_tier, 0) <= ceiling
        ]

    return [RestaurantOut(**r.model_dump()) for r in restaurants]


@router.get("/{restaurant_id}/personalized-fit", response_model=PersonalizedFitOut)
async def personalized_fit(
    restaurant_id: UUID,
    session_id: UUID,
    current: User = Depends(get_current_user),
    sessions: SessionService = Depends(get_session_service),
    gemini: GeminiService = Depends(get_gemini_service),
) -> PersonalizedFitOut:
    """Houston-only. Returns a Gemini-powered 'why this fits you' for one restaurant.
    Returns 404 for non-seed restaurants so iOS can silently skip the section."""
    session = await sessions.get_by_id(session_id)
    if not sessions.is_member(session, current.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a session member")

    restaurant = await Restaurant.get(restaurant_id)
    if restaurant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Restaurant not found")

    if not restaurant.is_seed:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not a Houston seed restaurant")

    result = await gemini.personalized_fit(restaurant, current)
    return PersonalizedFitOut(**result)

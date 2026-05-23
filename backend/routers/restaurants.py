import asyncio
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status

from config import get_settings
from deps import get_current_user
from models.restaurant import Restaurant
from models.user import User
from schemas.restaurant import RestaurantOut
from security import limiter
from services.places_service import GroupFilter, PRICE_LEVEL_BY_TIER, PlacesService, get_places_service
from services.session_service import SessionService, get_session_service

router = APIRouter(prefix="/restaurants", tags=["restaurants"])
_settings = get_settings()

_MOCK_RESTAURANTS = [
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000001"), google_place_id="mock_1", name="Joe's Pizza", cuisine_tags=["italian","pizza"], price_tier="$", rating=4.7, photo_url=None, address="7 Carmine St, New York, NY", lat=40.7301, lng=-74.0023),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000002"), google_place_id="mock_2", name="Xi'an Famous Foods", cuisine_tags=["chinese","noodles"], price_tier="$", rating=4.5, photo_url=None, address="81 St Marks Pl, New York, NY", lat=40.7282, lng=-73.9842),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000003"), google_place_id="mock_3", name="Katz's Delicatessen", cuisine_tags=["deli","american"], price_tier="$$", rating=4.4, photo_url=None, address="205 E Houston St, New York, NY", lat=40.7223, lng=-73.9873),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000004"), google_place_id="mock_4", name="Shake Shack", cuisine_tags=["burgers","american"], price_tier="$$", rating=4.3, photo_url=None, address="Madison Square Park, New York, NY", lat=40.7408, lng=-73.9882),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000005"), google_place_id="mock_5", name="Momofuku Noodle Bar", cuisine_tags=["japanese","ramen"], price_tier="$$", rating=4.4, photo_url=None, address="171 1st Ave, New York, NY", lat=40.7267, lng=-73.9815),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000006"), google_place_id="mock_6", name="Tacombi", cuisine_tags=["mexican","tacos"], price_tier="$$", rating=4.3, photo_url=None, address="267 Elizabeth St, New York, NY", lat=40.7241, lng=-73.9948),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000007"), google_place_id="mock_7", name="Gramercy Tavern", cuisine_tags=["american","fine dining"], price_tier="$$$$", rating=4.6, photo_url=None, address="42 E 20th St, New York, NY", lat=40.7386, lng=-73.9886),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000008"), google_place_id="mock_8", name="Sushi Nakazawa", cuisine_tags=["japanese","sushi"], price_tier="$$$$", rating=4.7, photo_url=None, address="23 Commerce St, New York, NY", lat=40.7302, lng=-74.0031),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000009"), google_place_id="mock_9", name="Roberta's Pizza", cuisine_tags=["italian","pizza"], price_tier="$$", rating=4.5, photo_url=None, address="261 Moore St, Brooklyn, NY", lat=40.7054, lng=-73.9334),
    RestaurantOut(id=UUID("a1000000-0000-0000-0000-000000000010"), google_place_id="mock_10", name="The Halal Guys", cuisine_tags=["middle eastern","halal"], price_tier="$", rating=4.2, photo_url=None, address="W 53rd St & 6th Ave, New York, NY", lat=40.7614, lng=-73.9797),
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
        # Google Places takes minprice/maxprice as a range. We narrow the API call to that
        # range, then post-filter to the EXACT set of selected tiers.
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

    # Exact-tier post-filter: only keep restaurants whose price_tier is one the user picked.
    # We don't drop unknown-price restaurants — Google often returns them without price_level,
    # and excluding them would empty the stack in many neighborhoods.
    if budget_levels:
        allowed_tiers = {b for b in (session.budget_overrides or [])}
        restaurants = [
            r for r in restaurants
            if r.price_tier is None or r.price_tier in allowed_tiers
        ]

    return [RestaurantOut(**r.model_dump()) for r in restaurants]

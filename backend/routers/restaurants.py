from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from deps import get_current_user
from models.user import User
from schemas.restaurant import RestaurantOut
from services.places_service import PlacesService, get_places_service
from services.session_service import SessionService, get_session_service

router = APIRouter(prefix="/restaurants", tags=["restaurants"])


@router.get("", response_model=list[RestaurantOut])
async def list_restaurants(
    session_id: UUID,
    current: User = Depends(get_current_user),
    sessions: SessionService = Depends(get_session_service),
    places: PlacesService = Depends(get_places_service),
) -> list[RestaurantOut]:
    session = await sessions.get_by_id(session_id)
    if not sessions.is_member(session, current.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a session member")
    if session.location_lat is None or session.location_lng is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session has no location set",
        )

    member_users = [await User.get(m.user_id) for m in session.members]
    prefs = [u.preferences for u in member_users if u is not None]
    group_filter = places.derive_group_filter(prefs)

    restaurants = await places.nearby_search(
        session.location_lat,
        session.location_lng,
        group_filter,
    )
    return [RestaurantOut(**r.model_dump()) for r in restaurants]

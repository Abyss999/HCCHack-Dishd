from fastapi import APIRouter, Depends, status

from deps import get_current_user
from models.user import User
from schemas.user import PreferencesUpdate, PushTokenIn, UserMe
from services.user_service import UserService, get_user_service

router = APIRouter(prefix="/users", tags=["users"])


def _to_me(user: User) -> UserMe:
    return UserMe(
        id=user.id,
        email=user.email,
        name=user.name,
        preferences=user.preferences.model_dump(),
        created_at=user.created_at,
    )


@router.get("/me", response_model=UserMe)
async def get_me(current: User = Depends(get_current_user)) -> UserMe:
    return _to_me(current)


@router.put("/me/preferences", response_model=UserMe)
async def update_preferences(
    patch: PreferencesUpdate,
    current: User = Depends(get_current_user),
    users: UserService = Depends(get_user_service),
) -> UserMe:
    updated = await users.update_preferences(current, patch)
    return _to_me(updated)


@router.post("/me/push-token", status_code=status.HTTP_204_NO_CONTENT)
async def add_push_token(
    payload: PushTokenIn,
    current: User = Depends(get_current_user),
    users: UserService = Depends(get_user_service),
) -> None:
    await users.add_push_token(current, payload)

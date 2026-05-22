from fastapi import APIRouter, Depends, status

from schemas.auth import RefreshRequest, TokenResponse, UserCreate, UserLogin
from services.auth_service import AuthService, get_auth_service

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def signup(
    data: UserCreate,
    auth: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    _, tokens = await auth.signup(data)
    return tokens


@router.post("/login", response_model=TokenResponse)
async def login(
    data: UserLogin,
    auth: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    _, tokens = await auth.login(data)
    return tokens


@router.post("/refresh", response_model=TokenResponse)
async def refresh(
    data: RefreshRequest,
    auth: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    return await auth.refresh(data.refresh_token)

from fastapi import APIRouter, Depends, Request, Response, status

from config import get_settings
from schemas.auth import AppleAuthRequest, RefreshRequest, TokenResponse, UserCreate, UserLogin
from security import limiter
from services.auth_service import AuthService, get_auth_service

router = APIRouter(prefix="/auth", tags=["auth"])
_settings = get_settings()


@router.post("/signup", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit(_settings.rate_limit_signup)
async def signup(
    request: Request,
    response: Response,
    data: UserCreate,
    auth: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    _, tokens = await auth.signup(data)
    return tokens


@router.post("/login", response_model=TokenResponse)
@limiter.limit(_settings.rate_limit_login)
async def login(
    request: Request,
    response: Response,
    data: UserLogin,
    auth: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    _, tokens = await auth.login(data)
    return tokens


@router.post("/apple", response_model=TokenResponse)
@limiter.limit(_settings.rate_limit_login)
async def apple_auth(
    request: Request,
    response: Response,
    data: AppleAuthRequest,
    auth: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    _, tokens = await auth.apple_login(data)
    return tokens


@router.post("/refresh", response_model=TokenResponse)
@limiter.limit(_settings.rate_limit_refresh)
async def refresh(
    request: Request,
    response: Response,
    data: RefreshRequest,
    auth: AuthService = Depends(get_auth_service),
) -> TokenResponse:
    return await auth.refresh(data.refresh_token)

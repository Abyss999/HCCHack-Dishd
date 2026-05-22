from datetime import datetime, timedelta, timezone
from typing import Literal
from uuid import UUID

from fastapi import HTTPException, status
from jose import JWTError, jwt
from passlib.context import CryptContext

from config import Settings, get_settings
from models.user import User
from schemas.auth import TokenResponse, UserCreate, UserLogin

TokenType = Literal["access", "refresh"]


class AuthService:
    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()
        self.pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

    # ----- password hashing -----

    def hash_password(self, password: str) -> str:
        return self.pwd_context.hash(password)

    def verify_password(self, password: str, password_hash: str) -> bool:
        return self.pwd_context.verify(password, password_hash)

    # ----- JWT -----

    def _create_token(self, user_id: UUID, token_type: TokenType, expires_delta: timedelta) -> str:
        now = datetime.now(timezone.utc)
        payload = {
            "sub": str(user_id),
            "type": token_type,
            "iat": int(now.timestamp()),
            "exp": int((now + expires_delta).timestamp()),
        }
        return jwt.encode(payload, self.settings.jwt_secret, algorithm=self.settings.jwt_algorithm)

    def create_access_token(self, user_id: UUID) -> str:
        return self._create_token(
            user_id,
            "access",
            timedelta(minutes=self.settings.access_token_expire_minutes),
        )

    def create_refresh_token(self, user_id: UUID) -> str:
        return self._create_token(
            user_id,
            "refresh",
            timedelta(days=self.settings.refresh_token_expire_days),
        )

    def decode_token(self, token: str, expected_type: TokenType) -> UUID:
        try:
            payload = jwt.decode(
                token,
                self.settings.jwt_secret,
                algorithms=[self.settings.jwt_algorithm],
            )
        except JWTError as exc:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token",
            ) from exc

        if payload.get("type") != expected_type:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Expected {expected_type} token",
            )

        sub = payload.get("sub")
        if not sub:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token missing subject",
            )
        return UUID(sub)

    def _issue_token_pair(self, user_id: UUID) -> TokenResponse:
        return TokenResponse(
            access_token=self.create_access_token(user_id),
            refresh_token=self.create_refresh_token(user_id),
        )

    # ----- auth flows -----

    async def signup(self, data: UserCreate) -> tuple[User, TokenResponse]:
        existing = await User.find_one(User.email == data.email)
        if existing is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Email already registered",
            )
        user = User(
            email=data.email,
            password_hash=self.hash_password(data.password),
            name=data.name,
        )
        await user.insert()
        return user, self._issue_token_pair(user.id)

    async def login(self, data: UserLogin) -> tuple[User, TokenResponse]:
        user = await User.find_one(User.email == data.email)
        if user is None or not self.verify_password(data.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
            )
        return user, self._issue_token_pair(user.id)

    async def refresh(self, refresh_token: str) -> TokenResponse:
        user_id = self.decode_token(refresh_token, expected_type="refresh")
        user = await User.get(user_id)
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User no longer exists",
            )
        return self._issue_token_pair(user.id)


def get_auth_service() -> AuthService:
    return AuthService()

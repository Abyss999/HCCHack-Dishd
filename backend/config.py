from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Runtime
    environment: Literal["development", "staging", "production"] = "development"

    # Mongo
    # Set MONGO_TARGET=atlas to use Atlas, MONGO_TARGET=local (default) for Docker.
    mongo_target: Literal["local", "atlas"] = "local"
    mongo_url_local: str = "mongodb://localhost:27017"
    mongo_url_atlas: str = ""
    mongo_db_name: str = "dishmatch"

    @property
    def mongo_url(self) -> str:
        if self.mongo_target == "atlas":
            if not self.mongo_url_atlas:
                raise ValueError("MONGO_TARGET=atlas but MONGO_URL_ATLAS is not set")
            return self.mongo_url_atlas
        return self.mongo_url_local

    # JWT
    jwt_secret: str = "change-me-in-env"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 30

    # Third-party
    google_places_api_key: str | None = None
    use_mock_restaurants: bool = False
    expo_push_url: str = "https://exp.host/--/api/v2/push/send"

    # HTTP / CORS
    cors_origins: list[str] = ["*"]
    allowed_hosts: list[str] = ["*"]
    max_request_body_bytes: int = 1_000_000  # 1 MB

    # Rate limits — slowapi-format strings, e.g. "5/minute" or "10/30seconds".
    rate_limit_enabled: bool = True
    rate_limit_default: str = "100/minute"
    rate_limit_signup: str = "5/minute"
    rate_limit_login: str = "10/minute"
    rate_limit_refresh: str = "30/minute"
    rate_limit_session_create: str = "10/minute"
    rate_limit_session_join: str = "20/minute"
    rate_limit_swipe: str = "60/minute"
    rate_limit_restaurants: str = "20/minute"
    rate_limit_push_token: str = "10/minute"

    # Domain limits
    max_session_members: int = 12

    # Apple Sign In
    apple_bundle_id: str = "com.dishmatch.app"

    @property
    def cors_allow_credentials(self) -> bool:
        # Browsers reject credentials=True with wildcard origins per CORS spec.
        return "*" not in self.cors_origins


@lru_cache
def get_settings() -> Settings:
    return Settings()

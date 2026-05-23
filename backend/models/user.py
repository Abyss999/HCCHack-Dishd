from datetime import datetime, timezone
from typing import Literal
from uuid import UUID, uuid4

from beanie import Document
from pydantic import BaseModel, EmailStr, Field
from pymongo import IndexModel


class UserPreferences(BaseModel):
    dietary_restrictions: list[str] = Field(default_factory=list)
    cuisine_preferences: list[str] = Field(default_factory=list)
    budget_ranges: list[str] = Field(default_factory=list)
    max_distance_km: float = 10.0


class PushToken(BaseModel):
    token: str
    platform: Literal["ios", "android"]


class User(Document):
    id: UUID = Field(default_factory=uuid4)
    email: EmailStr
    password_hash: str | None = None
    name: str
    apple_id: str | None = None
    preferences: UserPreferences = Field(default_factory=UserPreferences)
    push_tokens: list[PushToken] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "users"
        indexes = [
            IndexModel("email", unique=True),
            # apple_id sparse unique index is managed manually in database._fix_indexes
            # because Beanie strips the sparse option when building the createIndex command.
        ]

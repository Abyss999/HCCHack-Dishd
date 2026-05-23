from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class PreferencesUpdate(BaseModel):
    dietary_restrictions: list[str] | None = Field(default=None, max_length=20)
    cuisine_preferences: list[str] | None = Field(default=None, max_length=20)
    budget_ranges: list[str] | None = Field(default=None, max_length=4)
    max_distance_km: float | None = Field(default=None, gt=0, le=200)


class PreferencesOut(BaseModel):
    dietary_restrictions: list[str]
    cuisine_preferences: list[str]
    budget_ranges: list[str]
    max_distance_km: float


class PushTokenIn(BaseModel):
    token: str = Field(min_length=1, max_length=512)
    platform: Literal["ios", "android"]


class UserMe(BaseModel):
    id: UUID
    email: EmailStr
    name: str
    preferences: PreferencesOut
    created_at: datetime

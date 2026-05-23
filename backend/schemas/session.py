from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field

SessionStatus = Literal["lobby", "swiping", "results", "matched"]


class SessionCreate(BaseModel):
    location_lat: float | None = Field(default=None, ge=-90, le=90)
    location_lng: float | None = Field(default=None, ge=-180, le=180)
    location_label: str | None = Field(default=None, max_length=120)
    solo_mode: bool = False
    cuisine_overrides: list[str] | None = Field(default=None, max_length=20)
    radius_km_override: float | None = Field(default=None, gt=0, le=100)
    budget_overrides: list[Literal["$", "$$", "$$$", "$$$$"]] | None = Field(default=None, max_length=4)
    swipe_ceiling_override: int | None = Field(default=None, ge=3, le=30)


class MemberOut(BaseModel):
    user_id: UUID
    name: str
    joined_at: datetime


class SessionOut(BaseModel):
    id: UUID
    code: str
    host_user_id: UUID
    status: SessionStatus
    location_lat: float | None
    location_lng: float | None
    location_label: str | None
    members: list[MemberOut]
    matched_restaurant_id: UUID | None
    solo_mode: bool
    cuisine_overrides: list[str] | None = None
    radius_km_override: float | None = None
    budget_overrides: list[Literal["$", "$$", "$$$", "$$$$"]] | None = None
    swipe_ceiling_override: int | None = None
    created_at: datetime

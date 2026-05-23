from datetime import datetime, timezone
from typing import Literal
from uuid import UUID, uuid4

from beanie import Document
from pydantic import BaseModel, Field
from pymongo import IndexModel

SessionStatus = Literal["lobby", "swiping", "results", "matched"]


class SessionMember(BaseModel):
    user_id: UUID
    name: str
    joined_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class Session(Document):
    id: UUID = Field(default_factory=uuid4)
    code: str
    host_user_id: UUID
    status: SessionStatus = "lobby"
    location_lat: float | None = None
    location_lng: float | None = None
    location_label: str | None = None
    members: list[SessionMember] = Field(default_factory=list)
    matched_restaurant_id: UUID | None = None
    solo_mode: bool = False
    cuisine_overrides: list[str] | None = None
    radius_km_override: float | None = None
    budget_overrides: list[str] | None = None  # multi-select; e.g. ["$$", "$$$"] → only those tiers
    swipe_ceiling_override: int | None = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "sessions"
        indexes = [IndexModel("code", unique=True)]

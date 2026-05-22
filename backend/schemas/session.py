from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field

SessionStatus = Literal["lobby", "swiping", "results", "matched"]


class SessionCreate(BaseModel):
    location_lat: float | None = Field(default=None, ge=-90, le=90)
    location_lng: float | None = Field(default=None, ge=-180, le=180)
    location_label: str | None = None


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
    created_at: datetime

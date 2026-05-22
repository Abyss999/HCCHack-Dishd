from typing import Literal
from uuid import UUID

from pydantic import BaseModel

from schemas.restaurant import RestaurantOut


class SwipeIn(BaseModel):
    restaurant_id: UUID
    direction: Literal["yes", "no"]


class SwipeProgress(BaseModel):
    user_id: UUID
    swipe_count: int


class SwipeAck(BaseModel):
    accepted: bool
    swipe_count: int
    instant_match: RestaurantOut | None = None


class TopResult(BaseModel):
    restaurant: RestaurantOut
    score_pct: int
    yes_count: int
    total: int


class ResultsOut(BaseModel):
    top: list[TopResult]

from datetime import datetime, timezone
from typing import Literal
from uuid import UUID, uuid4

from beanie import Document
from pydantic import Field
from pymongo import ASCENDING, IndexModel

SwipeDirection = Literal["yes", "no"]


class Swipe(Document):
    id: UUID = Field(default_factory=uuid4)
    session_id: UUID
    user_id: UUID
    restaurant_id: UUID
    direction: SwipeDirection
    swiped_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Settings:
        name = "swipes"
        indexes = [
            IndexModel(
                [
                    ("session_id", ASCENDING),
                    ("user_id", ASCENDING),
                    ("restaurant_id", ASCENDING),
                ],
                unique=True,
                name="uniq_session_user_restaurant",
            ),
            IndexModel(
                [
                    ("session_id", ASCENDING),
                    ("restaurant_id", ASCENDING),
                    ("direction", ASCENDING),
                ],
                name="match_lookup",
            ),
        ]

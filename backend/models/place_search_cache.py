from datetime import datetime, timezone
from uuid import UUID, uuid4

from beanie import Document
from pydantic import Field
from pymongo import IndexModel


class PlaceSearchCache(Document):
    """Memoizes Google Places `nearby_search` results so we don't pay for
    repeat queries with the same effective filter.

    `cache_key` is a stable hash of (rounded lat/lng, radius_m, sorted cuisines,
    max_price_level). `restaurant_ids` is the cached result set — point lookups
    on `Restaurant.get(id)` rehydrate the full documents (which are themselves
    upserted on the cold-path call).

    `expires_at` drives a TTL index so Mongo deletes stale entries automatically.
    """

    id: UUID = Field(default_factory=uuid4)
    cache_key: str
    restaurant_ids: list[UUID] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    expires_at: datetime

    class Settings:
        name = "place_search_caches"
        indexes = [
            IndexModel("cache_key", unique=True),
            IndexModel("expires_at", expireAfterSeconds=0),
        ]

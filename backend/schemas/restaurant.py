from uuid import UUID

from pydantic import BaseModel


class RestaurantOut(BaseModel):
    id: UUID
    google_place_id: str
    name: str
    cuisine_tags: list[str]
    price_tier: str | None
    rating: float | None
    photo_url: str | None
    address: str | None
    lat: float
    lng: float
    description: str | None = None

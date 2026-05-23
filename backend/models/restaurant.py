from typing import Any
from uuid import UUID, uuid4

from beanie import Document
from pydantic import Field, field_validator
from pymongo import IndexModel


class Restaurant(Document):
    id: UUID = Field(default_factory=uuid4)
    google_place_id: str
    name: str
    cuisine_tags: list[str] = Field(default_factory=list)
    price_tier: str | None = None  # "$" | "$$" | "$$$" | "$$$$"
    rating: float | None = None
    photo_url: str | None = None
    address: str | None = None
    lat: float
    lng: float
    description: str | None = None  # editorial_summary from Places Details (cached, single API call)
    reviews: list[str] | None = None          # top 3 review text snippets from Places Details
    vibe_blurb: str | None = None             # Gemini-generated atmosphere summary
    overall_vibe_quotes: list[str] | None = None  # 2-3 short quotes Gemini picks from reviews

    @field_validator("overall_vibe_quotes", "reviews", mode="before")
    @classmethod
    def _coerce_string_list(cls, v: Any) -> Any:
        # Old DB documents stored these as [{"text": "...", "source": "..."}] dicts.
        if isinstance(v, list):
            return [item["text"] if isinstance(item, dict) else item for item in v]
        return v

    class Settings:
        name = "restaurants"
        indexes = [IndexModel("google_place_id", unique=True)]

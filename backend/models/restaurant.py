from uuid import UUID, uuid4

from beanie import Document
from pydantic import Field
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
    menu: list[str] = Field(default_factory=list)
    vibe_blurb: str | None = None
    reviews: list[str] = Field(default_factory=list)  # cached Google Places reviews
    # menu_reviews entries: {"item": str, "quotes": [{"text": str, "source": str}, ...]}
    menu_reviews: list[dict] = Field(default_factory=list)
    # overall_vibe_quotes entries: {"text": str, "source": str}
    overall_vibe_quotes: list[dict] = Field(default_factory=list)
    is_seed: bool = False  # True for hand-curated demo rows; keeps the demo path isolated from Google upserts
    # Keyed by "{user_id}:{prefs_hash}" — cached Gemini personalized-fit results.
    # Value shape matches PersonalizedFitOut schema.
    personalized_fits: dict[str, dict] = Field(default_factory=dict)

    class Settings:
        name = "restaurants"
        indexes = [IndexModel("google_place_id", unique=True)]

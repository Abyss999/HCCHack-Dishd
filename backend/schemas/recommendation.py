from typing import Literal

from pydantic import BaseModel, Field


class RecommendationRequest(BaseModel):
    """Free-form preferences for cold-start (pre-swipe) discovery.

    All fields are optional — the scorer applies whatever signals are present.
    """

    cuisines: list[str] = Field(default_factory=list, max_length=20)
    borough: Literal["Manhattan", "Brooklyn", "Queens", "Bronx", "Staten Island"] | None = None
    min_grade: Literal["A", "B", "C"] = "C"
    limit: int = Field(default=3, ge=1, le=20)


class RecommendedAddress(BaseModel):
    building: str | None = None
    street: str | None = None
    zipcode: str | None = None
    coord: list[float] | None = None


class RecommendedGrade(BaseModel):
    grade: str | None = None
    score: int | None = None


class RecommendationOut(BaseModel):
    restaurant_id: str
    name: str
    cuisine: str
    borough: str
    address: RecommendedAddress
    latest_grade: RecommendedGrade | None = None
    match_score: float

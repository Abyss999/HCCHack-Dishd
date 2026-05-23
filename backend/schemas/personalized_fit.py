from pydantic import BaseModel


class EligibleItem(BaseModel):
    name: str
    tags: list[str]  # e.g. ["vegan", "gluten-free"]
    review_quote: str | None = None
    review_source: str | None = None


class HeadlineQuote(BaseModel):
    text: str
    source: str


class PersonalizedFitOut(BaseModel):
    eligible_items: list[EligibleItem]
    personalized_reason: str
    budget_fit: str  # "match" | "over" | "under" | "unknown"
    headline_quote: HeadlineQuote | None = None

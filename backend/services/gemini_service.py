import json
import logging

import google.generativeai as genai

from config import Settings, get_settings
from models.restaurant import Restaurant
from models.user import User

logger = logging.getLogger(__name__)

_MAX_VIBE_LEN = 120


class GeminiService:
    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()
        self._model = None

    def _get_model(self):
        if self._model is None:
            if not self.settings.gemini_api_key:
                return None
            genai.configure(api_key=self.settings.gemini_api_key)
            self._model = genai.GenerativeModel("gemini-2.5-flash")
        return self._model

    async def generate_vibe_fields(
        self,
        name: str,
        cuisine_tags: list[str],
        description: str | None,
        reviews: list[str] | None,
    ) -> dict:
        """Returns {vibe_blurb, overall_vibe_quotes}. Never raises."""
        model = self._get_model()
        if model is None:
            return {}
        cuisines = ", ".join(cuisine_tags) if cuisine_tags else "various"
        review_block = ""
        if reviews:
            review_block = "\nCustomer reviews:\n" + "\n".join(f'- "{r}"' for r in reviews[:5])
        prompt = f"""Given this restaurant, write a vibe description and extract memorable quotes.

Restaurant: {name}
Cuisine: {cuisines}
Description: {description or "Not available"}{review_block}

Respond with JSON only (no markdown, no backticks):
{{
  "vibe_blurb": "One vivid sentence (max {_MAX_VIBE_LEN} chars) capturing the atmosphere and feel",
  "overall_vibe_quotes": ["short memorable quote from a review", "another short quote"]
}}

If there are no reviews, return an empty array for overall_vibe_quotes."""
        try:
            resp = await model.generate_content_async(prompt)
            text = resp.text.strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            data = json.loads(text)
            vibe = data.get("vibe_blurb") or ""
            if len(vibe) > _MAX_VIBE_LEN:
                vibe = vibe[:_MAX_VIBE_LEN - 1].rsplit(" ", 1)[0] + "…"
            quotes = [q for q in (data.get("overall_vibe_quotes") or []) if isinstance(q, str)]
            return {"vibe_blurb": vibe or None, "overall_vibe_quotes": quotes or None}
        except Exception:
            logger.debug("Gemini vibe generation failed for %s", name, exc_info=True)
            return {}

    async def get_vibe_pick(
        self,
        yes_restaurants: list[Restaurant],
        user: User,
    ) -> dict | None:
        """Returns {restaurant_id: UUID, narrative: str} or None on failure."""
        model = self._get_model()
        if model is None or not yes_restaurants:
            return None
        prefs = user.preferences
        cuisines = ", ".join(prefs.cuisine_preferences) if prefs.cuisine_preferences else "any"
        dietary = ", ".join(prefs.dietary_restrictions) if prefs.dietary_restrictions else "none"
        budget = "/".join(prefs.budget_ranges) if prefs.budget_ranges else "any"

        restaurant_lines = []
        for r in yes_restaurants:
            tags = ", ".join(r.cuisine_tags) if r.cuisine_tags else "various"
            vibe = r.vibe_blurb or r.description or "No description"
            restaurant_lines.append(
                f'- ID: {r.id} | Name: {r.name} | Cuisine: {tags} | Price: {r.price_tier or "?"} | Vibe: {vibe}'
            )
        restaurants_block = "\n".join(restaurant_lines)

        prompt = f"""You are a personalized restaurant advisor. Pick the SINGLE best restaurant for this user.

User preferences:
- Favorite cuisines: {cuisines}
- Dietary restrictions: {dietary}
- Budget: {budget}

Restaurants the user liked (swiped yes on):
{restaurants_block}

Choose the one that best matches their preferences. Respond with JSON only (no markdown, no backticks):
{{"restaurant_id": "<exact UUID from the list above>", "narrative": "2-3 sentence personal explanation of why this is their perfect pick based on their specific preferences"}}"""
        try:
            resp = await model.generate_content_async(prompt)
            text = resp.text.strip()
            if text.startswith("```"):
                text = text.split("```")[1]
                if text.startswith("json"):
                    text = text[4:]
            data = json.loads(text)
            rid_str = data.get("restaurant_id")
            narrative = data.get("narrative", "")
            if not rid_str or not narrative:
                return None
            # Validate the returned ID is actually in our list
            from uuid import UUID
            rid = UUID(rid_str)
            if not any(r.id == rid for r in yes_restaurants):
                return None
            return {"restaurant_id": rid, "narrative": narrative}
        except Exception:
            logger.debug("Gemini vibe pick failed", exc_info=True)
            return None

    async def analyze_personalized_fit(
        self,
        restaurant: Restaurant,
        user: User,
    ) -> dict:
        """Returns {dietary_match, budget_match, cuisine_overlap, narrative}."""
        prefs = user.preferences

        # Rule-based checks
        budget_match = True
        if prefs.budget_ranges and restaurant.price_tier:
            from services.places_service import PRICE_LEVEL_BY_TIER
            user_level = max((PRICE_LEVEL_BY_TIER.get(b, 0) for b in prefs.budget_ranges), default=4)
            rest_level = PRICE_LEVEL_BY_TIER.get(restaurant.price_tier, 0)
            budget_match = rest_level <= user_level

        cuisine_overlap = []
        if prefs.cuisine_preferences and restaurant.cuisine_tags:
            user_cuisines = {c.lower() for c in prefs.cuisine_preferences}
            cuisine_overlap = [t for t in restaurant.cuisine_tags if t.lower() in user_cuisines]

        dietary_match = True
        if prefs.dietary_restrictions:
            restrictions_lower = {d.lower() for d in prefs.dietary_restrictions}
            tags_lower = {t.lower() for t in restaurant.cuisine_tags}
            desc_lower = (restaurant.description or "").lower()
            vibe_lower = (restaurant.vibe_blurb or "").lower()
            all_text = tags_lower | set(desc_lower.split()) | set(vibe_lower.split())
            # Only flag mismatch when we have strong evidence
            vegan_conflict = "vegan" in restrictions_lower and any(
                w in all_text for w in ("steakhouse", "bbq", "barbecue", "burger", "meat")
            )
            gluten_conflict = "gluten-free" in restrictions_lower and any(
                w in all_text for w in ("pasta", "ramen", "noodle", "bakery", "pizza")
            )
            dietary_match = not (vegan_conflict or gluten_conflict)

        narrative = await self._narrative_fit(restaurant, user, dietary_match, budget_match, cuisine_overlap)
        return {
            "dietary_match": dietary_match,
            "budget_match": budget_match,
            "cuisine_overlap": cuisine_overlap,
            "narrative": narrative,
        }

    async def _narrative_fit(
        self,
        restaurant: Restaurant,
        user: User,
        dietary_match: bool,
        budget_match: bool,
        cuisine_overlap: list[str],
    ) -> str:
        model = self._get_model()
        fallback = _rule_based_narrative(restaurant, dietary_match, budget_match, cuisine_overlap)
        if model is None:
            return fallback

        prefs = user.preferences
        tags = ", ".join(restaurant.cuisine_tags) if restaurant.cuisine_tags else "various"
        overlap_str = ", ".join(cuisine_overlap) if cuisine_overlap else "none"
        prompt = f"""Write a 2-3 sentence personal note explaining how well this restaurant fits this user. Be conversational and specific.

Restaurant: {restaurant.name}
Cuisine: {tags}
Price: {restaurant.price_tier or "unknown"}
Vibe: {restaurant.vibe_blurb or restaurant.description or "No info"}

User fit:
- Dietary match: {"Yes" if dietary_match else "No"}
- Budget match: {"Yes" if budget_match else "No"}
- Shared cuisine interests: {overlap_str}
- User's dietary restrictions: {", ".join(prefs.dietary_restrictions) if prefs.dietary_restrictions else "none"}
- User's budget: {"/".join(prefs.budget_ranges) if prefs.budget_ranges else "any"}

Respond with the narrative text only (no quotes, no JSON, no markdown)."""
        try:
            resp = await model.generate_content_async(prompt)
            text = resp.text.strip().strip('"')
            return text if text else fallback
        except Exception:
            logger.debug("Gemini fit narrative failed", exc_info=True)
            return fallback


def _rule_based_narrative(
    restaurant: Restaurant,
    dietary_match: bool,
    budget_match: bool,
    cuisine_overlap: list[str],
) -> str:
    parts = []
    if cuisine_overlap:
        parts.append(f"Matches your interest in {', '.join(cuisine_overlap)}.")
    if budget_match:
        parts.append(f"The {restaurant.price_tier or 'price'} tier fits your budget.")
    else:
        parts.append(f"This spot is outside your usual budget range at {restaurant.price_tier}.")
    if not dietary_match:
        parts.append("It may not align with your dietary restrictions.")
    return " ".join(parts) if parts else "No personal fit data available."


def get_gemini_service() -> GeminiService:
    return GeminiService()

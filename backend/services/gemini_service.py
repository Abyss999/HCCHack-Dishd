"""Vibe-pick and personalized-fit via Gemini.

Lazy-fetches Google Places reviews for top-3 candidates on first call and
caches them on the Restaurant document so future demo runs skip the API.
"""
from __future__ import annotations

import hashlib
import json
from typing import Any

import httpx
from fastapi import HTTPException, status

from config import Settings, get_settings
from models.restaurant import Restaurant
from models.user import User, UserPreferences

GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
PLACE_DETAILS_URL = "https://maps.googleapis.com/maps/api/place/details/json"


class GeminiService:
    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    async def vibe_pick(
        self,
        members: list[User],
        top: list[dict[str, Any]],
    ) -> dict[str, Any]:
        """`top` rows are matching_service.get_top_3() output:
        {restaurant: Restaurant, yes_count, total, score_pct}.
        Returns {pick_restaurant_id, name, reasoning}.
        """
        if not self.settings.google_gemini_api_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="GOOGLE_GEMINI_API_KEY is not configured",
            )
        if not top:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No top-3 yet")

        async with httpx.AsyncClient(timeout=15.0) as http:
            for row in top:
                r: Restaurant = row["restaurant"]
                if not r.reviews and self.settings.google_places_api_key:
                    r.reviews = await self._fetch_reviews(http, r.google_place_id)
                    await r.save()

            prompt = self._build_prompt(members, top)
            resp = await http.post(
                f"{GEMINI_URL}?key={self.settings.google_gemini_api_key}",
                json={
                    "contents": [{"parts": [{"text": prompt}]}],
                    "generationConfig": {"temperature": 0.7, "responseMimeType": "application/json"},
                },
            )
            if resp.status_code >= 400:
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail=f"Gemini error: {resp.text[:200]}",
                )
            body = resp.json()

        try:
            text = body["candidates"][0]["content"]["parts"][0]["text"]
            parsed = json.loads(text)
            pick_name = parsed["pick"]
            reasoning = parsed["reasoning"]
        except (KeyError, IndexError, json.JSONDecodeError) as exc:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Could not parse Gemini response: {exc}",
            ) from exc

        chosen = next(
            (row["restaurant"] for row in top if row["restaurant"].name == pick_name),
            top[0]["restaurant"],
        )
        return {
            "pick_restaurant_id": chosen.id,
            "name": chosen.name,
            "reasoning": reasoning,
        }

    @staticmethod
    async def _fetch_reviews(http: httpx.AsyncClient, place_id: str) -> list[str]:
        from config import get_settings as _s
        resp = await http.get(
            PLACE_DETAILS_URL,
            params={"key": _s().google_places_api_key, "place_id": place_id, "fields": "reviews"},
        )
        if resp.status_code != 200:
            return []
        result = resp.json().get("result", {})
        return [rev.get("text", "")[:600] for rev in (result.get("reviews") or [])[:5]]

    @staticmethod
    def _build_prompt(members: list[User], top: list[dict[str, Any]]) -> str:
        is_houston = all(row["restaurant"].is_seed for row in top)
        is_solo = len(members) == 1

        group_prefs = []
        for u in members:
            p = u.preferences
            group_prefs.append({
                "name": u.name,
                "cuisines": p.cuisine_preferences,
                "dietary": p.dietary_restrictions,
                "budget": p.budget_range,
            })

        candidates = []
        for row in top:
            r: Restaurant = row["restaurant"]
            menu_with_reviews = [
                {
                    "item": mr.get("item"),
                    "quotes": [{"text": q.get("text"), "source": q.get("source")} for q in (mr.get("quotes") or [])],
                }
                for mr in (r.menu_reviews or [])
            ]
            vibe_quotes = [{"text": q.get("text"), "source": q.get("source")} for q in (r.overall_vibe_quotes or [])]
            candidates.append({
                "name": r.name,
                "cuisine_tags": r.cuisine_tags,
                "price_tier": r.price_tier,
                "rating": r.rating,
                "vibe_blurb": r.vibe_blurb,
                "menu_highlights": r.menu[:5],
                "menu_with_reviews": menu_with_reviews,
                "vibe_quotes": vibe_quotes,
                "generic_reviews": r.reviews[:3],
                "group_yes_pct": row["score_pct"],
            })

        base_instruction = (
            "You are picking one restaurant for a group based on vibe, group preferences, "
            "and real customer reviews. The group already voted; here are their top 3.\n\n"
            f"GROUP MEMBERS AND PREFERENCES:\n{json.dumps(group_prefs, indent=2)}\n\n"
            f"TOP 3 CANDIDATES:\n{json.dumps(candidates, indent=2)}\n\n"
            "Pick the ONE restaurant whose vibe + menu + reviews best fit the group. "
            "Prioritize signals in this order:\n"
            "  1. menu_with_reviews — dish-level quotes are the strongest signal.\n"
            "  2. vibe_quotes — atmosphere quotes from real diners.\n"
            "  3. generic_reviews and vibe_blurb — fallback context.\n"
            "  4. group_yes_pct — tie-breaker only.\n\n"
        )

        if is_houston:
            all_dietary = [r for u in group_prefs for r in u["dietary"]]
            dietary_intersection = list(set(all_dietary))

            if is_solo:
                user = group_prefs[0]
                dietary_note = (
                    f"The user is {user['name']}. "
                    f"They have dietary restrictions: {user['dietary'] or 'none'}. "
                    f"Your reasoning MUST address {user['name']} by name, "
                    f"name AT LEAST ONE specific dish they can eat (respecting {user['dietary'] or 'no'} dietary restrictions), "
                    f"explain why it fits their cuisine preferences ({user['cuisines'] or 'not specified'}), "
                    "and quote 3-8 words verbatim from a real menu_with_reviews quote with source attribution."
                )
            else:
                names = [u["name"] for u in group_prefs]
                strict_members = [u["name"] for u in group_prefs if u["dietary"]]
                if dietary_intersection:
                    dietary_note = (
                        f"The group is {', '.join(names)}. "
                        f"Shared dietary needs across the group: {dietary_intersection}. "
                        "Your reasoning MUST identify the dietary intersection ('everyone can eat plant-based here') "
                        "or note that the restaurant accommodates the strictest member "
                        f"({', '.join(strict_members) if strict_members else 'no strict members'}). "
                        "Name AT LEAST ONE specific dish and quote 3-8 words verbatim from a real review with source."
                    )
                else:
                    dietary_note = (
                        f"The group is {', '.join(names)}. No shared dietary restrictions. "
                        "Name AT LEAST ONE specific dish from menu_with_reviews "
                        "and quote 3-8 words verbatim from a real review with source attribution."
                    )

            reasoning_instruction = (
                f"{dietary_note}\n\n"
                "Quote ONLY text that appears in the data — do not paraphrase or invent. "
                "Keep reasoning to 3-4 sentences max.\n\n"
            )
        else:
            reasoning_instruction = (
                "In your reasoning, name AT LEAST ONE specific menu item from menu_with_reviews "
                "and quote 3-8 words from a real review verbatim (in quotes), explaining WHY that "
                "dish/quote fits the group's preferences. Quote ONLY text that appears in the "
                "data — do not paraphrase or invent.\n\n"
            )

        return (
            base_instruction
            + reasoning_instruction
            + 'Respond ONLY with JSON: {"pick": "<exact restaurant name>", '
            '"reasoning": "<3-4 sentences. Mention at least one menu item by name and one short verbatim review quote.>"}'
        )


    # ------------------------------------------------------------------
    # Feature 1: personalized-fit for a single Houston restaurant
    # ------------------------------------------------------------------

    async def personalized_fit(
        self,
        restaurant: Restaurant,
        user: User,
    ) -> dict[str, Any]:
        """Return a personalized-fit dict for `restaurant` given `user` prefs.

        Caches on `restaurant.personalized_fits[cache_key]` so repeat calls
        by the same user (same prefs hash) are free.
        """
        prefs = user.preferences
        cache_key = f"{user.id}:{_prefs_hash(prefs)}"

        if cache_key in restaurant.personalized_fits:
            return restaurant.personalized_fits[cache_key]

        if not self.settings.google_gemini_api_key:
            return _fit_fallback(restaurant, prefs)

        try:
            async with httpx.AsyncClient(timeout=12.0) as http:
                prompt = self._build_fit_prompt(restaurant, prefs)
                resp = await http.post(
                    f"{GEMINI_URL}?key={self.settings.google_gemini_api_key}",
                    json={
                        "contents": [{"parts": [{"text": prompt}]}],
                        "generationConfig": {
                            "temperature": 0.5,
                            "responseMimeType": "application/json",
                        },
                    },
                )
                if resp.status_code >= 400:
                    return _fit_fallback(restaurant, prefs)

                body = resp.json()
                text = body["candidates"][0]["content"]["parts"][0]["text"]
                result: dict[str, Any] = json.loads(text)
        except Exception:
            return _fit_fallback(restaurant, prefs)

        # Persist the cache entry — fire-and-forget style; don't let a save
        # failure block the caller.
        try:
            restaurant.personalized_fits = {**restaurant.personalized_fits, cache_key: result}
            await restaurant.save()
        except Exception:
            pass

        return result

    @staticmethod
    def _build_fit_prompt(restaurant: Restaurant, prefs: UserPreferences) -> str:
        price_tiers = ["$", "$$", "$$$", "$$$$"]
        user_budget = prefs.budget_range
        r_tier = restaurant.price_tier

        if user_budget and r_tier:
            if price_tiers.index(r_tier) <= price_tiers.index(user_budget):
                budget_fit = "match"
            else:
                budget_fit = "over"
        elif user_budget:
            budget_fit = "unknown"
        else:
            budget_fit = "unknown"

        menu_with_reviews = [
            {
                "item": mr.get("item"),
                "quotes": [{"text": q.get("text"), "source": q.get("source")} for q in (mr.get("quotes") or [])[:2]],
            }
            for mr in (restaurant.menu_reviews or [])
        ]
        vibe_quotes = [{"text": q.get("text"), "source": q.get("source")} for q in (restaurant.overall_vibe_quotes or [])[:3]]

        data = {
            "restaurant": {
                "name": restaurant.name,
                "cuisine_tags": restaurant.cuisine_tags,
                "price_tier": r_tier,
                "menu": restaurant.menu,
                "vibe_blurb": restaurant.vibe_blurb,
                "menu_with_reviews": menu_with_reviews,
                "vibe_quotes": vibe_quotes,
            },
            "user_prefs": {
                "dietary_restrictions": prefs.dietary_restrictions,
                "cuisine_preferences": prefs.cuisine_preferences,
                "budget_range": user_budget,
            },
            "precomputed_budget_fit": budget_fit,
        }

        return (
            "You are helping a user decide whether a restaurant fits them. "
            "Based on the restaurant data and user preferences below, return ONLY JSON "
            "with exactly these fields:\n"
            '- "eligible_items": array of 2-4 menu items the user can likely eat given their '
            "dietary restrictions. Each item: "
            '{"name": str, "tags": [str], "review_quote": str|null, "review_source": str|null}. '
            "Tags must only be from: vegan, plant-based, gluten-free, dairy-free, nut-free, halal, kosher. "
            "Only add a tag if you are confident from the dish name/context. "
            "If no dietary restrictions, pick the 2-4 most appealing items. "
            'Add "review_quote" and "review_source" from menu_with_reviews when available.\n'
            '- "personalized_reason": 1-2 sentences. Mention at least one dish by name. '
            "Explain why this restaurant fits their cuisine_preferences. "
            "If dietary restrictions exist, confirm the dish works. "
            "Be specific — do not be generic.\n"
            f'- "budget_fit": use the precomputed value "{budget_fit}" exactly.\n'
            '- "headline_quote": pick the single most compelling quote from vibe_quotes, '
            'as {"text": str, "source": str}. Null if none available.\n\n'
            f"DATA:\n{json.dumps(data, indent=2)}"
        )


def _prefs_hash(prefs: UserPreferences) -> str:
    key = json.dumps({
        "dietary": sorted(prefs.dietary_restrictions),
        "cuisines": sorted(prefs.cuisine_preferences),
        "budget": prefs.budget_range,
    }, sort_keys=True)
    return hashlib.sha256(key.encode()).hexdigest()[:16]


def _fit_fallback(restaurant: Restaurant, prefs: UserPreferences) -> dict[str, Any]:
    """Graceful fallback: return menu items without tags, no Gemini reasoning."""
    items = [{"name": m, "tags": [], "review_quote": None, "review_source": None} for m in restaurant.menu[:4]]
    price_tiers = ["$", "$$", "$$$", "$$$$"]
    user_budget = prefs.budget_range
    r_tier = restaurant.price_tier
    if user_budget and r_tier:
        budget_fit = "match" if price_tiers.index(r_tier) <= price_tiers.index(user_budget) else "over"
    else:
        budget_fit = "unknown"
    return {
        "eligible_items": items,
        "personalized_reason": f"Check out {restaurant.name} for {', '.join(restaurant.cuisine_tags[:2])} cuisine.",
        "budget_fit": budget_fit,
        "headline_quote": None,
    }


def get_gemini_service() -> GeminiService:
    return GeminiService()

import asyncio
import hashlib
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

import httpx
from fastapi import HTTPException, status
from pymongo.errors import DuplicateKeyError

from config import Settings, get_settings
from models.place_search_cache import PlaceSearchCache
from models.restaurant import Restaurant
from models.user import UserPreferences

CACHE_TTL = timedelta(hours=6)

GOOGLE_NEARBY_URL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
GOOGLE_DETAILS_URL = "https://maps.googleapis.com/maps/api/place/details/json"
GOOGLE_PHOTO_URL = "https://maps.googleapis.com/maps/api/place/photo"

PRICE_TIER_BY_LEVEL = {0: "$", 1: "$", 2: "$$", 3: "$$$", 4: "$$$$"}
PRICE_LEVEL_BY_TIER = {"$": 1, "$$": 2, "$$$": 3, "$$$$": 4}


@dataclass(frozen=True)
class GroupFilter:
    """Effective filter derived by intersecting member preferences."""

    radius_m: int
    cuisines: list[str]                   # union of non-empty member cuisines
    dietary_restrictions: list[str]       # union (strictest)
    max_price_level: int | None           # min across members' budget ceilings


class PlacesService:
    def __init__(self, settings: Settings | None = None, gemini=None) -> None:
        self.settings = settings or get_settings()
        self._gemini = gemini  # injected lazily to avoid circular imports

    # ---------- group filter derivation ----------

    @staticmethod
    def derive_group_filter(prefs: list[UserPreferences]) -> GroupFilter:
        if not prefs:
            return GroupFilter(radius_m=10_000, cuisines=[], dietary_restrictions=[], max_price_level=None)

        radius_km = min(p.max_distance_km for p in prefs if p.max_distance_km)
        radius_m = max(500, int(radius_km * 1000))

        cuisines: set[str] = set()
        for p in prefs:
            cuisines.update(c.lower() for c in p.cuisine_preferences)

        dietary: set[str] = set()
        for p in prefs:
            dietary.update(d.lower() for d in p.dietary_restrictions)

        price_levels = []
        for p in prefs:
            if p.budget_ranges:
                level = max(PRICE_LEVEL_BY_TIER[b] for b in p.budget_ranges if b in PRICE_LEVEL_BY_TIER)
                price_levels.append(level)
        max_price_level = min(price_levels) if price_levels else None

        return GroupFilter(
            radius_m=radius_m,
            cuisines=sorted(cuisines),
            dietary_restrictions=sorted(dietary),
            max_price_level=max_price_level,
        )

    # ---------- Google Places ----------

    @staticmethod
    def _cache_key(lat: float, lng: float, group: GroupFilter) -> str:
        # Round coords so nearby calls with tiny offsets share a cache entry.
        rounded_lat = round(lat, 3)  # ~110m granularity
        rounded_lng = round(lng, 3)
        cuisines = ",".join(sorted(group.cuisines))
        raw = f"{rounded_lat}|{rounded_lng}|{group.radius_m}|{cuisines}|{group.max_price_level or ''}"
        return hashlib.sha256(raw.encode()).hexdigest()

    async def nearby_search(
        self,
        lat: float,
        lng: float,
        group: GroupFilter,
    ) -> list[Restaurant]:
        if not self.settings.google_places_api_key:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="GOOGLE_PLACES_API_KEY is not configured",
            )

        cache_key = self._cache_key(lat, lng, group)
        cached = await PlaceSearchCache.find_one(PlaceSearchCache.cache_key == cache_key)
        if cached is not None and cached.expires_at > datetime.now(timezone.utc):
            restaurants: list[Restaurant] = []
            for rid in cached.restaurant_ids:
                doc = await Restaurant.get(rid)
                if doc is not None:
                    restaurants.append(doc)
            if restaurants:
                return restaurants
            # Cached but the restaurant docs are gone — fall through and refetch.

        params: dict[str, Any] = {
            "key": self.settings.google_places_api_key,
            "location": f"{lat},{lng}",
            "radius": group.radius_m,
            "type": "restaurant",
        }
        if group.cuisines:
            params["keyword"] = " ".join(group.cuisines)
        if group.max_price_level is not None:
            params["maxprice"] = group.max_price_level

        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(GOOGLE_NEARBY_URL, params=params)
            resp.raise_for_status()
            body = resp.json()

        if body.get("status") not in ("OK", "ZERO_RESULTS"):
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Places API error: {body.get('status')}",
            )

        _EXCLUDED = {"lodging", "hotel", "motel", "casino"}

        results: list[Restaurant] = []
        for place in body.get("results", []):
            if set(place.get("types", [])) & _EXCLUDED:
                continue
            restaurant = await self._upsert_place(place)
            if restaurant is not None:
                results.append(restaurant)

        await self._save_cache(cache_key, [r.id for r in results], existing=cached)
        return results

    @staticmethod
    async def _save_cache(cache_key: str, restaurant_ids: list, existing: PlaceSearchCache | None) -> None:
        expires = datetime.now(timezone.utc) + CACHE_TTL
        if existing is not None:
            existing.restaurant_ids = restaurant_ids
            existing.expires_at = expires
            await existing.save()
            return
        try:
            await PlaceSearchCache(
                cache_key=cache_key,
                restaurant_ids=restaurant_ids,
                expires_at=expires,
            ).insert()
        except DuplicateKeyError:
            # Lost the race with another request that just cached the same key — fine, ignore.
            pass

    async def _upsert_place(self, place: dict[str, Any]) -> Restaurant | None:
        place_id = place.get("place_id")
        loc = place.get("geometry", {}).get("location")
        if not place_id or not loc:
            return None

        photo_url: str | None = None
        photos = place.get("photos") or []
        if photos and self.settings.google_places_api_key:
            ref = photos[0].get("photo_reference")
            if ref:
                photo_url = (
                    f"{GOOGLE_PHOTO_URL}?maxwidth=800&photoreference={ref}"
                    f"&key={self.settings.google_places_api_key}"
                )

        price_level = place.get("price_level")
        price_tier = PRICE_TIER_BY_LEVEL.get(price_level) if price_level is not None else None

        fields = {
            "name": place.get("name", "Unknown"),
            "cuisine_tags": [t for t in place.get("types", []) if t not in ("restaurant", "food", "point_of_interest", "establishment")],
            "price_tier": price_tier,
            "rating": place.get("rating"),
            "photo_url": photo_url,
            "address": place.get("vicinity"),
            "lat": loc["lat"],
            "lng": loc["lng"],
        }

        existing = await Restaurant.find_one(Restaurant.google_place_id == place_id)
        if existing is None:
            details = await self._fetch_details(place_id)
            restaurant = Restaurant(
                google_place_id=place_id,
                description=details.get("description"),
                reviews=details.get("reviews"),
                **fields,
            )
            await restaurant.insert()
            asyncio.create_task(self._generate_ai_fields(restaurant))
            return restaurant

        for key, value in fields.items():
            setattr(existing, key, value)
        if not existing.description or not existing.reviews:
            details = await self._fetch_details(place_id)
            if not existing.description:
                existing.description = details.get("description")
            if not existing.reviews:
                existing.reviews = details.get("reviews")
        await existing.save()
        if existing.vibe_blurb is None:
            asyncio.create_task(self._generate_ai_fields(existing))
        return existing

    async def _fetch_details(self, place_id: str) -> dict:
        """Fetches editorial_summary and reviews from Places Details. Never raises."""
        if not self.settings.google_places_api_key:
            return {}
        params = {
            "key": self.settings.google_places_api_key,
            "place_id": place_id,
            "fields": "editorial_summary,reviews",
        }
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                resp = await client.get(GOOGLE_DETAILS_URL, params=params)
            if resp.status_code != 200:
                return {}
            body = resp.json()
            if body.get("status") != "OK":
                return {}
            result = body.get("result") or {}
            out: dict = {}

            summary = (result.get("editorial_summary") or {}).get("overview")
            if isinstance(summary, str) and summary.strip():
                MAX_LEN = 180
                text = summary.strip()
                out["description"] = text if len(text) <= MAX_LEN else text[: MAX_LEN - 1].rsplit(" ", 1)[0] + "…"

            raw_reviews = result.get("reviews") or []
            snippets = [r["text"] for r in raw_reviews if isinstance(r.get("text"), str) and r["text"].strip()]
            if snippets:
                out["reviews"] = snippets[:3]

            return out
        except Exception:  # noqa: BLE001
            return {}

    async def _generate_ai_fields(self, restaurant: Restaurant) -> None:
        """Background task: call Gemini to fill vibe_blurb + overall_vibe_quotes. Never raises."""
        try:
            if self._gemini is None:
                from services.gemini_service import GeminiService
                self._gemini = GeminiService(self.settings)
            data = await self._gemini.generate_vibe_fields(
                name=restaurant.name,
                cuisine_tags=restaurant.cuisine_tags,
                description=restaurant.description,
                reviews=restaurant.reviews,
            )
            if data:
                if data.get("vibe_blurb"):
                    restaurant.vibe_blurb = data["vibe_blurb"]
                if data.get("overall_vibe_quotes"):
                    restaurant.overall_vibe_quotes = data["overall_vibe_quotes"]
                await restaurant.save()
        except Exception:  # noqa: BLE001
            pass


def get_places_service() -> PlacesService:
    from services.gemini_service import GeminiService
    return PlacesService(gemini=GeminiService())

from motor.motor_asyncio import AsyncIOMotorCollection

from database import Database
from schemas.recommendation import RecommendationOut, RecommendationRequest

# Atlas built-in sample dataset.
SAMPLE_DB = "sample_restaurants"
SAMPLE_COLLECTION = "restaurants"

# Grade letter → score contribution. A worse latest grade reduces the rec score.
GRADE_POINTS: dict[str, int] = {"A": 50, "B": 30, "C": 10}

# Cuisine match contribution (case-insensitive intersection).
CUISINE_POINTS = 50

# Borough match contribution.
BOROUGH_POINTS = 25


class RecommendationService:
    """Scores Atlas `sample_restaurants` docs against user preferences.

    All scoring runs inside a single aggregation pipeline so the database
    does the filter/sort/limit work. The service only shapes the payload.
    """

    def __init__(self, collection: AsyncIOMotorCollection | None = None) -> None:
        if collection is not None:
            self.collection = collection
        else:
            if Database.client is None:
                raise RuntimeError("Database client is not initialized")
            self.collection = Database.client[SAMPLE_DB][SAMPLE_COLLECTION]

    async def top(self, req: RecommendationRequest) -> list[RecommendationOut]:
        cuisines_lower = [c.lower() for c in req.cuisines]
        allowed_grades = self._grades_at_or_above(req.min_grade)

        pipeline: list[dict] = []

        match: dict = {"grades": {"$ne": []}}
        if req.borough:
            match["borough"] = req.borough
        pipeline.append({"$match": match})

        # Pick most recent grade (grades[] is ordered newest-first in the sample dataset,
        # but we sort defensively in case it isn't).
        pipeline.append(
            {
                "$addFields": {
                    "latest_grade": {
                        "$first": {
                            "$sortArray": {"input": "$grades", "sortBy": {"date": -1}}
                        }
                    }
                }
            }
        )

        pipeline.append({"$match": {"latest_grade.grade": {"$in": allowed_grades}}})

        pipeline.append(
            {
                "$addFields": {
                    "cuisine_score": {
                        "$cond": [
                            {"$in": [{"$toLower": "$cuisine"}, cuisines_lower]},
                            CUISINE_POINTS,
                            0,
                        ]
                    },
                    "borough_score": (
                        BOROUGH_POINTS if req.borough is None else {
                            "$cond": [{"$eq": ["$borough", req.borough]}, BOROUGH_POINTS, 0]
                        }
                    ),
                    "grade_score": {
                        "$switch": {
                            "branches": [
                                {"case": {"$eq": ["$latest_grade.grade", g]}, "then": pts}
                                for g, pts in GRADE_POINTS.items()
                            ],
                            "default": 0,
                        }
                    },
                }
            }
        )

        pipeline.append(
            {
                "$addFields": {
                    "match_score": {
                        "$add": ["$cuisine_score", "$borough_score", "$grade_score"]
                    }
                }
            }
        )

        pipeline.append(
            {
                "$sort": {
                    "match_score": -1,
                    "latest_grade.score": 1,  # tie-break: lower NYC inspection score = cleaner
                    "name": 1,
                }
            }
        )

        pipeline.append({"$limit": req.limit})

        pipeline.append(
            {
                "$project": {
                    "_id": 0,
                    "restaurant_id": 1,
                    "name": 1,
                    "cuisine": 1,
                    "borough": 1,
                    "address": 1,
                    "latest_grade": {
                        "grade": "$latest_grade.grade",
                        "score": "$latest_grade.score",
                    },
                    "match_score": 1,
                }
            }
        )

        rows = await self.collection.aggregate(pipeline).to_list(length=req.limit)
        return [RecommendationOut(**row) for row in rows]

    @staticmethod
    def _grades_at_or_above(min_grade: str) -> list[str]:
        order = ["A", "B", "C"]
        return order[: order.index(min_grade) + 1]


def get_recommendation_service() -> RecommendationService:
    return RecommendationService()

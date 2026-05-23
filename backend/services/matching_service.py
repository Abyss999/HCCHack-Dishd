from uuid import UUID

from models.restaurant import Restaurant
from models.session import Session
from models.swipe import Swipe


class MatchingService:
    """Aggregates swipes into match decisions.

    Phase 1: pure yes-count math. Phase 9 will swap this for a vector-based
    welfare function over Atlas Vector Search.
    """

    SWIPE_CEILING = 10  # forced top-3 reveal once every member has hit this many swipes (per session it can be overridden via session.swipe_ceiling_override)

    @staticmethod
    def ceiling_for(session: Session) -> int:
        return session.swipe_ceiling_override or MatchingService.SWIPE_CEILING

    async def count_user_swipes(self, session_id: UUID, user_id: UUID) -> int:
        return await Swipe.find(
            Swipe.session_id == session_id,
            Swipe.user_id == user_id,
        ).count()

    async def check_instant_match(self, session: Session) -> Restaurant | None:
        member_count = len(session.members)
        if member_count == 0:
            return None
        # Non-solo sessions need at least 2 members for an "instant match" to be meaningful —
        # otherwise the host gets a match on their very first yes while waiting for friends.
        if not session.solo_mode and member_count < 2:
            return None
        pipeline = [
            {"$match": {"session_id": session.id, "direction": "yes"}},
            {"$group": {"_id": "$restaurant_id", "yes_users": {"$addToSet": "$user_id"}}},
            {"$match": {"$expr": {"$eq": [{"$size": "$yes_users"}, member_count]}}},
            {"$limit": 1},
        ]
        docs = await Swipe.aggregate(pipeline).to_list()
        if not docs:
            return None
        return await Restaurant.get(docs[0]["_id"])

    async def get_top_n(self, session: Session) -> list[dict]:
        total = len(session.members)
        if total == 0:
            return []
        pipeline = [
            {"$match": {"session_id": session.id, "direction": "yes"}},
            {"$group": {"_id": "$restaurant_id", "yes_users": {"$addToSet": "$user_id"}}},
            {"$project": {"yes_count": {"$size": "$yes_users"}}},
            {"$sort": {"yes_count": -1}},
            {"$limit": session.top_n},
        ]
        rows = await Swipe.aggregate(pipeline).to_list()
        results: list[dict] = []
        for row in rows:
            restaurant = await Restaurant.get(row["_id"])
            if restaurant is None:
                continue
            yes_count = row["yes_count"]
            results.append(
                {
                    "restaurant": restaurant,
                    "yes_count": yes_count,
                    "total": total,
                    "score_pct": round((yes_count / total) * 100),
                }
            )
        return results

    async def all_members_done(self, session: Session) -> bool:
        ceiling = self.ceiling_for(session)
        for member in session.members:
            count = await self.count_user_swipes(session.id, member.user_id)
            if count < ceiling:
                return False
        return True


def get_matching_service() -> MatchingService:
    return MatchingService()

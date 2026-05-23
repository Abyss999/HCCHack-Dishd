from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from pymongo.errors import DuplicateKeyError

from config import get_settings
from deps import get_current_user
from models.restaurant import Restaurant
from models.session import Session
from models.swipe import Swipe
from models.user import User
from schemas.restaurant import RestaurantOut
from schemas.swipe import ResultsOut, SwipeAck, SwipeIn, TopResult
from schemas.vibe_pick import VibePickOut
from security import limiter
from services.gemini_service import GeminiService, get_gemini_service
from services.matching_service import MatchingService, get_matching_service
from services.notification_service import NotificationService, get_notification_service
from services.session_service import SessionService, get_session_service
from ws.manager import ConnectionManager, get_connection_manager

router = APIRouter(tags=["swipes"])
_settings = get_settings()


def _restaurant_out(r: Restaurant) -> RestaurantOut:
    return RestaurantOut(**r.model_dump())


@router.post("/sessions/{session_id}/swipe", response_model=SwipeAck)
@limiter.limit(_settings.rate_limit_swipe)
async def submit_swipe(
    request: Request,
    response: Response,
    session_id: UUID,
    data: SwipeIn,
    current: User = Depends(get_current_user),
    sessions: SessionService = Depends(get_session_service),
    matching: MatchingService = Depends(get_matching_service),
    cm: ConnectionManager = Depends(get_connection_manager),
    notifications: NotificationService = Depends(get_notification_service),
) -> SwipeAck:
    session = await sessions.get_by_id(session_id)
    if not sessions.is_member(session, current.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a session member")
    if session.status not in ("swiping",):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Session is in '{session.status}', not swiping",
        )

    restaurant = await Restaurant.get(data.restaurant_id)
    if restaurant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Restaurant not found")

    swipe = Swipe(
        session_id=session_id,
        user_id=current.id,
        restaurant_id=data.restaurant_id,
        direction=data.direction,
    )
    try:
        await swipe.insert()
    except DuplicateKeyError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Already swiped on this restaurant",
        ) from exc

    swipe_count = await matching.count_user_swipes(session_id, current.id)
    await cm.broadcast(
        session_id,
        {
            "type": "swipe_progress",
            "payload": {"user_id": str(current.id), "swipe_count": swipe_count},
        },
    )

    instant: Restaurant | None = None
    if data.direction == "yes":
        instant = await matching.check_instant_match(session)
        if instant is not None:
            session.status = "matched"
            session.matched_restaurant_id = instant.id
            await session.save()
            await cm.broadcast(
                session_id,
                {"type": "instant_match", "payload": {"restaurant": _restaurant_out(instant).model_dump(mode="json")}},
            )
            await notifications.send_to_session(
                session,
                title="It's a match!",
                body=f"Your group agreed on {instant.name}",
                data={"session_id": str(session.id), "restaurant_id": str(instant.id), "type": "instant_match"},
            )
            return SwipeAck(accepted=True, swipe_count=swipe_count, instant_match=_restaurant_out(instant))

    await _maybe_nudge_laggards(session, matching, notifications, current_user_id=current.id)

    if await matching.all_members_done(session):
        await _finalize_top3(session, matching, cm, notifications)

    return SwipeAck(accepted=True, swipe_count=swipe_count, instant_match=None)


@router.get("/sessions/{session_id}/results", response_model=ResultsOut)
async def get_results(
    session_id: UUID,
    current: User = Depends(get_current_user),
    sessions: SessionService = Depends(get_session_service),
    matching: MatchingService = Depends(get_matching_service),
) -> ResultsOut:
    session = await sessions.get_by_id(session_id)
    if not sessions.is_member(session, current.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a session member")
    top = await matching.get_top_n(session)
    return ResultsOut(top=[
        TopResult(
            restaurant=_restaurant_out(row["restaurant"]),
            score_pct=row["score_pct"],
            yes_count=row["yes_count"],
            total=row["total"],
        )
        for row in top
    ])


async def _finalize_top3(
    session: Session,
    matching: MatchingService,
    cm: ConnectionManager,
    notifications: NotificationService,
) -> None:
    top = await matching.get_top_n(session)
    session.status = "results"
    await session.save()
    payload = [
        {
            "restaurant": _restaurant_out(row["restaurant"]).model_dump(mode="json"),
            "score_pct": row["score_pct"],
            "yes_count": row["yes_count"],
            "total": row["total"],
        }
        for row in top
    ]
    await cm.broadcast(
        session.id,
        {"type": "top3_ready", "payload": {"results": payload}},
    )
    await notifications.send_to_session(
        session,
        title=f"Your Top {session.top_n} is ready",
        body="Open DishMatch to see what your group picked.",
        data={"session_id": str(session.id), "type": "top3_ready"},
    )


@router.get("/sessions/{session_id}/vibe-pick", response_model=VibePickOut)
async def get_vibe_pick(
    session_id: UUID,
    current: User = Depends(get_current_user),
    sessions: SessionService = Depends(get_session_service),
    gemini: GeminiService = Depends(get_gemini_service),
) -> VibePickOut:
    session = await sessions.get_by_id(session_id)
    if not sessions.is_member(session, current.id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a session member")

    yes_swipes = await Swipe.find(
        Swipe.session_id == session_id,
        Swipe.user_id == current.id,
        Swipe.direction == "yes",
    ).to_list()

    if not yes_swipes:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No yes swipes yet")

    yes_restaurants: list[Restaurant] = []
    for s in yes_swipes:
        r = await Restaurant.get(s.restaurant_id)
        if r is not None:
            yes_restaurants.append(r)

    if not yes_restaurants:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No yes swipes yet")

    pick = await gemini.get_vibe_pick(yes_restaurants, current)
    if pick is None:
        # Fallback: return the first yes restaurant with a generic narrative
        best = yes_restaurants[0]
        return VibePickOut(
            restaurant=_restaurant_out(best),
            narrative=f"Based on your swipes, {best.name} looks like a great fit for you!",
        )

    best = next(r for r in yes_restaurants if r.id == pick["restaurant_id"])
    return VibePickOut(restaurant=_restaurant_out(best), narrative=pick["narrative"])


async def _maybe_nudge_laggards(
    session: Session,
    matching: MatchingService,
    notifications: NotificationService,
    current_user_id: UUID,
) -> None:
    """When everyone except one member has hit the ceiling, ping that member."""
    ceiling = matching.ceiling_for(session)
    pending: list[UUID] = []
    for member in session.members:
        count = await matching.count_user_swipes(session.id, member.user_id)
        if count < ceiling:
            pending.append(member.user_id)
            if len(pending) > 1:
                return  # more than one straggler — no nudge yet
    if len(pending) != 1:
        return
    laggard_id = pending[0]
    if laggard_id == current_user_id:
        return  # the laggard is the swiper we just processed; let them keep going
    laggard = await User.get(laggard_id)
    if laggard is None:
        return
    await notifications.send_to_user(
        laggard,
        title="Your group is waiting",
        body="You're the last one swiping — finish up to see the results.",
        data={"session_id": str(session.id), "type": "waiting_on_you"},
    )

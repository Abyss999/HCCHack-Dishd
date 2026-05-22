from uuid import UUID

from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, status

from deps import get_current_user
from models.session import Session
from models.user import User
from schemas.session import MemberOut, SessionCreate, SessionOut
from services.auth_service import AuthService, get_auth_service
from services.session_service import SessionService, get_session_service
from ws.manager import ConnectionManager, get_connection_manager

router = APIRouter(tags=["sessions"])


def _to_out(session: Session) -> SessionOut:
    return SessionOut(
        id=session.id,
        code=session.code,
        host_user_id=session.host_user_id,
        status=session.status,
        location_lat=session.location_lat,
        location_lng=session.location_lng,
        location_label=session.location_label,
        members=[MemberOut(**m.model_dump()) for m in session.members],
        matched_restaurant_id=session.matched_restaurant_id,
        created_at=session.created_at,
    )


@router.post("/sessions", response_model=SessionOut, status_code=status.HTTP_201_CREATED)
async def create_session(
    data: SessionCreate,
    current: User = Depends(get_current_user),
    sessions: SessionService = Depends(get_session_service),
) -> SessionOut:
    session = await sessions.create(current, data)
    return _to_out(session)


@router.get("/sessions/{code}", response_model=SessionOut)
async def get_session_by_code(
    code: str,
    _: User = Depends(get_current_user),
    sessions: SessionService = Depends(get_session_service),
) -> SessionOut:
    session = await sessions.find_by_code(code)
    return _to_out(session)


@router.post("/sessions/{session_id}/join", response_model=SessionOut)
async def join_session(
    session_id: UUID,
    current: User = Depends(get_current_user),
    sessions: SessionService = Depends(get_session_service),
    cm: ConnectionManager = Depends(get_connection_manager),
) -> SessionOut:
    session, member, newly_added = await sessions.join(session_id, current)
    if newly_added:
        await cm.broadcast(
            session.id,
            {
                "type": "member_joined",
                "payload": {
                    "user_id": str(member.user_id),
                    "name": member.name,
                },
            },
        )
    return _to_out(session)


@router.post("/sessions/{session_id}/start", response_model=SessionOut)
async def start_session(
    session_id: UUID,
    current: User = Depends(get_current_user),
    sessions: SessionService = Depends(get_session_service),
    cm: ConnectionManager = Depends(get_connection_manager),
) -> SessionOut:
    session = await sessions.start(session_id, current)
    await cm.broadcast(
        session.id,
        {"type": "phase_change", "payload": {"phase": session.status}},
    )
    return _to_out(session)


@router.get("/sessions/{session_id}/status", response_model=SessionOut)
async def session_status(
    session_id: UUID,
    _: User = Depends(get_current_user),
    sessions: SessionService = Depends(get_session_service),
) -> SessionOut:
    session = await sessions.get_by_id(session_id)
    return _to_out(session)


@router.websocket("/ws/sessions/{session_id}")
async def session_ws(
    websocket: WebSocket,
    session_id: UUID,
    token: str,
    auth: AuthService = Depends(get_auth_service),
    sessions: SessionService = Depends(get_session_service),
    cm: ConnectionManager = Depends(get_connection_manager),
) -> None:
    try:
        user_id = auth.decode_token(token, expected_type="access")
    except Exception:  # noqa: BLE001
        await websocket.close(code=4401)
        return

    user = await User.get(user_id)
    if user is None:
        await websocket.close(code=4401)
        return

    session = await Session.get(session_id)
    if session is None:
        await websocket.close(code=4404)
        return
    if not sessions.is_member(session, user_id):
        await websocket.close(code=4403)
        return

    await cm.connect(session_id, user_id, websocket)
    try:
        while True:
            # Server-driven; we ignore client payloads but keep the loop alive.
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await cm.disconnect(session_id, user_id, websocket)

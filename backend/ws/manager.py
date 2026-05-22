import asyncio
from typing import Any
from uuid import UUID

from fastapi import WebSocket


class ConnectionManager:
    """Tracks active WebSocket connections per session.

    Structure: { session_id: { user_id: set[WebSocket] } }
    A user may have multiple sockets (e.g., phone + tablet).
    """

    def __init__(self) -> None:
        self._rooms: dict[UUID, dict[UUID, set[WebSocket]]] = {}
        self._lock = asyncio.Lock()

    async def connect(self, session_id: UUID, user_id: UUID, websocket: WebSocket) -> None:
        await websocket.accept()
        async with self._lock:
            room = self._rooms.setdefault(session_id, {})
            room.setdefault(user_id, set()).add(websocket)

    async def disconnect(self, session_id: UUID, user_id: UUID, websocket: WebSocket) -> None:
        async with self._lock:
            room = self._rooms.get(session_id)
            if not room:
                return
            sockets = room.get(user_id)
            if sockets is None:
                return
            sockets.discard(websocket)
            if not sockets:
                room.pop(user_id, None)
            if not room:
                self._rooms.pop(session_id, None)

    async def broadcast(self, session_id: UUID, event: dict[str, Any]) -> None:
        targets: list[WebSocket] = []
        async with self._lock:
            room = self._rooms.get(session_id)
            if not room:
                return
            for sockets in room.values():
                targets.extend(sockets)
        for ws in targets:
            try:
                await ws.send_json(event)
            except Exception:  # noqa: BLE001
                # Best-effort broadcast; dropped sockets are cleaned up on disconnect.
                pass

    def connected_user_ids(self, session_id: UUID) -> set[UUID]:
        room = self._rooms.get(session_id, {})
        return set(room.keys())


manager = ConnectionManager()


def get_connection_manager() -> ConnectionManager:
    return manager

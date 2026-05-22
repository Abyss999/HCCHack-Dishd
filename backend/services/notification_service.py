import logging
from typing import Any
from uuid import UUID

import httpx

from config import Settings, get_settings
from models.session import Session
from models.user import User

logger = logging.getLogger(__name__)


class NotificationService:
    """Sends push notifications via the Expo Push API.

    Best-effort: failures are logged but never raised. Notifications are a
    side channel — they must not break the user-facing request that triggered
    them.
    """

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    async def send_to_user(
        self,
        user: User,
        title: str,
        body: str,
        data: dict[str, Any] | None = None,
    ) -> None:
        tokens = [t.token for t in user.push_tokens]
        if tokens:
            await self._send(tokens, title, body, data)

    async def send_to_session(
        self,
        session: Session,
        title: str,
        body: str,
        data: dict[str, Any] | None = None,
        exclude_user_ids: set[UUID] | None = None,
    ) -> None:
        exclude = exclude_user_ids or set()
        target_ids = [m.user_id for m in session.members if m.user_id not in exclude]
        if not target_ids:
            return
        users = [u for u in [await User.get(uid) for uid in target_ids] if u is not None]
        tokens = [t.token for u in users for t in u.push_tokens]
        if tokens:
            await self._send(tokens, title, body, data)

    async def _send(
        self,
        tokens: list[str],
        title: str,
        body: str,
        data: dict[str, Any] | None,
    ) -> None:
        messages = [
            {"to": tok, "title": title, "body": body, "sound": "default", "data": data or {}}
            for tok in tokens
        ]
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(
                    self.settings.expo_push_url,
                    json=messages,
                    headers={"Accept": "application/json", "Content-Type": "application/json"},
                )
                resp.raise_for_status()
        except Exception as exc:  # noqa: BLE001
            logger.warning("Expo push failed for %d token(s): %s", len(tokens), exc)


def get_notification_service() -> NotificationService:
    return NotificationService()

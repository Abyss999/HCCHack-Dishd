import re
import secrets
import string
from uuid import UUID

from fastapi import HTTPException, status
from pymongo.errors import DuplicateKeyError

from config import get_settings
from models.session import Session, SessionMember
from models.user import User
from schemas.session import SessionCreate

CODE_ALPHABET = string.ascii_uppercase + string.digits
CODE_LENGTH = 4
MAX_CODE_ATTEMPTS = 25
CODE_REGEX = re.compile(r"^[A-Z0-9]{4}$")


class SessionService:
    async def create(self, host: User, data: SessionCreate) -> Session:
        host_member = SessionMember(user_id=host.id, name=host.name)
        last_error: Exception | None = None
        for _ in range(MAX_CODE_ATTEMPTS):
            code = self._generate_code()
            session = Session(
                code=code,
                host_user_id=host.id,
                # Always start in "swiping" — host doesn't have to wait. Others can still
                # join while the session is in swiping state (see join()).
                status="swiping",
                location_lat=data.location_lat,
                location_lng=data.location_lng,
                location_label=data.location_label,
                members=[host_member],
                solo_mode=data.solo_mode,
                cuisine_overrides=data.cuisine_overrides,
                radius_km_override=data.radius_km_override,
                budget_overrides=data.budget_overrides,
                swipe_ceiling_override=data.swipe_ceiling_override,
            )
            try:
                await session.insert()
                return session
            except DuplicateKeyError as exc:
                last_error = exc
                continue
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not generate a unique session code",
        ) from last_error

    async def find_by_code(self, code: str) -> Session:
        normalized = code.upper()
        if not CODE_REGEX.match(normalized):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid session code format",
            )
        session = await Session.find_one(Session.code == normalized)
        if session is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Session not found",
            )
        return session

    async def get_by_id(self, session_id: UUID) -> Session:
        session = await Session.get(session_id)
        if session is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Session not found",
            )
        return session

    async def join(self, session_id: UUID, user: User) -> tuple[Session, SessionMember, bool]:
        session = await self.get_by_id(session_id)
        if session.status not in ("lobby", "swiping"):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Session is no longer accepting members",
            )
        for member in session.members:
            if member.user_id == user.id:
                return session, member, False
        if len(session.members) >= get_settings().max_session_members:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Session is full",
            )
        new_member = SessionMember(user_id=user.id, name=user.name)
        session.members.append(new_member)
        await session.save()
        return session, new_member, True

    async def start(self, session_id: UUID, user: User) -> Session:
        session = await self.get_by_id(session_id)
        if session.host_user_id != user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Only the host can start the session",
            )
        if session.status != "lobby":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Session is already in '{session.status}'",
            )
        session.status = "swiping"
        await session.save()
        return session

    async def get_user_sessions(self, user_id: UUID) -> list[Session]:
        # UUID fields are stored as BSON Binary (subtype 4) by Beanie, so the query
        # value must be a UUID object — not str(user_id) — or nothing will match.
        return (
            await Session.find({"members.user_id": user_id})
            .sort(-Session.created_at)
            .limit(20)
            .to_list()
        )

    def is_member(self, session: Session, user_id: UUID) -> bool:
        return any(m.user_id == user_id for m in session.members)

    async def leave(self, session_id: UUID, user_id: UUID) -> bool:
        """Remove user from session. Returns True if the session was deleted (last member left)."""
        # Import here to avoid a circular import (Swipe -> Session via tests etc.)
        from models.swipe import Swipe

        session = await self.get_by_id(session_id)
        if not self.is_member(session, user_id):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not a session member")

        session.members = [m for m in session.members if m.user_id != user_id]
        if not session.members:
            await Swipe.find(Swipe.session_id == session_id).delete()
            await session.delete()
            return True

        if session.host_user_id == user_id:
            # Promote the earliest-joined remaining member to host.
            session.host_user_id = session.members[0].user_id
        await session.save()
        return False

    async def delete(self, session_id: UUID, user_id: UUID) -> None:
        from models.swipe import Swipe

        session = await self.get_by_id(session_id)
        if session.host_user_id != user_id:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only the host can delete this session")
        await Swipe.find(Swipe.session_id == session_id).delete()
        await session.delete()

    @staticmethod
    def _generate_code() -> str:
        return "".join(secrets.choice(CODE_ALPHABET) for _ in range(CODE_LENGTH))


def get_session_service() -> SessionService:
    return SessionService()

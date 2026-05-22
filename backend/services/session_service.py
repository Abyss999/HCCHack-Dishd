import secrets
import string
from uuid import UUID

from fastapi import HTTPException, status
from pymongo.errors import DuplicateKeyError

from models.session import Session, SessionMember
from models.user import User
from schemas.session import SessionCreate

CODE_ALPHABET = string.ascii_uppercase + string.digits
CODE_LENGTH = 4
MAX_CODE_ATTEMPTS = 25


class SessionService:
    async def create(self, host: User, data: SessionCreate) -> Session:
        host_member = SessionMember(user_id=host.id, name=host.name)
        last_error: Exception | None = None
        for _ in range(MAX_CODE_ATTEMPTS):
            code = self._generate_code()
            session = Session(
                code=code,
                host_user_id=host.id,
                status="lobby",
                location_lat=data.location_lat,
                location_lng=data.location_lng,
                location_label=data.location_label,
                members=[host_member],
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
        session = await Session.find_one(Session.code == code.upper())
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

    def is_member(self, session: Session, user_id: UUID) -> bool:
        return any(m.user_id == user_id for m in session.members)

    @staticmethod
    def _generate_code() -> str:
        return "".join(secrets.choice(CODE_ALPHABET) for _ in range(CODE_LENGTH))


def get_session_service() -> SessionService:
    return SessionService()

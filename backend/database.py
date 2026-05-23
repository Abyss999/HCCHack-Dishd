from beanie import init_beanie
from motor.motor_asyncio import AsyncIOMotorClient

from config import get_settings


class Database:
    client: AsyncIOMotorClient | None = None

    @classmethod
    async def connect(cls) -> None:
        settings = get_settings()
        cls.client = AsyncIOMotorClient(
            settings.mongo_url,
            uuidRepresentation="standard",
            tz_aware=True,
        )
        await init_beanie(
            database=cls.client[settings.mongo_db_name],
            document_models=cls._document_models(),
        )

    @classmethod
    async def disconnect(cls) -> None:
        if cls.client is not None:
            cls.client.close()
            cls.client = None

    @staticmethod
    def _document_models() -> list[type]:
        # Imported lazily to avoid circular imports at module load.
        # Add new Document classes here as they're built in later phases.
        models: list[type] = []
        try:
            from models.user import User  # noqa: WPS433

            models.append(User)
        except ImportError:
            pass
        try:
            from models.session import Session  # noqa: WPS433

            models.append(Session)
        except ImportError:
            pass
        try:
            from models.restaurant import Restaurant  # noqa: WPS433

            models.append(Restaurant)
        except ImportError:
            pass
        try:
            from models.swipe import Swipe  # noqa: WPS433

            models.append(Swipe)
        except ImportError:
            pass
        try:
            from models.place_search_cache import PlaceSearchCache  # noqa: WPS433

            models.append(PlaceSearchCache)
        except ImportError:
            pass
        return models

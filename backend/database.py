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
        db = cls.client[settings.mongo_db_name]
        await cls._fix_indexes(db)
        await init_beanie(
            database=db,
            document_models=cls._document_models(),
        )

    @classmethod
    async def _fix_indexes(cls, db) -> None:
        # Beanie strips the sparse option when building createIndex commands, so we manage
        # the apple_id sparse unique index manually: drop any existing version, then recreate.
        try:
            await db["users"].drop_index("apple_id_1")
        except Exception:
            pass
        try:
            await db["users"].create_index(
                "apple_id", unique=True, sparse=True, name="apple_id_1"
            )
        except Exception:
            pass

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

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import get_settings
from database import Database


@asynccontextmanager
async def lifespan(app: FastAPI):
    await Database.connect()
    yield
    await Database.disconnect()


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title="DishMatch API", version="0.1.0", lifespan=lifespan)

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.get("/")
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": "dishmatch-api"}

    from routers import auth, restaurants, sessions, swipes, users

    app.include_router(auth.router)
    app.include_router(users.router)
    app.include_router(sessions.router)
    app.include_router(restaurants.router)
    app.include_router(swipes.router)

    return app


app = create_app()

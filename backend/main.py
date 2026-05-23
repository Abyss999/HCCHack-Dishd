from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware

from config import get_settings
from database import Database
from security import install_security, perform_startup_checks


@asynccontextmanager
async def lifespan(app: FastAPI):
    await Database.connect()
    yield
    await Database.disconnect()


def create_app() -> FastAPI:
    settings = get_settings()
    perform_startup_checks(settings)

    app = FastAPI(title="DishMatch API", version="0.1.0", lifespan=lifespan)

    # Outer-to-inner: trusted host → gzip → security headers → size limit → slowapi → CORS → routes.
    if "*" not in settings.allowed_hosts:
        app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.allowed_hosts)
    app.add_middleware(GZipMiddleware, minimum_size=1024)
    install_security(app, settings)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=settings.cors_allow_credentials,
        allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type"],
    )

    @app.get("/")
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": "dishmatch-api"}

    from routers import auth, recommendations, restaurants, sessions, swipes, users

    app.include_router(auth.router)
    app.include_router(users.router)
    app.include_router(sessions.router)
    app.include_router(restaurants.router)
    app.include_router(swipes.router)
    app.include_router(recommendations.router)

    return app


app = create_app()

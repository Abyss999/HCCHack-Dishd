"""Shared fixtures: spin up the real FastAPI app against the configured Mongo
(Atlas per .env) and hand back an httpx AsyncClient bound to it.

Rate limits are disabled so we can run a 3-user session inside the signup limit
window. All users/sessions/swipes created during a test are tagged with a
random run-id and cleaned up afterward.

Motor binds an event loop on first use, so we (re)connect the DB inside each
test's loop and disconnect after — keeps things simple under pytest-asyncio's
per-test loop default.
"""

from __future__ import annotations

import os
import uuid
from collections.abc import AsyncIterator

import pytest_asyncio

# Force rate-limiter off BEFORE importing the app (settings are cached).
os.environ["RATE_LIMIT_ENABLED"] = "false"

from httpx import ASGITransport, AsyncClient  # noqa: E402
import subprocess
import sys
import socket
import asyncio
import time
import httpx as _httpx

from motor.motor_asyncio import AsyncIOMotorClient  # noqa: E402
from config import get_settings  # noqa: E402

from main import app  # noqa: E402
from models.session import Session  # noqa: E402
from models.swipe import Swipe  # noqa: E402
from models.user import User  # noqa: E402


@pytest_asyncio.fixture
async def client() -> AsyncIterator[AsyncClient]:
    """Return an AsyncClient bound to the app.

    Do NOT pre-connect the Database here: the FastAPI app's lifespan handler
    will call `Database.connect()` inside the ASGI/app event loop. Creating a
    Motor/Beanie client on the pytest loop leads to "Future attached to a
    different loop" errors when the app services use the DB.
    """
    # Using `app=` ensures the AsyncClient triggers the ASGI lifespan events
    # (startup/shutdown) so the app's `lifespan` connects/disconnects the DB in
    # the correct event loop.
    # Start a real Uvicorn server in a subprocess. Running a separate process
    # avoids any event-loop affinity issues between Motor/Beanie and the test
    # runner (httpx ASGI transport + anyio). The subprocess will create its
    # own event loop and DB client.
    def _get_free_port() -> int:
        s = socket.socket()
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]
        s.close()
        return port

    port = _get_free_port()
    host = "127.0.0.1"
    base_url = f"http://{host}:{port}"

    env = os.environ.copy()
    # Run uvicorn with the test venv's Python to ensure same deps.
    cmd = [sys.executable, "-m", "uvicorn", "main:app", "--host", host, "--port", str(port), "--log-level", "warning", "--loop", "asyncio"]
    proc = subprocess.Popen(cmd, cwd="/Users/kuldeepojha/Desktop/HCCHack/backend", env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    # Wait for the server to respond on the health endpoint.
    async def _wait_ready(timeout: float = 10.0) -> None:
        async with _httpx.AsyncClient(base_url=base_url) as wait_client:
            start = time.time()
            while True:
                try:
                    r = await wait_client.get("/")
                    if r.status_code == 200:
                        return
                except Exception:
                    pass
                if time.time() - start > timeout:
                    raise RuntimeError("uvicorn server did not start in time")
                await asyncio.sleep(0.1)

    try:
        await _wait_ready()
        c = AsyncClient(base_url=base_url)
        await c.__aenter__()
        try:
            yield c
        finally:
            # Ensure client is closed; ignore loop-closed errors which can
            # happen during pytest/asyncio teardown races on some macOS
            # environments.
            try:
                await c.__aexit__(None, None, None)
            except RuntimeError:
                pass
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except Exception:
            proc.kill()


@pytest_asyncio.fixture
async def run_tag(client) -> AsyncIterator[str]:
    """A unique tag we embed in email addresses so we can clean up after.

    The fixture depends on `client` so its finalizer runs before the client's
    finalizer (while the app is still running). Cleanup uses a test-loop
    `AsyncIOMotorClient` and raw collection operations to avoid Beanie's loop
    affinity.
    """
    tag = f"itest-{uuid.uuid4().hex[:10]}"
    yield tag
    # cleanup: use a fresh Motor client in this loop to remove test artifacts.
    settings = get_settings()
    mclient = AsyncIOMotorClient(settings.mongo_url)
    try:
        db = mclient[settings.mongo_db_name]
        # delete swipes for sessions owned by users with the tag
        users_coll = db["users"]
        sessions_coll = db["sessions"]
        swipes_coll = db["swipes"]

        users = await users_coll.find({"email": {"$regex": tag}}).to_list(length=None)
        user_ids = [u.get("_id") for u in users]
        if user_ids:
            sessions = await sessions_coll.find({"host_user_id": {"$in": user_ids}}).to_list(length=None)
            session_ids = [s.get("_id") for s in sessions]
            if session_ids:
                await swipes_coll.delete_many({"session_id": {"$in": session_ids}})
                await sessions_coll.delete_many({"_id": {"$in": session_ids}})
            await users_coll.delete_many({"_id": {"$in": user_ids}})
    finally:
        mclient.close()

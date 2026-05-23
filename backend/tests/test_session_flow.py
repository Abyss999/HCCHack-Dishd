"""End-to-end tests for the join-by-code + multi-user swipe flow.

These exercise the real FastAPI app and the real Mongo backend configured in
.env. They simulate three users:
  1. Host signs up, creates a session, gets a 4-char code.
  2. Two friends sign up and JOIN by looking up `/sessions/{code}` then POSTing
     to `/sessions/{session_id}/join`.
  3. Host starts the session (phase -> "swiping").
  4. All three swipe "yes" on the same restaurant -> instant match.
  5. A separate test covers majority/Top-3 (not unanimous).
"""

from __future__ import annotations

from uuid import UUID

import pytest
from httpx import AsyncClient


pytestmark = pytest.mark.asyncio


async def _signup(client: AsyncClient, email: str, name: str) -> str:
    r = await client.post(
        "/auth/signup",
        json={"email": email, "password": "password123", "name": name},
    )
    assert r.status_code == 201, r.text
    return r.json()["access_token"]


def _auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


async def _list_restaurants(client: AsyncClient, token: str, session_id: str) -> list[dict]:
    r = await client.get(
        "/restaurants",
        params={"session_id": session_id},
        headers=_auth(token),
    )
    assert r.status_code == 200, r.text
    return r.json()


async def _swipe(
    client: AsyncClient, token: str, session_id: str, restaurant_id: str, direction: str
) -> dict:
    r = await client.post(
        f"/sessions/{session_id}/swipe",
        json={"restaurant_id": restaurant_id, "direction": direction},
        headers=_auth(token),
    )
    assert r.status_code == 200, r.text
    return r.json()


# --------------------------------------------------------------------------- #
# Tests                                                                       #
# --------------------------------------------------------------------------- #


async def test_join_by_code_three_users(client: AsyncClient, run_tag: str) -> None:
    """Host creates a session, two friends find it by code and join."""
    host_t = await _signup(client, f"host-{run_tag}@example.com", "Host")
    a_t = await _signup(client, f"alice-{run_tag}@example.com", "Alice")
    b_t = await _signup(client, f"bob-{run_tag}@example.com", "Bob")

    # Host creates a session.
    r = await client.post(
        "/sessions",
        json={"location_lat": 40.73, "location_lng": -74.0, "location_label": "NYC"},
        headers=_auth(host_t),
    )
    assert r.status_code == 201, r.text
    session = r.json()
    code = session["code"]
    session_id = session["id"]
    assert len(code) == 4 and code.isalnum() and code.isupper()
    assert len(session["members"]) == 1
    assert session["status"] == "lobby"

    # Alice & Bob find by code (lookup), then join by id.
    for token in (a_t, b_t):
        r = await client.get(f"/sessions/{code}", headers=_auth(token))
        assert r.status_code == 200, r.text
        assert r.json()["id"] == session_id

        r = await client.post(f"/sessions/{session_id}/join", headers=_auth(token))
        assert r.status_code == 200, r.text

    # Final state: 3 members.
    r = await client.get(f"/sessions/{session_id}/status", headers=_auth(host_t))
    assert r.status_code == 200
    assert len(r.json()["members"]) == 3
    names = {m["name"] for m in r.json()["members"]}
    assert names == {"Host", "Alice", "Bob"}


async def test_join_by_code_case_insensitive(client: AsyncClient, run_tag: str) -> None:
    host_t = await _signup(client, f"host2-{run_tag}@example.com", "Host")
    r = await client.post("/sessions", json={}, headers=_auth(host_t))
    code = r.json()["code"]

    # lowercased code should still resolve.
    r = await client.get(f"/sessions/{code.lower()}", headers=_auth(host_t))
    assert r.status_code == 200
    assert r.json()["code"] == code


async def test_bad_code_returns_404(client: AsyncClient, run_tag: str) -> None:
    host_t = await _signup(client, f"host3-{run_tag}@example.com", "Host")
    r = await client.get("/sessions/ZZZZ", headers=_auth(host_t))
    assert r.status_code == 404


async def test_unanimous_yes_triggers_instant_match(
    client: AsyncClient, run_tag: str
) -> None:
    """Three users join, host starts, all swipe yes on the same restaurant -> match."""
    host_t = await _signup(client, f"hostm-{run_tag}@example.com", "Host")
    a_t = await _signup(client, f"alicem-{run_tag}@example.com", "Alice")
    b_t = await _signup(client, f"bobm-{run_tag}@example.com", "Bob")

    r = await client.post("/sessions", json={}, headers=_auth(host_t))
    session = r.json()
    session_id = session["id"]

    for token in (a_t, b_t):
        await client.post(f"/sessions/{session_id}/join", headers=_auth(token))

    # Host starts.
    r = await client.post(f"/sessions/{session_id}/start", headers=_auth(host_t))
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "swiping"

    # Non-host cannot start.
    r = await client.post(f"/sessions/{session_id}/start", headers=_auth(a_t))
    assert r.status_code in (403, 409)

    # Load the mock restaurant list (Google Places key is empty in .env, so the
    # backend persists the bundled mocks).
    restaurants = await _list_restaurants(client, host_t, session_id)
    assert len(restaurants) >= 1
    target = restaurants[0]["id"]
    other = restaurants[1]["id"]

    # All three swipe yes on the same restaurant.
    ack1 = await _swipe(client, host_t, session_id, target, "yes")
    assert ack1["instant_match"] is None  # only host has voted

    ack2 = await _swipe(client, a_t, session_id, target, "yes")
    assert ack2["instant_match"] is None  # still need bob

    ack3 = await _swipe(client, b_t, session_id, target, "yes")
    assert ack3["instant_match"] is not None, ack3
    assert ack3["instant_match"]["id"] == target

    # Session is now matched and frozen on the matched restaurant.
    r = await client.get(f"/sessions/{session_id}/status", headers=_auth(host_t))
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "matched"
    assert body["matched_restaurant_id"] == target

    # Swiping after match is rejected.
    r = await client.post(
        f"/sessions/{session_id}/swipe",
        json={"restaurant_id": other, "direction": "yes"},
        headers=_auth(host_t),
    )
    assert r.status_code == 409


async def test_majority_yields_top3_with_majority_winner(
    client: AsyncClient, run_tag: str
) -> None:
    """Two yes / one no on a restaurant. No instant match. Top-3 ranks it first."""
    host_t = await _signup(client, f"hostt-{run_tag}@example.com", "Host")
    a_t = await _signup(client, f"alicet-{run_tag}@example.com", "Alice")
    b_t = await _signup(client, f"bobt-{run_tag}@example.com", "Bob")

    r = await client.post("/sessions", json={}, headers=_auth(host_t))
    session_id = r.json()["id"]
    for token in (a_t, b_t):
        await client.post(f"/sessions/{session_id}/join", headers=_auth(token))
    await client.post(f"/sessions/{session_id}/start", headers=_auth(host_t))

    restaurants = await _list_restaurants(client, host_t, session_id)
    r1 = restaurants[0]["id"]
    r2 = restaurants[1]["id"]
    r3 = restaurants[2]["id"]

    # r1: host yes, alice yes, bob no -> 2/3
    # r2: host yes, alice no -> 1/3
    # r3: all no -> 0/3
    ack = await _swipe(client, host_t, session_id, r1, "yes")
    assert ack["instant_match"] is None
    ack = await _swipe(client, a_t, session_id, r1, "yes")
    assert ack["instant_match"] is None  # bob hasn't voted yet, no unanimity possible
    await _swipe(client, b_t, session_id, r1, "no")

    await _swipe(client, host_t, session_id, r2, "yes")
    await _swipe(client, a_t, session_id, r2, "no")

    await _swipe(client, host_t, session_id, r3, "no")

    # Results endpoint: r1 should rank first with 2 yes.
    r = await client.get(f"/sessions/{session_id}/results", headers=_auth(host_t))
    assert r.status_code == 200
    top = r.json()["top"]
    assert len(top) >= 1
    assert top[0]["restaurant"]["id"] == r1
    assert top[0]["yes_count"] == 2
    assert top[0]["total"] == 3
    assert top[0]["score_pct"] == 67  # round(2/3*100)


async def test_duplicate_swipe_rejected(client: AsyncClient, run_tag: str) -> None:
    host_t = await _signup(client, f"hostd-{run_tag}@example.com", "Host")
    r = await client.post("/sessions", json={}, headers=_auth(host_t))
    session_id = r.json()["id"]
    await client.post(f"/sessions/{session_id}/start", headers=_auth(host_t))

    restaurants = await _list_restaurants(client, host_t, session_id)
    target = restaurants[0]["id"]
    # First swipe ok; on a solo session it instant-matches, so use a "no" to
    # keep the session in swiping state for the duplicate check.
    ack = await _swipe(client, host_t, session_id, target, "no")
    assert ack["accepted"] is True

    r = await client.post(
        f"/sessions/{session_id}/swipe",
        json={"restaurant_id": target, "direction": "no"},
        headers=_auth(host_t),
    )
    assert r.status_code == 409


async def test_non_member_cannot_swipe(client: AsyncClient, run_tag: str) -> None:
    host_t = await _signup(client, f"hostn-{run_tag}@example.com", "Host")
    outsider_t = await _signup(client, f"out-{run_tag}@example.com", "Outsider")

    r = await client.post("/sessions", json={}, headers=_auth(host_t))
    session_id = r.json()["id"]
    await client.post(f"/sessions/{session_id}/start", headers=_auth(host_t))

    restaurants = await _list_restaurants(client, host_t, session_id)
    target = restaurants[0]["id"]

    r = await client.post(
        f"/sessions/{session_id}/swipe",
        json={"restaurant_id": target, "direction": "yes"},
        headers=_auth(outsider_t),
    )
    assert r.status_code == 403

# DishMatch

Group restaurant decision app. Friends join a session via a 4-digit code, swipe yes/no on nearby restaurants, and the app either declares an **instant match** (every member said yes to the same place) or shows a **Top 3** leaderboard ranked by yes-count percentage. Also supports **solo mode** — one user swipes alone to get a personal top pick.

## Stack

| Layer | Tech |
|---|---|
| Mobile | SwiftUI (iOS 16+) |
| Backend | FastAPI (async) |
| Database | MongoDB via Beanie (Motor + Pydantic) |
| Auth | JWT access + refresh (`python-jose`), bcrypt (`passlib`) |
| Realtime | FastAPI WebSockets |
| Restaurants | Google Places API (Nearby Search + Details/editorial_summary), 6h DB cache, `?mock=true` / `USE_MOCK_RESTAURANTS` fallback |
| Push | APNs (UNUserNotificationCenter) |
| Local dev | Docker Compose (mongo + mongo-express) — or MongoDB Atlas |
| Production target | DigitalOcean (App Platform or Droplet) |

## Repo layout

```
HCCHack/
├── backend/           FastAPI + Beanie + MongoDB
├── mobile-swift/      SwiftUI iOS app (iOS 16+, xcodegen project)
└── CLAUDE.md          Project context for Claude Code sessions
```

## Run it

### Backend

```bash
cd backend
docker compose up -d                       # mongo + mongo-express (local target only)
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env                       # fill JWT_SECRET + GOOGLE_PLACES_API_KEY
uvicorn main:app --reload --port 8001      # http://localhost:8001/docs
```

- Health check: `curl http://localhost:8001/` → `{"status":"ok","service":"dishmatch-api"}`
- Mongo admin UI: `http://localhost:8081` (admin/admin) when using the local Docker target.
- Toggle Mongo target with `MONGO_TARGET=local|atlas` in `.env`.
- Set `USE_MOCK_RESTAURANTS=true` to force the hardcoded NYC restaurant list (skips Google Places). The same effect is available per-request via `?mock=true` on `/restaurants`.

### Mobile (iOS)

```bash
open mobile-swift/DishMatch.xcodeproj      # then Cmd+R
```

- The simulator's `localhost` reaches your laptop. Real devices need your laptop's LAN IP — edit `API_BASE_URL` in `mobile-swift/DishMatch/Config/Debug.xcconfig` (e.g. `http://192.168.1.42:8001`).
- The project is generated with [xcodegen](https://github.com/yonaskolb/XcodeGen) (`mobile-swift/project.yml`); re-run `xcodegen` if you change the spec.

## Smoke test

1. Open `http://localhost:8001/docs`, hit `POST /auth/signup` with `{email, password (8+ chars), name}` → you get an access token.
2. In the iOS app, sign up / log in with the same flow.
3. **Create Session** on Home → pick a location on the map → land directly in the swipe view (no lobby — the share code is shown in the header).
4. From a second simulator/device, sign in as a different user, paste the code into **Join a Session** — they land in the same swipe view live.
5. Swipe yes/no. On unanimous yes (with ≥2 members) → instant-match overlay fires. After 10 swipes per member → Top 3 leaderboard. Tap a result row to open in Apple Maps or Google Maps.
6. **Solo Swipe** is a separate entrypoint — single-member session, first yes is the match.

> `/restaurants?session_id=…` returns the mock list if `GOOGLE_PLACES_API_KEY` is unset, `USE_MOCK_RESTAURANTS=true`, or the request includes `?mock=true`. The Swift client also races real fetches against a 20s timeout and auto-falls-back to mocks on failure, so the swipe stack is never empty.

## API surface

```
POST  /auth/signup | /auth/login | /auth/refresh
GET   /users/me                          PUT /users/me/preferences
POST  /users/me/push-token
GET   /users/me/sessions                 # last 20 sessions you've been a member of
POST  /sessions                          GET /sessions/{code}
POST  /sessions/{id}/join                POST /sessions/{id}/start       # rate-limited
POST  /sessions/{id}/leave               DELETE /sessions/{id}            # rate-limited; delete is host only
GET   /sessions/{id}/status              GET /sessions/{id}/results
GET   /restaurants?session_id=...[&mock=true]
POST  /sessions/{id}/swipe
WS    /ws/sessions/{id}?token=...
        events: member_joined | swipe_progress | instant_match
                | phase_change | top3_ready
```

## Restaurant data + caching

- `GET /restaurants?session_id=…` returns up to ~20 results around the session's pinned `(lat, lng)`, filtered by the effective `GroupFilter` (intersected member prefs *or* session overrides).
- The query result is memoized in `place_search_caches` keyed by a SHA-256 of `(round(lat, 3), round(lng, 3), radius_m, sorted(cuisines), max_price_level)`. TTL is **6 hours** via a Mongo `expireAfterSeconds=0` index on `expires_at`. Subsequent calls inside the cache window skip Google Places entirely and rehydrate from the `restaurants` collection.
- **Budget filter is multi-select.** `Session.budget_overrides` is a list of tiers (e.g. `["$$", "$$$"]`). The Places API call uses `max_price_level = max(levels)` so the network response is narrow; results are then post-filtered to the exact selected tiers. Restaurants without a `price_tier` are kept (Google often omits it).
- Each restaurant document is upserted by `google_place_id`. On first sight we also fire a one-shot **Places Details** call with `fields=editorial_summary` to populate `description` (capped at ~180 chars). Surfaced on swipe cards and result rows.

## Session lifecycle

- **Create** → session is born in `status="swiping"` (both solo and group). The host can swipe immediately.
- **Join** → allowed while status is `"lobby"` or `"swiping"`. New members start contributing to the yes-aggregation on their next swipe.
- **Instant match** → broadcast when every current member has said yes to the same restaurant. Suppressed for non-solo sessions with fewer than 2 members (so the host doesn't auto-match on their first yes).
- **Top 3** → finalized once every member has swiped at least 10 times (`SWIPE_CEILING`).

## Security model (short version)

- All routes rate-limited via `slowapi` (env-configurable per route: auth, swipe, places, etc.). Keyed per-user when authed, per-IP otherwise.
- Security headers: CSP, HSTS, `X-Frame-Options: DENY`, `Referrer-Policy`, `Permissions-Policy`.
- Request body capped at 1 MB (configurable).
- Production startup refuses to boot if `JWT_SECRET` is the placeholder / < 32 chars or if CORS is wildcard.
- Inputs are Pydantic models — no raw user dicts ever reach Mongo (NoSQL-injection-free by construction).
- Session codes enforced by regex; sessions capped at `MAX_SESSION_MEMBERS` (12).
- WebSocket validates JWT + session membership on connect; frames capped at 1024 bytes.

## Design tokens

The app is dark-first. Key hex values (all in `AppTheme.swift`):

| Token | Dark | Light |
|---|---|---|
| Background | `#0a0a0a` | `#faf9f7` |
| Surface | `#1a1a1a` | `#f2efeb` |
| Primary (coral) | `#d97757` | `#d97757` |
| Like (green) | `#4caf50` | `#4caf50` |
| Pass (red) | `#ef5350` | `#ef5350` |

Full details — including UI design tokens, simulator-noise tables, and per-component patterns — in [CLAUDE.md](./CLAUDE.md).

## Deployment

The backend is containerized (`backend/Dockerfile`) and config-via-env, so it drops onto DigitalOcean App Platform or a Droplet with no code changes. Set `ENVIRONMENT=production`, a strong `JWT_SECRET`, explicit `CORS_ORIGINS`, and an Atlas connection string in `MONGO_URL_ATLAS` (with `MONGO_TARGET=atlas`).

## Roadmap

The current matching logic uses simple yes-count aggregation. A future phase will swap `MatchingService` for a vector-based welfare function over MongoDB Atlas Vector Search (Gemini embeddings of dish/mood data). Config is structured so the Atlas swap is just an env var change.

# DishMatch

Group restaurant decision app. Friends join a session via a 4-digit code, swipe yes/no on nearby restaurants, and the app either declares an **instant match** (every member said yes to the same place) or a **Top 3** leaderboard ranked by yes-count percentage.

## Stack

| Layer | Tech |
|---|---|
| Mobile | React Native (Expo) + NativeWind |
| Backend | FastAPI (Python, async) |
| Database | MongoDB |
| ODM | Beanie (Motor + Pydantic) |
| Auth | JWT access + refresh via `python-jose`, bcrypt via `passlib` |
| Realtime | FastAPI WebSockets |
| Restaurants | Google Places API |
| Push | Expo Push API |
| Local dev | Docker Compose (mongo + mongo-express) |
| Production target | DigitalOcean (App Platform or Droplet running the same container stack) |

## Repo layout

```
HCCHack/
├── backend/
│   ├── main.py                      # FastAPI app + lifespan
│   ├── config.py                    # Settings (pydantic-settings)
│   ├── database.py                  # Mongo client + Beanie init
│   ├── deps.py                      # get_current_user, etc.
│   ├── routers/                     # thin HTTP layer
│   │   ├── auth.py
│   │   ├── users.py
│   │   ├── sessions.py
│   │   ├── restaurants.py
│   │   └── swipes.py
│   ├── models/                      # Beanie Document classes (DB)
│   │   ├── user.py
│   │   ├── session.py
│   │   ├── restaurant.py
│   │   └── swipe.py
│   ├── schemas/                     # Pydantic request/response models
│   ├── services/                    # OOP business logic
│   │   ├── auth_service.py
│   │   ├── session_service.py
│   │   ├── places_service.py
│   │   ├── matching_service.py
│   │   └── notification_service.py
│   ├── ws/
│   │   └── manager.py               # ConnectionManager
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── .env.example
│   └── requirements.txt
└── mobile/
    ├── app/                         # expo-router (placeholder for now)
    ├── tailwind.config.js
    └── package.json
```

## Architectural decisions

- **Beanie ODM** over raw Motor — gives us OOP `Document` classes with Pydantic validation and index declarations in one place.
- **OOP throughout the backend** — business logic lives in service classes (`AuthService`, `SessionService`, `MatchingService`, `PlacesService`, `NotificationService`, `ConnectionManager`). Routers stay thin: parse request → call service → return schema.
- **UUIDs for every ID**, not Mongo ObjectIds.
- **Document shape:** embed bounded sub-docs (`UserPreferences`, `PushToken[]` inside `User`; `SessionMember[]` inside `Session`). Separate collections for unbounded data (`swipes`, `restaurants`).
- **Cache restaurants** — never call Google Places per-swipe. Upsert into the `restaurants` collection keyed by `google_place_id`.
- **WebSocket auth** — JWT passed as `?token=` query param; `ConnectionManager` keeps `dict[session_id, dict[user_id, WebSocket]]`.
- **AI/vector matching is deferred.** Phase 1 ships simple aggregation-based matching. A later phase will add Gemini embeddings + MongoDB Atlas Vector Search; config is structured so the Atlas swap is just an env var change.
- **Containerization first.** No host-path assumptions, all config via env vars, single `Dockerfile` for the API — so DigitalOcean deploy is a non-event later.

## Running locally

```bash
# from backend/
docker compose up -d                    # mongo + mongo-express
pip install -r requirements.txt
cp .env.example .env                    # then fill values
uvicorn main:app --reload               # http://localhost:8000/docs

# from mobile/
npx expo start
```

## Conventions

- **Async everywhere on the backend** — Motor + Beanie are async; never use sync DB calls.
- **Service classes own business logic.** A router function should be ~5 lines: validate inputs, call a service method, return a response schema.
- **One Beanie `Document` per collection.** Indexes go in the `Settings` inner class.
- **Schemas vs models:** `models/` = DB documents, `schemas/` = HTTP request/response Pydantic models. Never return a `Document` directly from an endpoint.
- **WS events** are JSON `{type, payload}` envelopes. Event types: `member_joined`, `swipe_progress`, `instant_match`, `phase_change`, `top3_ready`.
- **Session codes** are 4 uppercase alphanumeric chars, regenerated on collision.
- **Swipe phase** has a soft floor of 5 and a hard ceiling of 10 swipes per user before Top 3 is forced.

## Pointers

- Phase plan: `/Users/nosaj/.claude/plans/dishmatch-claude-splendid-volcano.md`

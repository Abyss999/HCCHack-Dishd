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
│   ├── security.py                  # rate limiter, headers, size limits, startup checks
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── .env.example
│   └── requirements.txt
└── mobile/
    ├── src/
    │   ├── app/                     # expo-router file-based routing
    │   │   ├── (tabs)/              # bottom tab navigator (index, profile)
    │   │   ├── auth/                # login.tsx, signup.tsx
    │   │   ├── session/             # lobby.tsx, swipe.tsx, results.tsx
    │   │   └── _layout.tsx          # root layout + auth gate
    │   ├── components/              # RestaurantCard, SwipeStack, MatchModal, etc.
    │   ├── context/                 # React context providers
    │   ├── hooks/                   # useAuth, useColors, etc.
    │   └── global.css               # NativeWind global styles
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
docker compose up -d                    # mongo + mongo-express (only needed for local target)
pip install -r requirements.txt
cp .env.example .env                    # then fill values
uvicorn main:app --reload               # http://localhost:8000/docs

# from mobile/
npx expo start
```

## MongoDB target switching

The backend supports two Mongo targets, toggled by a single env var in `backend/.env`:

| `MONGO_TARGET` | URL used | When to use |
|---|---|---|
| `local` (default) | `MONGO_URL_LOCAL` (`mongodb://localhost:27017`) | Local dev with Docker Compose |
| `atlas` | `MONGO_URL_ATLAS` | Shared Atlas cluster, no Docker needed |

**To switch to Atlas:** set `MONGO_TARGET=atlas` in `.env`. The Atlas cluster is `hackhcc.k4x55rs.mongodb.net` (`HackHCC` app). Credentials are already in `.env`.

**To go back to local:** set `MONGO_TARGET=local` and make sure `docker compose up -d` is running.

`config.py` exposes a `@property mongo_url` that resolves the active URL; `database.py` consumes it — no other files need changing when switching targets.

## Security model

All security primitives live in `backend/security.py` and are wired in `main.py`.

**Middleware stack (outer → inner):**
1. `TrustedHostMiddleware` — only enabled when `ALLOWED_HOSTS` is not `["*"]`.
2. `GZipMiddleware` — compresses responses ≥ 1 KB.
3. `SecurityHeadersMiddleware` — sets `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`, `Permissions-Policy` (deny geo/mic/cam), `Strict-Transport-Security`, and a hardened `Content-Security-Policy` (`default-src 'none'; frame-ancestors 'none'`).
4. `RequestSizeLimitMiddleware` — rejects requests > `MAX_REQUEST_BODY_BYTES` (default 1 MB) with 413.
5. `SlowAPIMiddleware` + per-route `@limiter.limit(...)` — rate limits keyed per-user when authenticated (`request.state.user_id`) and per-IP otherwise.
6. `CORSMiddleware` — `allow_credentials` is auto-`False` whenever origins is wildcard (browsers reject the combination anyway).

**Rate limit knobs (env, slowapi syntax):**
- `RATE_LIMIT_DEFAULT` — fallback for unspecified routes (100/min)
- `RATE_LIMIT_SIGNUP` — 5/min, `RATE_LIMIT_LOGIN` — 10/min, `RATE_LIMIT_REFRESH` — 30/min
- `RATE_LIMIT_SESSION_CREATE` — 10/min, `RATE_LIMIT_SESSION_JOIN` — 20/min
- `RATE_LIMIT_SWIPE` — 60/min (≈ 1/sec)
- `RATE_LIMIT_RESTAURANTS` — 20/min (protects the Google Places bill)
- `RATE_LIMIT_PUSH_TOKEN` — 10/min
- `RATE_LIMIT_ENABLED=false` disables everything for local debugging

**Startup checks (`perform_startup_checks`):** in `ENVIRONMENT=production` the app *refuses to boot* if `JWT_SECRET` is the placeholder or shorter than 32 chars, or if `CORS_ORIGINS` contains `*`. In dev, the same conditions log a warning.

**Input hardening:**
- All HTTP payloads are Pydantic models — no raw dicts reach Mongo.
- Session codes are validated by regex (`^[A-Za-z0-9]{4}$`) both at the path-param layer and inside `SessionService.find_by_code`.
- Sessions are capped at `MAX_SESSION_MEMBERS` (default 12).
- Free-text fields have explicit `max_length` caps (e.g., `location_label` ≤ 120, push token ≤ 512, preference list lengths ≤ 20).
- Password minimum length: 8.

**Injection posture:**
- **NoSQL injection:** ruled out by inspection — every query uses Beanie's typed operator API (`Model.field == value`); aggregation pipelines are built from server-controlled UUIDs only; user-controlled strings are never spliced into raw query dicts.
- **SQL injection:** N/A (no SQL).
- **Prompt injection:** N/A in the current scope (LLM/embeddings live behind a deferred phase). When the vector phase lands, the same `services/`-class boundary will isolate any LLM input from query construction.

**WebSocket hardening:**
- JWT validated on connect; non-members rejected with 4403, expired/invalid with 4401, unknown session with 4404.
- Inbound frames are capped at 1024 bytes; oversized frames close the socket with 1009.

**Token storage:** access tokens are 30 minutes by default; refresh tokens 30 days. Token `type` claim is checked on decode so a refresh token can never be used as access.

## Conventions

- **Async everywhere on the backend** — Motor + Beanie are async; never use sync DB calls.
- **Service classes own business logic.** A router function should be ~5 lines: validate inputs, call a service method, return a response schema.
- **One Beanie `Document` per collection.** Indexes go in the `Settings` inner class.
- **Schemas vs models:** `models/` = DB documents, `schemas/` = HTTP request/response Pydantic models. Never return a `Document` directly from an endpoint.
- **WS events** are JSON `{type, payload}` envelopes. Event types: `member_joined`, `swipe_progress`, `instant_match`, `phase_change`, `top3_ready`.
- **Session codes** are 4 uppercase alphanumeric chars, regenerated on collision.
- **Swipe phase** has a soft floor of 5 and a hard ceiling of 10 swipes per user before Top 3 is forced.
- **Email normalization** — always `.lower()` emails before DB reads/writes (`AuthService.signup` and `AuthService.login`). The mobile layer also trims and lowercases before sending so the backend never sees mixed-case addresses.
- **Mobile text inputs** — email fields must have `autoCapitalize="none"` `autoCorrect={false}` `autoComplete="email"` `textContentType="emailAddress"`. Password fields use `textContentType="password"` (login) or `textContentType="newPassword"` (signup) with matching `autoComplete` values. Frontend password min-length must match the backend schema (`min_length=8`).

## UI design system

The mobile design is dark-first, warm coral (`#d97757`) primary, referencing `/Users/nosaj/Downloads/DishMatch Redesign Standalone.html` as the visual source of truth.

**Color tokens** live in two places that must stay in sync:
- `mobile/tailwind.config.js` — Tailwind theme (used for `className` utilities)
- `mobile/src/hooks/useColors.ts` — imperative `LIGHT`/`DARK` objects (used for inline `style={}`)

Key dark-mode values: `bg: #0a0a0a`, `surface: #1a1a1a`, `surfaceLight: #262626`. New tokens added: `cardBorder`, `chipBg`, `chipBorder`, `progressBg` — all primary-tinted rgba values.

**Component patterns (match the HTML design):**
- **Buttons** — primary uses `borderRadius: 10`, `paddingVertical: 14`, coral shadow (`shadowColor: primary, opacity: 0.3`). No `expo-linear-gradient` installed; use solid primary color.
- **Cards** — `borderRadius: 12`, `borderWidth: 1`, `borderColor: colors.cardBorder`.
- **Chips/tags** — `borderRadius: 8`, `chipBg` + `chipBorder`, never use pill shape (`borderRadius: 999`) for preference chips.
- **Inputs** — `borderRadius: 10`, `fontFamily: IBM Plex Mono`, `borderColor: colors.inputBorder` (primary at ~25% opacity).
- **Progress bars** — `height: 3`, `backgroundColor: colors.progressBg` track, primary fill.
- **Restaurant card** — has both swipe gestures AND visible Pass/Like buttons at the bottom of the info section.
- **Results list** — compact flat list with 40×40 square rank badges (medal emoji 🥇🥈🥉) and a slim 2px agreement bar. No full image cards.
- **Profile section titles** — `fontSize: 11, fontWeight: "700", letterSpacing: 0.6, textTransform: "uppercase"`, muted `rgba(255,255,255,0.5)`.
- **CodeDisplay boxes** — 50×50, `borderColor: rgba(217,119,87,0.4)`, IBM Plex Mono 18px primary text.
- **Home header** — compact with `borderBottomColor: rgba(255,255,255,0.06)` divider.
- **"How it works" tips** — left-border accent block: `borderLeftWidth: 3, borderLeftColor: rgba(217,119,87,0.4)`, warm-tinted bg.

## Pointers

- Phase plan: `/Users/nosaj/.claude/plans/dishmatch-claude-splendid-volcano.md`

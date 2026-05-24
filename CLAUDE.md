# Dishd

> 🏆 1st Place — DigitalOcean Track @ HCCHack (May 22–23, 2025)

Group restaurant decision app. Friends join a session via a 4-digit code, swipe yes/no on nearby restaurants, and the app either declares an **instant match** (every member said yes to the same place) or a **Top 3** leaderboard ranked by yes-count percentage. Also supports **solo mode** — one user swipes alone to get a personal top pick.

## Stack

| Layer | Tech |
|---|---|
| Mobile | SwiftUI (iOS 16+) |
| Backend | FastAPI (Python, async) |
| Database | MongoDB |
| ODM | Beanie (Motor + Pydantic) |
| Auth | JWT access + refresh via `python-jose`, bcrypt via `passlib` |
| Realtime | FastAPI WebSockets |
| Restaurants | Google Places API |
| AI | Google Gemini 2.5 Flash (`google-generativeai` SDK) |
| Push | APNs (UNUserNotificationCenter) |
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
│   │   ├── notification_service.py
│   │   └── gemini_service.py        # Gemini 2.5 Flash: vibe blurb, vibe pick, personalized fit
│   ├── ws/
│   │   └── manager.py               # ConnectionManager
│   ├── security.py                  # rate limiter, headers, size limits, startup checks
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── .env.example
│   └── requirements.txt
└── mobile-swift/                    # SwiftUI iOS app (iOS 16+)
    ├── DishMatch.xcodeproj
    ├── project.yml                  # xcodegen spec
    └── DishMatch/
        ├── App/                     # DishdApp, AppDelegate, ContentCoordinator + navigators
        ├── Core/
        │   ├── Auth/                # AuthStore (@ObservableObject), KeychainService
        │   ├── Network/             # APIClient (URLSession), NetworkError
        │   ├── WebSocket/           # WebSocketService (URLSessionWebSocketTask, auto-reconnect)
        │   ├── Notifications/       # PushNotificationService (APNs)
        │   └── Theme/               # AppTheme (30+ tokens), ThemeStore
        ├── Models/                  # Codable structs: User, Session, Restaurant, Swipe, WSEvent
        ├── ViewModels/              # @ObservableObject: Auth, Home, Session, Swipe, Results, Profile
        ├── Views/
        │   ├── Auth/                # LoginView, SignupView
        │   ├── Tabs/                # RootTabView, HomeView, ProfileView
        │   ├── Session/             # LobbyView, SwipeView, ResultsView, MatchOverlay (confetti)
        │   └── Components/          # RestaurantCard (DragGesture), SwipeStack, CodeDisplay, etc.
        ├── Config/                  # Config.swift + Debug/Release xcconfig (API_BASE_URL)
        └── Resources/               # Assets.xcassets, Info.plist
```

## Architectural decisions

- **Beanie ODM** over raw Motor — gives us OOP `Document` classes with Pydantic validation and index declarations in one place.
- **OOP throughout the backend** — business logic lives in service classes (`AuthService`, `SessionService`, `MatchingService`, `PlacesService`, `NotificationService`, `ConnectionManager`). Routers stay thin: parse request → call service → return schema.
- **UUIDs for every ID**, not Mongo ObjectIds.
- **Document shape:** embed bounded sub-docs (`UserPreferences`, `PushToken[]` inside `User`; `SessionMember[]` inside `Session`). Separate collections for unbounded data (`swipes`, `restaurants`).
- **Cache restaurants** — never call Google Places per-swipe. Upsert into the `restaurants` collection keyed by `google_place_id`. The Places API query always uses `type=restaurant`; `PlacesService.nearby_search` additionally filters out any result whose `types` list contains `lodging`, `hotel`, `motel`, or `casino` before upserting.
- **Cache nearby-search results too** — `PlaceSearchCache` (`models/place_search_cache.py`) memoizes the entire `nearby_search` *query result* keyed by `sha256(round(lat, 3) | round(lng, 3) | radius_m | sorted(cuisines) | max_price_level)`. Lat/lng rounded to 3 decimals (~110 m bucket) so nearby calls share an entry. TTL is 6 hours via a Mongo `expireAfterSeconds=0` index on `expires_at`. The cache stores `restaurant_ids: [UUID]`; cold-path lookups rehydrate via `Restaurant.get(rid)`. The cache is intentionally *separate* from the `restaurants` collection: documents are still individually fresh (each cold-path call still upserts them), but the *which-IDs-to-return-for-this-query* mapping is cached. If a cached restaurant doc is missing, we fall through to refetch rather than returning a hole.
- **Restaurant description** — `Restaurant.description: str | None` holds the Places Details `editorial_summary.overview` text. `PlacesService._fetch_details(place_id)` makes a single Places Details call with `fields=editorial_summary,reviews` on first-time upsert (replaces the old `_fetch_description`), then is back-filled for previously cached restaurants that don't have one. Failures are swallowed and return `{}` — a missing description never blocks a card from rendering. **Truncated server-side at 180 chars with ellipsis on a word boundary** so the client never has to deal with novel-length text. Surfaced on `RestaurantCardView` (2-line clamp, tail truncation) and on `ResultsView` rows (2-line clamp, tertiary text). Belt-and-suspenders: client clamps even if the server limit is loosened later.
- **Extended restaurant AI fields** — `Restaurant` has three additional optional fields: `reviews: list[str] | None` (top 3 snippets from Places Details), `vibe_blurb: str | None` (Gemini-generated 1-2 sentence atmosphere description, capped at 120 chars), and `overall_vibe_quotes: list[str] | None` (2-3 short quotes Gemini picks from reviews). All three are generated lazily: `_fetch_details` fetches reviews during upsert, then `_generate_ai_fields` fires as a background `asyncio.create_task` so the search response is never blocked. If `vibe_blurb` is None on an existing restaurant, the background task also runs on the next upsert. Failures are silently swallowed — missing AI fields never block a card.
- **GeminiService** (`services/gemini_service.py`) — three methods: `generate_vibe_fields(name, cuisine_tags, description, reviews)` → `{vibe_blurb, overall_vibe_quotes}`; `get_vibe_pick(yes_restaurants, user)` → `{restaurant_id, narrative}` (best match from user's yes swipes); `analyze_personalized_fit(restaurant, user)` → `{dietary_match, budget_match, cuisine_overlap, narrative}`. Requires `GEMINI_API_KEY` in env; returns graceful fallbacks when the key is absent or Gemini fails. Injected into `PlacesService` via `get_places_service()` factory and into routers via `get_gemini_service()` dependency.
- **Vibe Pick endpoint** — `GET /sessions/{id}/vibe-pick` (in `routers/swipes.py`): fetches the current user's yes swipes for the session, rehydrates the `Restaurant` docs, passes them to `GeminiService.get_vibe_pick` with the user's preferences, and returns `VibePickOut(restaurant, narrative)`. Returns 404 if the user has no yes swipes. Falls back to the first yes restaurant with a generic narrative if Gemini fails.
- **Personalized Fit endpoint** — `GET /restaurants/{id}/fit?session_id=` (in `routers/restaurants.py`): verifies session membership, fetches the restaurant and current user, calls `GeminiService.analyze_personalized_fit`, returns `PersonalizedFitOut(dietary_match, budget_match, cuisine_overlap, narrative)`. Rate-limited via `RATE_LIMIT_RESTAURANTS`. Dietary and budget checks are rule-based; the narrative is Gemini-generated with a rule-based fallback.
- **Mock restaurant fallback** — `GET /restaurants?session_id=…` returns a hardcoded NYC list (`_MOCK_RESTAURANTS` in `routers/restaurants.py`) when **any** of: (a) the `?mock=true` query param is set, (b) `USE_MOCK_RESTAURANTS=true` in env, or (c) `GOOGLE_PLACES_API_KEY` is missing. The Swift `SwipeViewModel.load` races the real fetch against a 20s timer and, on failure or timeout, fires a `Task.detached` retry with `?mock=true` so the user never sees an empty stack. The detached task is intentional — the SwipeView's `.task` lifecycle was cancelling the in-place fallback when the create-session sheet→fullScreenCover transition re-mounted the view. `SessionViewModel.fetchRestaurants` also clears `restaurants` at the start of each call so stale data from a previous session can't bleed through on a failed fetch.
- **WebSocket auth** — JWT passed as `?token=` query param; `ConnectionManager` keeps `dict[session_id, dict[user_id, WebSocket]]`.
- **Invite lobby for group sessions, direct swipe for everything else.** All sessions auto-start in `status="swiping"` (see `SessionService.create`). When a user *creates* a group session, `SessionNavigator` opens `LobbyView` first (`startInLobby: true` passed from `HomeView`). `LobbyView` shows the 4-digit code via `CodeDisplayView`, a live member list (WS `onMemberJoined`), and a **"Start Swiping →"** button that is always enabled — the host does not need to wait for anyone. When *joining* via code or reopening from history, `SessionNavigator` goes directly to `SwipeView` (`startInLobby: false`). Solo sessions always skip the lobby and open `SwipeView` directly. The 4-digit code is also shown in the `SwipeView` header (tap to copy) for latecomers. `Session.solo_mode` still drives results-screen copy ("Your top picks" vs "Your group's top picks") and gates instant-match (see below).
- **Instant-match gating** — `MatchingService.check_instant_match` returns `None` for non-solo sessions with fewer than 2 members. This prevents the host from triggering an "instant match" on their first yes while waiting for friends to join. Solo sessions (`solo_mode=true`, `member_count=1`) still match on the first yes by design.
- **Leave vs delete** — `POST /sessions/{id}/leave` removes the calling user from `members`. If they were the host, the earliest-joined remaining member is promoted to host. If they were the last member, the session and its swipes are deleted. `DELETE /sessions/{id}` is host-only and tears down the session + all its swipes for everyone. Both endpoints live in `SessionService.leave` / `SessionService.delete`. The router broadcasts a `member_joined` envelope with `{"left": true}` on a non-deleting leave so connected clients can update presence (no dedicated `member_left` event type yet). **"End Session" button** is exposed to hosts in both `LobbyView` (top-right "End" button) and `SwipeView` (inline next to the swipe count) — both call `SessionViewModel.deleteSession` then `onLeave()` to dismiss the cover.
- **Session history** — `GET /users/me/sessions` returns the last 20 sessions the current user has been a member of, sorted newest-first. The history lives in its own tab (`HistoryView`, left of Home) — `HomeView` no longer renders past sessions. Each row supports a context-menu **Leave** (`POST /sessions/{id}/leave`) and, if the user is the host, **Delete for everyone** (`DELETE /sessions/{id}`). Leaving as the host promotes the earliest-joined remaining member; leaving as the last member deletes the session and its swipes. Tapping a row re-opens the session via `SessionNavigator` in the History tab's own `fullScreenCover`.
- **Tab order** — `RootTabView` is `History | Home | Profile`, but the default `selection` is **Home** (`tag(1)`) so first launch lands there. SF Symbols: `clock.arrow.circlepath | house.fill | person.fill`.
- **History filters + clear all** — `HistoryView` has two filter rows: status (`All | Lobby | Swiping | Results | Matched | Solo | Group`) and date (`Any time | Today | Past week | Past month`). They compose — the trash button clears only what's *currently visible* given both filters. The confirm dialog title interpolates the active filters (e.g. "Clear 4 swiping / today sessions?") and runs `HistoryViewModel.clearAll(filteredSessions)` — *deletes* sessions where the user is host, *leaves* the rest. Per-row swipe actions live in a `List` (swipeActions only works in `List`): trailing-edge **Delete** (host only, red) and **Leave** (orange). Context-menu duplicates remain available for long-press.
- **Swipe ceiling override** — `Session.swipe_ceiling_override: int | None` (3–30, schema-validated) lets each session set its own forced-top-3 threshold instead of the global `MatchingService.SWIPE_CEILING = 10`. `MatchingService.ceiling_for(session)` is the single read site; both `all_members_done` and the laggard-nudge helper in `routers/swipes.py` go through it. The mobile sheet exposes this as a slider (3–30, step 1) in `CreateSessionSheet`.
- **Profile layout + multi-select budget** — `ProfileView` is laid out as a header card + a single "Preferences" card grouping (dietary, cuisines, budget, max distance) + an Appearance card + actions. Sections are visually separated by `theme.textSecondary.opacity(0.12)` 1pt rules — no nested cards. Distance is a continuous `Slider` (1.6–80 km, step 0.8) displayed in miles. **Budget is multi-select** in `ProfileViewModel.budgetRanges: [String]`; `savePreferences()` collapses to the max via `Self.budgetOrder` and sends a single `budget_range` to the backend (the `User.preferences` schema stays single-value — for sessions we send the full list as `budget_overrides`). After a successful PUT, `auth.updateUser(updated)` is called so other views see fresh prefs immediately.
- **Cuisine + dietary tag sets** — Cuisines (`Italian, Mexican, American, Chinese, Japanese, Thai, Korean, Vietnamese, Indian, Mediterranean, Greek, French, Spanish, Middle Eastern, BBQ, Burgers, Pizza, Sushi, Seafood, Steakhouse, Brunch, Bakery, Cafe, Dessert, Vegan, Vegetarian`) and dietary (`Vegetarian, Vegan, Gluten-free, Dairy-free, Nut-free, Halal, Kosher, Pescatarian`) are duplicated in both `ProfileView` and `CreateSessionSheet` as `let` arrays. Keep them in sync when adding new tags.
- **AI features ship in Phase 1.** Gemini 2.5 Flash is live for vibe blurb generation, vibe pick, and personalized fit. The deferred phase is Atlas Vector Search (embeddings-based matching) — still blocked on an Atlas migration.
- **Containerization first.** No host-path assumptions, all config via env vars, single `Dockerfile` for the API — so DigitalOcean deploy is a non-event later.

## Running locally

```bash
# from backend/
docker compose up -d                    # mongo + mongo-express (only needed for local target)
pip install -r requirements.txt         # includes google-generativeai
cp .env.example .env                    # then fill values: GOOGLE_PLACES_API_KEY, GEMINI_API_KEY
uvicorn main:app --reload --port 8001   # http://localhost:8001/docs

# mobile: open in Xcode
open mobile-swift/DishMatch.xcodeproj  # then Cmd+R to run on simulator
# API_BASE_URL in mobile-swift/DishMatch/Config/Debug.xcconfig points to localhost:8001
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

`POST /sessions/{id}/start`, `POST /sessions/{id}/leave`, and `DELETE /sessions/{id}` all reuse `RATE_LIMIT_SESSION_CREATE`/`_JOIN` — they're mutation endpoints that should not be hammerable.

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

## Known gotchas

- **`score_pct` is already a percentage (0–100)**, not a fraction. `MatchingService.get_top_n` returns `round(yes/total*100)`. Don't multiply by 100 again in the UI — `ResultsView` displays `Int(result.scorePct)%` directly.
- **Beanie + UUIDs**: UUID fields are stored as BSON Binary subtype 4. Raw-dict queries on UUID values must pass the `UUID` object, not `str(uuid)`, or nothing matches. See `SessionService.get_user_sessions` for the canonical pattern.
- **Match-popup / results-navigation dedupe**: `SwipeViewModel` guards `triggerMatch` with `didShowMatch` and `requestNavigateToResults` with `didNavigateToResults`. The swipe ack and the WS `instant_match` event both fire for the same yes; the WS `phase_change`, `top3_ready`, and the `MatchOverlay` dismiss can all independently request the results push. Always route through those guarded methods rather than mutating `showMatch`/`navigateToResults` directly.
- **SwipeStackView width**: both the peek card and the top card explicitly set `.frame(maxWidth: .infinity)`, and `RestaurantCardView`'s body does the same. Without these, the ZStack collapses to intrinsic content width and the card visibly resizes between cards (especially when only one card remains).
- **RestaurantCardView clipping**: the card body has `.clipped()` *before* the corner radius/shadow, the photo uses a fixed `.frame(height: 280)` (not `maxHeight`) applied **on the image itself** (not just the ZStack), and the restaurant name is `.lineLimit(1).truncationMode(.tail)` with `Spacer(minLength: 8)` and `.fixedSize()` on the price tier. The image-level frame is the load-bearing fix — the ZStack's frame alone doesn't prevent portrait images from overflowing. Without all of these, a long name or an AsyncImage with a tall intrinsic aspect would visibly push the card past the screen edge.
- **SwipeStackView GeometryReader + hard cap**: the stack uses a `GeometryReader` with an explicit outer `.frame(height: 540)` and pins both the peek card and the top card to `width: min(geo.size.width, 380), height: 520`. The `min(..., 380)` cap is the load-bearing fix — even with the GeometryReader, a transient layout pass mid-animation can hand out a wider geo on the first measurement; the cap prevents that from leaking into the card frame. Equally important: **`RestaurantCardView.body` no longer has `.frame(maxWidth: .infinity)` of its own**, and the inner photo container no longer does either. Both sides claiming "infinity" was the original cause of the card visibly expanding past the screen after a few swipes — SwiftUI would resolve the ambiguity differently depending on layout state.
- **Results back = `onClose` callback, NOT `dismiss()`**: `@Environment(\.dismiss)` inside a `NavigationStack`-pushed view *pops the nav*, not the fullScreenCover — so calling `dismiss()` directly from `ResultsView` would land back on the stale `SwipeView`, re-run its `.task`, get a 500/timeout, trigger the mock NYC fallback, and the next swipe would 409 with "Session is in 'results', not swiping". The cure: `SessionNavigator` owns the `@Environment(\.dismiss)` (it's the cover's root), and passes `onClose: { dismiss() }` down to `ResultsView`. The back button and the "Start New Session" button both call `onClose()`. This is the canonical pattern for any deep view that needs to close the entire cover.
- **`await` inside comprehensions / generators**: `[await foo(x) for x in xs]` is *valid* async comprehension but serial — fine for short lists, but use `await asyncio.gather(*(foo(x) for x in xs))` for any membership-sized fan-out (e.g. fetching all session members' `User` docs in `routers/restaurants.py` and `notification_service.py`). The truly broken form is `[r for r in (await foo(x) for x in xs)]` — a *parenthesized* generator expression returns an async generator that the outer comp can't iterate with sync `for`; that's a runtime 500. The `PlaceSearchCache` cache-hit path was rewritten as an explicit `for ... await` loop to avoid this trap.
- **Gemini is optional** — `GeminiService._get_model()` returns `None` when `GEMINI_API_KEY` is unset; all three public methods return graceful fallbacks (empty dict / None / rule-based narrative) in that case. The server boots and works without a key.
- **`APIClient.delete` and 204 responses**: `request<T>` checks `data.isEmpty` and returns an `_EmptyResponse()` placeholder when `T == _EmptyResponse`. Endpoints returning `204 No Content` (leave, delete) must be called via `APIClient.delete(...)` or by typing the response as `_EmptyResponse`, otherwise `JSONDecoder` will throw on the empty body.

## Conventions

- **Haptics** — use `UIImpactFeedbackGenerator` and `UINotificationFeedbackGenerator` inline at call sites (no wrapper class needed). Like swipe/button → `.medium`; Pass swipe/button → `.light`; copy code → `.rigid`. Haptics are suppressed by the simulator (see Simulator noise table).
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

**Color tokens** live in `mobile-swift/DishMatch/Core/Theme/AppTheme.swift` (30+ tokens, dark-first).

| Token | Dark | Light |
|---|---|---|
| `bg` | `#0a0a0a` | `#faf9f7` |
| `surface` | `#1a1a1a` | `#f2efeb` |
| `surfaceLight` | `#262626` | `#e8e3dc` |
| `primary` (coral) | `#d97757` | `#d97757` |
| `primaryLight` | `#f5a76d` | `#f5a76d` |
| `text` | `#ffffff` | `#1c1917` |
| `textSecondary` | `#b3b3b3` | `#78716c` |
| `textTertiary` | `#808080` | `#a8a29e` |
| `border` | `#404040` | `#d6d0c8` |
| `like` | `#4caf50` | `#4caf50` |
| `pass` | `#ef5350` | `#ef5350` |

Tokens include `cardBorder`, `chipBg`, `chipBorder`, `progressBg` — all primary-tinted rgba values.

**Component patterns (match the HTML design):**

- **Buttons** — primary uses `cornerRadius: 10`, vertical padding 14pt, coral shadow (primary at 30% opacity). Use solid primary color.
- **Cards** — `cornerRadius: 12`, `borderWidth: 1`, `cardBorder` color.
- **Chips/tags** — `cornerRadius: 8`, `chipBg` + `chipBorder`, never use pill shape for preference chips.
- **Inputs** — `cornerRadius: 10`, IBM Plex Mono font, `inputBorder` color (primary at ~25% opacity).
- **Progress bars** — `height: 3`, `progressBg` track color, primary fill.
- **Restaurant card** — has both swipe gestures AND visible Pass/Like buttons at the bottom of the info section.
- **Results list** — compact flat list with 40×40 square rank badges (medal emoji 🥇🥈🥉) and a slim 2px agreement bar. No full image cards. Has a List/Map segmented toggle that shows a `MapKit` map with `MapMarker` annotations at each restaurant's `lat`/`lng`. Tapping a row opens a `confirmationDialog` with **Open in Apple Maps**, **Open in Google Maps**, and **✨ Why this fits me** (triggers `PersonalizedFitSheet`). The `ResultsView` has a back button at the top that pops the nav path (or dismisses the fullScreenCover if the path is already empty). A **Vibe Pick card** (coral left-border accent block) appears above the medal rows once `ResultsViewModel.loadVibePick()` resolves — it fires as a background `Task` so medal rows show immediately.
- **ResultsViewModel async loading** — `load()` fetches results first (blocking `isLoading`), then fires `loadVibePick()` in a detached `Task` so the Vibe Pick card appears after results without delaying them. `loadFit(for:)` fetches `PersonalizedFitOut` on demand and sets `selectedFitContext: PersonalizedFitContext?` which drives the `.sheet`.
- **PersonalizedFitSheet** — shown via `.sheet(item: $vm.selectedFitContext)`. Displays dietary match, budget match, cuisine overlap chips, and a Gemini narrative paragraph. `PersonalizedFitContext` is `Identifiable` via the restaurant's UUID.
- **Restaurant card photo clipping** — `AsyncImage` success case applies `.frame(height: 280).clipped()` directly on the image (not just the outer ZStack) to prevent portrait-oriented photos from overflowing the card regardless of the SwiftUI layout pass order.
- **Profile section titles** — `fontSize: 11, fontWeight: .bold, letterSpacing: 0.6, textCase: .uppercase`, muted white at 50% opacity.
- **CodeDisplay boxes** — 60×72, primary border at 40% opacity, monospaced 32px primary text. Tapping the boxes copies the code and shows a "Copied!" toast. The share icon (`square.and.arrow.up`) sits inline to the right of the boxes.
- **Home header** — compact with bottom divider at 6% white opacity.
- **"How it works" tips** — left-border accent block: 3pt left border at 40% primary opacity, warm-tinted background.
- **Session setup sheet (`CreateSessionSheet`)** — full-screen `MKMapView` (`UIViewRepresentable`) with tap-to-drop-pin as the primary location input. Tap anywhere → coral pin drops + reverse geocode fires. Search bar at the top uses `MKLocalSearch` (`naturalLanguageQuery`) to fly the map to a typed city/neighborhood. "My Location" button (GPS) also centers + pins. Sheet is `.large` detent. Works for both group and solo sessions via the `soloMode: Bool` parameter; button label and title adapt accordingly. The `LocationManager` class lives in this file (GPS helper only — no geocoding).
- **Session setup prefill + filters** — `onAppear` pre-fills *every* session setting from `authStore.user?.preferences`: `sessionCuisines` from `cuisinePreferences`, `sessionRadius` from `maxDistanceKm` (clamped into the slider's `[1.6, 80]` km range so the thumb stays visible), `sessionBudgets` from `budgetRange` (wrapped as a single-element list). The sheet's selections override personal prefs for *that session* (sent as `cuisine_overrides` / `radius_km_override` / `budget_overrides` / `swipe_ceiling_override`). Radius is a continuous **`Slider`** (`1.6…80` km, step `0.8`); the swipe-limit slider is 3–30 step 1; budget is a multi-select chip row. **`ProfileViewModel.savePreferences` calls `authStore.updateUser(updated)`** after a successful PUT so the sheet's `onAppear` sees fresh prefs without a manual refresh.
- **Budget filtering is multi-select + exact match** — `Session.budget_overrides: list[str] | None` (was a single `budget_override`). Backend derives `max_price_level = max(budget_levels)` for the Places API call, then **post-filters** the returned restaurants to the exact set of selected tiers (keeping unknown-price entries since Google often omits `price_level` and excluding them would empty the stack in many neighborhoods). The sheet sends `sessionBudgets` directly — no client-side collapse to a single value.
- **Results map pin tap** — `ResultsView.mapView` uses `MapAnnotation` (not `MapMarker`) so each pin is a tappable `Button` that opens the same Apple/Google Maps `confirmationDialog` the list rows use. The annotation shows a coral mappin + the restaurant name caption.

## Simulator noise (safe to ignore)

Running in the iOS simulator produces several recurring log lines that are **not app bugs**:

| Log pattern | Cause | Action |
|---|---|---|
| `Failed to send CA Event for app launch measurements` | Simulator telemetry stub | Ignore |
| `Unable to simultaneously satisfy constraints` (accessoryView.bottom / inputView.top) | UIKit internal keyboard layout conflict — iOS bug in simulator, not app code | Ignore |
| `CHHapticPattern patternForKey: hapticpatternlibrary.plist couldn't be opened` | Haptic asset files absent from simulator environment | Ignore |
| `System gesture gate timed out` | Simulator gesture recognizer noise | Ignore |
| `Could not find cached accumulator for token` | UIKit keyboard candidate cache noise | Ignore |
| `-[RTIInputSystemClient remoteTextInputSessionWithID:performInputOperation:] requires a valid sessionID` | UIKit keyboard input session noise | Ignore |

**Real errors to act on:** `NSURLErrorDomain Code=-1004 "Could not connect to the server."` — means the backend is not running on port 8001. Start it with `uvicorn main:app --reload --port 8001`.

## Pointers

- Phase plan: `/Users/nosaj/.claude/plans/dishmatch-claude-splendid-volcano.md`

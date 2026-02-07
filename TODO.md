# SyncForge - Development TODO

> Real-Time Collaboration Infrastructure for Developers

**Last Updated**: 2026-02-06 (Phase 9 started)

---

## Phase 1: Core Infrastructure ✅

### Project Setup
- [x] Initialize Phoenix 1.8 project
- [x] Configure PostgreSQL with binary UUIDs
- [x] Set up project structure
- [x] Create documentation (CLAUDE.md, PRD, SPECS, etc.)
- [x] Push to GitHub repository

---

## Phase 2: Real-Time Foundation ✅

### Phoenix Channels & Presence
- [x] Create UserSocket with authentication
- [x] Create RoomChannel for real-time communication
- [x] Implement Phoenix Presence for user tracking
- [x] Add presence metadata (name, avatar, status)
- [x] Handle join/leave events
- [x] Implement reconnection logic (client-side SDK task)

### Room Management
- [x] Create Room schema (Ecto)
- [x] Room CRUD operations
- [x] Room authorization (capacity + access checks)
- [x] Room configuration (max participants, metadata)
- [x] Room state persistence

---

## Phase 3: Core Features ✅

### Live Cursors
- [x] Cursor position tracking
- [x] Cursor broadcast optimization (throttling)
- [x] Cursor labels (user name + color display)
- [x] Client-side cursor smoothing
- [x] Selection highlighting

### Threaded Comments
- [x] Comment schema with threading (parent_id)
- [x] Element anchoring (anchor_id, position)
- [x] Real-time comment sync
- [x] Comment resolution (mark as resolved)
- [x] Reactions (emoji)

### Notifications
- [x] Notification schema
- [x] Real-time notification delivery
- [x] Notification preferences
- [x] Read/unread status
- [x] Activity feed

---

## Phase 4: Authentication & Accounts ✅

### User Management
- [x] User schema
- [x] Email/password authentication
- [x] Password reset flow
- [x] Email verification
- [x] API key generation

### Organizations
- [x] Organization schema
- [x] Multi-tenant support
- [x] Team member management (add/remove/update role)
- [x] Role-based access (Owner, Admin, Member, Viewer)
- [x] Organization settings (plan_type, max_rooms, max_monthly_connections)
- [x] API key management (create, list, revoke)
- [x] RBAC enforcement in RoomChannel (org-aware join, viewer write restrictions)

---

## Phase 5: JavaScript SDK ✅

### Core SDK (@syncforge/core) — 212 tests
- [x] TypeScript types (User, Comment, Reaction, Notification, Activity, CursorPosition, Selection, etc.)
- [x] TypedEventEmitter with strong typing
- [x] SyncForgeClient (connect, disconnect, joinRoom, joinNotifications)
- [x] Room class (join, leave, push, typing indicators, room state hydration)
- [x] PresenceManager (track joins/leaves, user list, onSync/onJoin/onLeave)
- [x] CursorManager (throttled ~60fps updates, lerp smoothing, cursor lifecycle)
- [x] SelectionManager (local/remote selection sync)
- [x] CommentManager (create/update/delete/resolve, real-time sync)
- [x] ReactionManager (add/remove/toggle, real-time sync)
- [x] ActivityManager (paginated list, real-time new activity)
- [x] NotificationManager (separate channel, list/markRead/markAllRead, unread count)

### React Integration (@syncforge/react) — 112 tests
- [x] SyncForgeProvider (React context, client lifecycle)
- [x] `useRoom` hook (join/leave, connection status)
- [x] `usePresence` hook (live user list)
- [x] `useCursors` hook (cursor positions map)
- [x] `useComments` hook (comment CRUD + real-time)
- [x] `useNotifications` hook (notification list + unread count)

### Pre-built UI Components
- [x] PresenceAvatars (stacked avatar display with overflow)
- [x] CursorOverlay (remote cursors with labels + colors)
- [x] CommentPanel (slide-out threaded comments with reactions)
- [x] NotificationToast (positioned toast notifications with dismiss)

---

## Phase 6: Developer Experience ✅

### Dashboard
- [x] Browser session auth (login/register LiveViews, session controller)
- [x] Dashboard layout (sidebar nav, org picker)
- [x] Overview page (stat cards)
- [x] API key management UI (list/create/revoke, copy-to-clipboard)
- [x] Room monitoring (org-scoped room list, create/delete, type badges)
- [x] Usage analytics (connection_events table, Analytics context)
- [x] Real-time logs (PubSub-streamed log viewer)

### Documentation
- [ ] SDK installation guide
- [ ] Quick start tutorial
- [ ] API reference
- [ ] Example applications
- [ ] Self-hosting guide

---

## Phase 7: Billing & Plans ✅

### Stripe Integration
- [x] Stripe checkout integration (stripity_stripe ~> 3.2)
- [x] Subscription management (create/update/cancel via webhooks)
- [x] Usage metering (MAU via connection_events, room count)
- [x] Plan enforcement (room limits, MAU limits, feature gating)
- [x] Billing portal (Stripe Customer Portal sessions)
- [x] Webhook handler (idempotent via BillingEvent schema)
- [x] StripeClient behaviour + Mox mock for testing

### Pricing Tiers
- [x] Free tier (50 MAU, 3 rooms — Presence, Cursors)
- [x] Starter ($49/mo — 1,000 MAU, 10 rooms + Comments, Notifications)
- [x] Pro ($199/mo — 10,000 MAU, 100 rooms + Voice, Webhooks)
- [x] Business ($499/mo — 50,000 MAU, unlimited rooms + Analytics, SSO)
- [x] Enterprise (custom — manual Stripe subscription)

### Billing Dashboard
- [x] BillingLive page (plan card, usage meters, feature checklist)
- [x] Real-time updates via PubSub (billing:#{org_id} topic)
- [x] Past-due/canceled status alerts
- [x] Org switching with billing data reload
- [x] Sidebar navigation link

### Billing API
- [x] POST /api/organizations/:org_id/billing/checkout
- [x] POST /api/organizations/:org_id/billing/portal
- [x] GET /api/organizations/:org_id/billing/subscription

---

## Phase 8: Production Readiness ✅

### 8.1 Performance Optimization (PR #33)
- [x] ETS cursor throttler (GenServer + ETS replaces Agent for concurrent reads/writes)
- [x] Socket assigns caching (org/plan data cached at join, no DB queries per action)
- [x] Slow query logging (telemetry handler for queries >100ms dev / >200ms prod)
- [x] Composite indexes (organization_id, event_type, inserted_at on connection_events)
- [x] Database SSL + pool tuning (configurable via env vars)

### 8.2 Security Hardening (PR #34)
- [x] Input validation (ParamSanitizer plug — null byte rejection, string length limits, depth limits)
- [x] Security headers (CSP with per-request nonces, Referrer-Policy, Permissions-Policy)
- [x] Rate limiting (Hammer 7.0 — IP-based for auth, user-based for API, channel event limits)
- [x] CORS configuration (Corsica 2.1 — configurable origins via ALLOWED_ORIGINS env var)
- [x] API key rotation (24h grace period, POST /api/organizations/:org_id/api-keys/:id/rotate)
- [x] WebSocket frame limits (max_frame_size: 65_536, compress: true)
- [x] Request body size limit (1MB on Plug.Parsers)

### 8.3 Observability (PR #35)
- [x] Health check endpoint (GET /health — DB connectivity check, 200/503)
- [x] Custom telemetry metrics (room join/leave counters, channel message counter, presence/room gauges)
- [x] Structured JSON logging (LoggerJSON 7.0 for production)
- [x] Error tracking (Sentry v10 — Logger-based, activated by SENTRY_DSN env var)
- [x] Logger metadata (user_id, room_id added to all log entries)

### 8.4 Deployment (PR #36)
- [x] OTP release module (Syncforge.Release — migrate/0, rollback/2 without Mix)
- [x] Multi-stage Dockerfile (hexpm/elixir builder + debian slim runner, nobody user)
- [x] Fly.io configuration (fly.toml — iad region, rolling deploy, auto-stop/start)
- [x] BEAM clustering (rel/env.sh.eex — DNS-based node discovery on Fly.io)
- [x] Release scripts (rel/overlays/bin/server, rel/overlays/bin/migrate)
- [x] CI pipeline (GitHub Actions — tests, format, compile)
- [x] CD pipeline (GitHub Actions — deploy to Fly.io on push to main)

---

## Phase 9: Marketing Surface 🚧

### Landing & Conversion
- [x] Promote landing page to `/` (LiveView)
- [x] Extract landing CSS into `assets/css/landing.css`
- [x] Add dark/light/system theme persistence with LiveView hook sync
- [x] Add landing page SEO basics (title/description/OG tags)
- [x] Improve landing accessibility (focus-visible, ARIA labels, tab roles, reduced motion)
- [x] Replace `/signup` CTAs with `/register`
- [x] Add waitlist persistence (`waitlist_signups` migration + context + schema)
- [x] Add support routes for `/docs`, `/blog`, `/privacy`, `/contact`
- [ ] Replace placeholder marketing pages with launch-ready content
- [ ] Add CTA conversion analytics instrumentation (hero CTA + waitlist submit)
- [ ] Add social proof blocks (logos/testimonials/trust badges) on landing page
- [ ] Run Lighthouse and address issues below 90 in Performance/Accessibility/SEO

---

## Completed Features

| # | Feature | PR | Tests |
|---|---------|-----|-------|
| 1 | UserSocket — WebSocket auth via Phoenix tokens | — | ✅ |
| 2 | RoomChannel — Real-time channel with cursor & typing events | — | ✅ |
| 3 | Presence — User presence tracking with CRDT sync | — | ✅ |
| 4 | Room Schema — Ecto schema with types, config, metadata | — | ✅ |
| 5 | Room CRUD — Full CRUD with slug generation | — | ✅ |
| 6 | Room Authorization — Capacity checks and access control | — | ✅ |
| 7 | Cursor Throttling — Rate-limited broadcasts ~60fps via ETS-backed GenServer | — | ✅ |
| 8 | Comment Schema — Threaded comments with anchoring, resolution | — | ✅ |
| 9 | CI Pipeline — GitHub Actions for tests and format checking | — | ✅ |
| 10 | Cursor Labels — User name and deterministic color in broadcasts | — | ✅ |
| 11 | Real-time Comment Sync — Channel handlers for comment CRUD | — | ✅ |
| 12 | Room State Persistence — Push room state on join | — | ✅ |
| 13 | Client-side Cursor Smoothing — JS SDK lerp interpolation | — | ✅ |
| 14 | Selection Highlighting — SelectionManager/Renderer + LiveView hook | — | ✅ |
| 15 | Reconnection Logic — ConnectionManager with exponential backoff | — | ✅ |
| 16 | Comment Reactions — Emoji toggle, batch queries, embedded state | — | ✅ |
| 17 | Notifications Context — 6 types, CRUD, read/unread, pagination | — | ✅ |
| 18 | Notification Delivery — NotificationChannel with real-time push | — | ✅ |
| 19 | Notification Preferences — Per-user settings, should_notify? | — | ✅ |
| 20 | Activity Feed — Room-level activity stream | — | ✅ |
| 21 | User Authentication — Email/password, bcrypt, Phoenix.Token | PR #15 | ✅ |
| 22 | Security Fix — Room join auth, comment ownership checks | PR #16 | ✅ |
| 23 | Password Reset & Email Verification — Token-based flows | PR #17 | ✅ |
| 24 | Pagination & Rescue Fix — list_comments pagination | — | ✅ |
| 25 | Composite Indexes — Database indexes for common queries | — | ✅ |
| 26 | Organizations & Multi-tenancy — Orgs, memberships, API keys, RBAC | PR #20 | ✅ |
| 27 | RBAC Room Channel — Org-aware join, viewer write restrictions | PR #21 | ✅ |
| 28 | JavaScript SDK — @syncforge/core + @syncforge/react | PR #22 | 324 tests |
| 29 | Browser Session Auth — LiveView login/register, session controller | PR #24 | ✅ |
| 30 | Dashboard Layout — Sidebar nav, org picker, overview stat cards | PR #25 | ✅ |
| 31 | API Key Management UI — List/create/revoke with copy-to-clipboard | PR #26 | ✅ |
| 32 | Room Monitoring — Org-scoped room list, create/delete, type badges | PR #27 | ✅ |
| 33 | Usage Analytics & Logs — connection_events, Analytics context, PubSub logs | PR #28 | ✅ |
| 34 | Session Auth Fix — Missing params handling, moduledoc corrections | PR #29 | ✅ |
| 35 | Bcrypt Perf Fix — Skip password hashing during LiveView validate events | PR #30 | ✅ |
| 36 | Phase 6 Merge — All dashboard features merged to main | PR #31 | ✅ |
| 37 | Phase 7 Billing & Plans — Stripe integration, plan enforcement, billing dashboard | PR #32 | 87 tests |
| 38 | Phase 8.1 Performance — ETS throttler, socket caching, slow query logging, indexes | PR #33 | ✅ |
| 39 | Phase 8.2 Security — Rate limiting, CORS, CSP headers, param sanitizer, API key rotation | PR #34 | ✅ |
| 40 | Phase 8.3 Observability — Health check, custom telemetry, JSON logging, Sentry | PR #35 | 10 tests |
| 41 | Phase 8.4 Deployment — OTP release, Dockerfile, fly.toml, CD pipeline | PR #36 | 2 tests |

### Test Totals
- **700 Elixir tests** (0 failures)
- **212 @syncforge/core tests** (TypeScript)
- **112 @syncforge/react tests** (TypeScript)
- **Total: 1,024 tests**

### Up Next
- Phase 6 gap: Documentation (SDK guide, quick start, API reference, example apps)
- Phase 9: Advanced Features (CRDT document sync, voice rooms, screen recording)
- Load testing with real WebSocket connections at scale

---

## Technical Debt

| Item | Priority | Notes |
|------|----------|-------|
| Unused `socket` warnings | Low | 3 warnings in room_channel_test.exs (lines 333, 418, 683) |
| Duplicated `pick_org/2` | Low | Same helper copy-pasted across 6 LiveViews — extract to shared module |
| Comment popovers | Low | Inline comment popover UI component not yet built |

---

## Production Dependencies Added (Phase 8)

| Package | Version | Purpose |
|---------|---------|---------|
| `hammer` | `~> 7.0` | Rate limiting (ETS backend) |
| `hammer_plug` | `~> 3.0` | Plug integration for Hammer |
| `corsica` | `~> 2.1` | CORS configuration |
| `logger_json` | `~> 7.0` | Structured JSON logging |
| `sentry` | `~> 10.0` | Error tracking |

---

## Performance Targets

| Metric | Target | Current |
|--------|--------|---------|
| Presence sync | <50ms | - |
| Cursor broadcast | <30ms | - |
| WebSocket latency | <100ms | - |
| Room join time | <200ms | - |

---

## Notes

- Follow TDD approach for all features
- Maintain 80%+ test coverage
- Update this TODO as tasks complete
- Reference PRD.md and SPECS.md for requirements

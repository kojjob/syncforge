# SyncForge - Development TODO

> Real-Time Collaboration Infrastructure for Developers

**Last Updated**: 2026-02-06

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

## Phase 6: Developer Experience

### Dashboard
- [ ] Developer signup/login
- [ ] API key management
- [ ] Room monitoring
- [ ] Usage analytics
- [ ] Real-time logs

### Documentation
- [ ] SDK installation guide
- [ ] Quick start tutorial
- [ ] API reference
- [ ] Example applications
- [ ] Self-hosting guide

---

## Phase 7: Billing & Plans

### Stripe Integration
- [ ] Stripe checkout integration
- [ ] Subscription management
- [ ] Usage metering (MAU, rooms)
- [ ] Plan enforcement
- [ ] Billing portal

### Pricing Tiers
- [ ] Free tier (100 MAU, 5 rooms)
- [ ] Starter ($49/mo - 1,000 MAU)
- [ ] Pro ($199/mo - 10,000 MAU)
- [ ] Business ($499/mo - 50,000 MAU)

---

## Phase 8: Production Readiness

### Performance
- [ ] Load testing (WebSocket connections)
- [ ] Presence sync <50ms (p95)
- [ ] Cursor broadcast <30ms (p95)
- [ ] Connection pooling optimization
- [ ] Database query optimization

### Security
- [ ] Security audit
- [ ] Rate limiting
- [ ] Input validation
- [ ] CORS configuration
- [ ] API key rotation

### Deployment
- [ ] Fly.io configuration
- [x] CI pipeline (GitHub Actions - tests, format)
- [ ] CD pipeline (staging/production deploy)
- [ ] Monitoring (Telemetry)
- [ ] Error tracking
- [ ] Automated backups

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
| 7 | Cursor Throttling — Rate-limited broadcasts ~60fps via Agent GenServer | — | ✅ |
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

### Up Next
- Phase 6: Developer Experience (Dashboard, Documentation)

---

## Technical Debt

| Item | Priority | Notes |
|------|----------|-------|
| - | - | No debt yet (greenfield) |

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

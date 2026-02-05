# SyncForge - Development TODO

> Real-Time Collaboration Infrastructure for Developers

**Last Updated**: 2026-02-05

---

## Phase 1: Core Infrastructure ✅

### Project Setup
- [x] Initialize Phoenix 1.8 project
- [x] Configure PostgreSQL with binary UUIDs
- [x] Set up project structure
- [x] Create documentation (CLAUDE.md, PRD, SPECS, etc.)
- [x] Push to GitHub repository

---

## Phase 2: Real-Time Foundation 🚧

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

## Phase 3: Core Features

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
- [ ] Reactions (emoji)

### Notifications
- [ ] Notification schema
- [ ] Real-time notification delivery
- [ ] Notification preferences
- [ ] Read/unread status
- [ ] Activity feed

---

## Phase 4: Authentication & Accounts

### User Management
- [ ] User schema
- [ ] Email/password authentication
- [ ] Password reset flow
- [ ] Email verification
- [ ] API key generation

### Organizations
- [ ] Organization schema
- [ ] Multi-tenant support
- [ ] Team member invitations
- [ ] Role-based access (Owner, Admin, Editor, Viewer)
- [ ] Organization settings

---

## Phase 5: JavaScript SDK

### Core SDK
- [ ] Vanilla JS SDK structure
- [ ] WebSocket connection management
- [ ] Auto-reconnect with exponential backoff
- [ ] Event system (subscribe/publish)
- [ ] TypeScript type definitions

### React Integration
- [ ] `usePresence` hook
- [ ] `useCursors` hook
- [ ] `useComments` hook
- [ ] `useRoom` hook
- [ ] Pre-built React components

### Pre-built UI Components
- [ ] Presence avatars (stacked)
- [ ] Cursor overlay renderer
- [ ] Comment panel (slide-out)
- [ ] Comment popovers (inline)
- [ ] Notification toasts

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

## Current Sprint: Core Features

### Completed ✅
1. **UserSocket** - WebSocket authentication via Phoenix tokens
2. **RoomChannel** - Real-time channel with cursor & typing events
3. **Presence** - User presence tracking with CRDT sync
4. **Room Schema** - Ecto schema with types, config, and metadata
5. **Room CRUD** - Full CRUD operations with slug generation
6. **Room Authorization** - Capacity checks and access control
7. **Cursor Throttling** - Rate-limited cursor broadcasts at ~60fps via Agent GenServer
8. **Comment Schema** - Threaded comments with anchoring, resolution, and cascade delete
9. **CI Pipeline** - GitHub Actions for tests and format checking on PRs
10. **Cursor Labels** - User name and deterministic color in cursor broadcasts
11. **Real-time Comment Sync** - Channel handlers for comment CRUD with broadcasts
12. **Room State Persistence** - Push room state (comments, metadata) to users on join
13. **Client-side Cursor Smoothing** - JavaScript SDK with lerp interpolation and CursorTracking LiveView hook
14. **Selection Highlighting** - JavaScript SDK with SelectionManager/SelectionRenderer and SelectionTracking LiveView hook
15. **Reconnection Logic** - JavaScript SDK with ConnectionManager (exponential backoff, state tracking) and ConnectionStatus LiveView hook

### Up Next
- Reactions (emoji) for comments
- Notification schema and real-time delivery

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

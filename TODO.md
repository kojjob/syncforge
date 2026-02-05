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
- [ ] Implement reconnection logic (client-side SDK task)

### Room Management
- [x] Create Room schema (Ecto)
- [x] Room CRUD operations
- [x] Room authorization (capacity + access checks)
- [x] Room configuration (max participants, metadata)
- [ ] Room state persistence

---

## Phase 3: Core Features

### Live Cursors
- [ ] Cursor position tracking
- [ ] Cursor broadcast optimization (throttling)
- [ ] Cursor labels (user name display)
- [ ] Client-side cursor smoothing
- [ ] Selection highlighting

### Threaded Comments
- [ ] Comment schema with threading (parent_id)
- [ ] Element anchoring (anchor_id, position)
- [ ] Real-time comment sync
- [ ] Comment resolution (mark as resolved)
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
- [ ] CI/CD pipeline
- [ ] Monitoring (Telemetry)
- [ ] Error tracking
- [ ] Automated backups

---

## Current Sprint: Real-Time Foundation

### Completed ✅
1. **UserSocket** - WebSocket authentication via Phoenix tokens
2. **RoomChannel** - Real-time channel with cursor & typing events
3. **Presence** - User presence tracking with CRDT sync
4. **Room Schema** - Ecto schema with types, config, and metadata
5. **Room CRUD** - Full CRUD operations with slug generation
6. **Room Authorization** - Capacity checks and access control

### Up Next
- Cursor tracking optimization (throttling)
- Comment system schema
- Room state persistence

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

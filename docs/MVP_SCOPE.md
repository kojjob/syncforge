# SyncForge - MVP Scope

## Overview

Definition of what ships in v1.0 (MVP) versus what's planned for later releases.

---

## MVP Philosophy

> "Ship the smallest thing that delivers real value to our target customer"

**Target Customer**: Developer at a growing startup who needs to add real-time collaboration features (presence, cursors, comments) to their web app without building infrastructure from scratch.

**Core Value Proposition**: Drop-in collaboration components that work in under 30 minutes—presence indicators, live cursors, and threaded comments with a simple SDK.

---

## MVP Features (v1.0)

### ✅ In Scope

#### Authentication & Accounts
| Feature | Details | Priority |
|---------|---------|----------|
| Email/password signup | With email verification | P0 |
| Google OAuth | Sign up and sign in | P0 |
| API key generation | For SDK authentication | P0 |
| Organization management | Multi-tenant support | P0 |

#### Room Management
| Feature | Details | Priority |
|---------|---------|----------|
| Create rooms | Named collaboration spaces | P0 |
| Room authorization | Token-based access control | P0 |
| Room configuration | Max participants, metadata | P0 |
| Room state persistence | Recover state on reconnect | P0 |

#### Presence (Core Feature)
| Feature | Details | Priority |
|---------|---------|----------|
| User presence tracking | Who's online in each room | P0 |
| Presence metadata | Custom user data (name, avatar, status) | P0 |
| Presence sync | <50ms latency target | P0 |
| Join/leave events | Real-time notifications | P0 |
| Multi-device handling | Same user, multiple tabs | P1 |

#### Live Cursors (Core Feature)
| Feature | Details | Priority |
|---------|---------|----------|
| Cursor position broadcast | Real-time x/y coordinates | P0 |
| Cursor labels | User name display | P0 |
| Cursor throttling | Optimized network usage | P0 |
| Cursor smoothing | Client-side interpolation | P1 |
| Selection highlighting | Show what users have selected | P1 |

#### Comments System
| Feature | Details | Priority |
|---------|---------|----------|
| Threaded comments | Parent/reply structure | P0 |
| Element anchoring | Attach comments to any element ID | P0 |
| Real-time sync | Instant comment delivery | P0 |
| Comment resolution | Mark threads as resolved | P0 |
| Reactions | Emoji reactions on comments | P1 |

#### JavaScript SDK
| Feature | Details | Priority |
|---------|---------|----------|
| Vanilla JS SDK | Framework-agnostic core | P0 |
| React hooks | `usePresence`, `useCursors`, `useComments` | P0 |
| Connection management | Auto-reconnect, status events | P0 |
| TypeScript types | Full type definitions | P0 |
| Event system | Subscribe to all room events | P0 |

#### Pre-built UI Components
| Feature | Details | Priority |
|---------|---------|----------|
| Presence avatars | Stacked avatar display | P0 |
| Cursor overlays | Labeled cursor rendering | P0 |
| Comment panel | Slide-out comment UI | P1 |
| Comment popovers | Inline comment anchors | P1 |

#### Monitoring & Dashboard
| Feature | Details | Priority |
|---------|---------|----------|
| Developer dashboard | Room status, active users | P0 |
| Connection metrics | Latency, error rates | P0 |
| Usage analytics | MAU, room counts | P0 |
| Real-time logs | Debug WebSocket events | P1 |

#### Billing (Stripe Integration)
| Feature | Details | Priority |
|---------|---------|----------|
| Free tier | 100 MAU, 5 rooms | P0 |
| Starter plan | $49/mo - 1,000 MAU, 10 rooms | P0 |
| Pro plan | $199/mo - 10,000 MAU, 100 rooms | P0 |
| Credit card payment | Via Stripe Checkout | P0 |
| Usage enforcement | Limit based on plan | P0 |

---

### ❌ Out of MVP Scope

#### Deferred to v1.1
| Feature | Reason | Target |
|---------|--------|--------|
| Vue/Svelte SDKs | Focus on React first | v1.1 |
| Document sync (CRDT) | Yjs complexity | v1.1 |
| GitHub OAuth | Lower priority auth | v1.1 |
| MFA/2FA | Security enhancement | v1.1 |
| Notifications system | Separate feature set | v1.1 |

#### Deferred to v1.2+
| Feature | Reason | Target |
|---------|--------|--------|
| Voice rooms | WebRTC complexity | v1.2 |
| Screen recording | Additional infrastructure | v1.2 |
| Webhook notifications | Event delivery system | v1.2 |
| REST API | SDK handles most use cases | v1.3 |
| Analytics dashboard | Extended metrics | v1.3 |

#### Deferred to v2.0
| Feature | Reason | Target |
|---------|--------|--------|
| Self-hosted edition | Packaging complexity | v2.0 |
| SSO/SAML | Enterprise auth | v2.0 |
| Audit logs | Compliance requirement | v2.0 |
| Custom branding | White-label UI | v2.0 |
| On-premise deployment | Enterprise requirement | v2.0+ |

---

## MVP Technical Decisions

### Simplified for MVP

| Decision | MVP Approach | Future Approach |
|----------|--------------|-----------------|
| Auth | Phoenix + custom sessions | Add OAuth providers |
| Real-time | Phoenix Channels + Presence | Distributed PubSub (Fly.io) |
| Storage | PostgreSQL only | Add Redis for sessions |
| Document sync | No CRDT (MVP) | Yjs integration |
| Deployment | Single region (Fly.io) | Multi-region edge |

### Technical Debt Accepted

| Debt | Rationale | Payoff Plan |
|------|-----------|-------------|
| No CRDT sync | Complexity, MVP focus on presence | v1.1 Yjs integration |
| Basic reconnect | Simple exponential backoff | v1.1 sophisticated recovery |
| Limited analytics | Simplicity | v1.2 event pipeline |
| Single region | Cost, time | v1.2 multi-region |

---

## MVP User Stories

### Must Have (P0)

```gherkin
As a developer
I want to sign up and get an API key
So that I can integrate SyncForge into my app

As a developer
I want to install an npm package
So that I can add presence to my app quickly

As a developer
I want to show who's online in a room
So that my users know they're collaborating

As a developer
I want to display live cursors
So that users can see where others are pointing

As a developer
I want to add threaded comments
So that users can discuss specific elements

As a product user
I want to see my teammates' avatars online
So that I know who's working with me
```

### Should Have (P1)

```gherkin
As a developer
I want to customize cursor labels
So that they match my app's design

As a developer
I want presence metadata updates
So that I can show user status (typing, viewing, etc.)

As a developer
I want to anchor comments to elements
So that discussions have context

As a team admin
I want to see active rooms
So that I can monitor usage
```

---

## MVP Success Criteria

### Launch Readiness

- [ ] All P0 features implemented and tested
- [ ] 5 beta customers successfully integrated
- [ ] Presence sync <50ms (p95)
- [ ] Cursor broadcast <30ms (p95)
- [ ] 99.9% WebSocket uptime over 7 days
- [ ] SDK documentation complete
- [ ] Security audit completed

### Post-Launch Metrics (30 days)

| Metric | Target |
|--------|--------|
| Developer signups | 500 |
| Apps integrated | 50 |
| Trial → Paid conversion | 5% |
| Time to first integration | < 30 min average |
| SDK satisfaction (survey) | > 4.0/5.0 |

---

## MVP Timeline

### Week 1-2: Foundation
- Phoenix project setup
- Authentication flow
- Organization management
- Database schema + migrations
- CI/CD pipeline

### Week 3-4: Real-Time Core
- Phoenix Channels setup
- Presence tracking implementation
- Room management
- WebSocket connection handling
- Reconnection logic

### Week 5-6: Features
- Live cursor implementation
- Comments system
- Pre-built UI components
- Event broadcasting

### Week 7: SDK Development
- JavaScript SDK core
- React hooks
- TypeScript definitions
- SDK documentation
- Example applications

### Week 8: Launch Prep
- Developer dashboard
- Beta testing with partners
- Performance optimization
- Documentation polish
- Launch marketing

---

## MVP Constraints

### Technical Constraints
- Maximum 100 users per room
- Maximum 1,000 cursor updates per second per room
- 10 comments per minute per user (rate limit)
- WebSocket messages max 64KB

### Business Constraints
- $3,000/month infrastructure budget
- 2 engineers available
- 8-week timeline to beta

---

## Post-MVP Roadmap

### v1.1 (Month 2)
- Document sync (Yjs CRDT)
- Vue.js SDK
- Notifications system
- Webhook delivery

### v1.2 (Month 3)
- Voice rooms (WebRTC)
- Screen recording
- Multi-region deployment
- Advanced analytics

### v1.3 (Month 4)
- REST API
- Svelte SDK
- Custom webhooks
- Audit logging

### v2.0 (Month 6)
- Self-hosted edition
- Enterprise features (SSO, SOC2)
- White-label customization
- On-premise support

---

## Related Documents

- [PRD](PRD.md)
- [Technical Specifications](SPECS.md)
- [Data Model](DATA_MODEL.md)
- [Test Plan](TEST_PLAN.md)

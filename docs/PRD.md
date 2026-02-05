# SyncForge - Product Requirements Document

## Overview

SyncForge is a **Real-Time Collaboration Infrastructure** platform that enables developers to add multiplayer experiences to any application—presence indicators, live cursors, comments, notifications, and voice rooms—in minutes instead of months.

**Think**: Liveblocks, Cord, or Velt—but with self-hosting options, framework-agnostic design, and native Phoenix LiveView support built on the BEAM's legendary concurrency.

---

## Problem Statement

### The Problem

Developers building modern applications face mounting pressure to add real-time collaborative features:
- **Users expect multiplayer** - Figma, Notion, and Google Docs set the standard
- **Building real-time is hard** - WebSockets, presence, CRDTs, conflict resolution
- **Maintenance burden** - Real-time infrastructure requires specialized expertise
- **Scaling challenges** - Handling millions of concurrent connections reliably

### Why It Matters

- **80% of SaaS applications** will need real-time features by 2026
- Developers spend **3-6 months** building collaboration features from scratch
- **67% of users** prefer collaborative tools over single-player alternatives
- Real-time infrastructure costs **$50K-$500K/year** to build and maintain internally

### Current Solutions Fall Short

| Solution | Limitation |
|----------|------------|
| **Liveblocks** | React-centric, no self-hosting, unpredictable pricing |
| **Cord** | Closed ecosystem, limited customization, vendor lock-in |
| **Velt** | Early stage, limited features, no self-hosting |
| **Build In-House** | 6+ months, $500K+ cost, ongoing maintenance burden |
| **Firebase Realtime** | Not purpose-built for collaboration, limited presence |

---

## Ideal Customer Profile (ICP)

### Primary Persona: Full-Stack Developer

**Alex, Senior Developer at Growth-Stage Startup**
- Company: Series A-C SaaS (20-200 employees)
- Challenge: Product team wants "Figma-like" collaboration features
- Goal: Add presence, cursors, and comments without rebuilding infrastructure
- Budget: $200-1,000/month for tooling
- Technical skill: Experienced with JavaScript, some backend experience

**Characteristics:**
- Building productivity, design, or workflow tools
- Has deadlines and can't spend months on infrastructure
- Values developer experience and good documentation
- Cares about long-term maintainability and avoiding vendor lock-in

### Secondary Persona: Elixir/Phoenix Developer

**Jordan, Tech Lead at Elixir Shop**
- Company: Agency or product company using Elixir stack
- Challenge: No native Phoenix solution for real-time collaboration
- Goal: Leverage Phoenix Channels without building from scratch
- Budget: $100-500/month
- Technical skill: Deep Elixir/Phoenix expertise

**Why They Matter:**
- Underserved market with no native solution
- Strong community advocates
- Value self-hosting and BEAM reliability
- Early adopters who drive word-of-mouth

### Tertiary Persona: Engineering Leader

**Sam, VP Engineering**
- Company: Scaling startup with compliance requirements
- Challenge: Needs self-hosted solution for data sovereignty
- Goal: Real-time features without sending data to third parties
- Budget: $500-2,000/month (or enterprise pricing)
- Technical skill: Architectural decision maker

### Anti-Persona (Not Our Customer)

- Enterprise companies with existing real-time infrastructure
- Non-technical users looking for no-code solutions
- Simple chat applications (better served by dedicated chat SDKs)
- Gaming applications (need specialized netcode solutions)

---

## User Journeys

### Journey 1: First Room Integration

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    FIRST INTEGRATION (Target: 15 minutes)                   │
│                                                                              │
│  1. INSTALL SDK             2. CREATE ROOM            3. ADD PRESENCE       │
│  ─────────────────          ─────────────────         ─────────────────     │
│  • npm install syncforge    • Initialize client       • Track user presence │
│  • Get API key              • Create/join room        • Render online users │
│  • Import components        • Handle connection       • Show user avatars   │
│                                                                              │
│  4. ADD CURSORS             5. ENABLE COMMENTS        6. GO LIVE            │
│  ─────────────────          ─────────────────         ─────────────────     │
│  • Track cursor position    • Render comment threads  • Test with team      │
│  • Broadcast to room        • Add reply functionality • Deploy to prod      │
│  • Render other cursors     • Handle mentions         • Monitor dashboard   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Success Criteria:**
- Time to working presence indicators: < 15 minutes
- SDK installed and connected without errors
- Developer understands the room/presence model immediately

### Journey 2: Daily Development

```
Developer building feature
    │
    ├──→ Check docs for component API ──→ Clear examples found
    │
    ├──→ Implement collaborative feature
    │         │
    │         ├──→ Use pre-built components (fast path)
    │         │
    │         └──→ Build custom UI with hooks (flexible path)
    │
    ├──→ Test with multiple browser windows
    │
    └──→ Deploy and verify in production
```

**Success Criteria:**
- Documentation answers questions within 30 seconds
- Pre-built components work with minimal configuration
- Testing locally is easy with multiple connections
- Production debugging is straightforward via dashboard

### Journey 3: Scaling to Production

```
App gains traction
    │
    ├──→ Monitor real-time dashboard
    │         │
    │         ├──→ View active rooms and connections
    │         │
    │         ├──→ Monitor latency metrics
    │         │
    │         └──→ Set up alerts for issues
    │
    ├──→ Upgrade plan as MAU grows
    │
    └──→ (Optional) Migrate to self-hosted for scale/compliance
```

**Success Criteria:**
- Clear visibility into system health
- Predictable pricing as usage grows
- Smooth upgrade path to higher tiers
- Self-hosting available when needed

---

## Feature Scope

### MVP Features (v1.0)

| Feature | Description | Priority |
|---------|-------------|----------|
| **JavaScript SDK** | Core client library for web applications | P0 |
| **Room Management** | Create, join, leave rooms with state management | P0 |
| **Presence Tracking** | Real-time user presence with metadata | P0 |
| **Live Cursors** | Broadcast and render cursor positions | P0 |
| **Phoenix Channels** | Server-side real-time infrastructure | P0 |
| **Pre-built Components** | React components for presence, cursors | P0 |
| **Dashboard** | Room monitoring, connection metrics | P0 |
| **Comments System** | Threaded comments anchored to elements | P1 |
| **Notifications** | Real-time in-app notifications | P1 |
| **Webhooks** | Event callbacks for server integrations | P1 |

### Post-MVP Features (v1.x)

| Feature | Description | Version |
|---------|-------------|---------|
| **Vue/Svelte SDKs** | Framework-specific SDK packages | v1.1 |
| **Phoenix LiveView SDK** | Native Elixir/LiveView integration | v1.1 |
| **CRDT Document Sync** | Yjs-based collaborative editing | v1.2 |
| **Voice Rooms** | Spatial audio for collaboration | v1.2 |
| **Screen Recording** | Async video messages | v1.3 |
| **AI Copilot** | Smart suggestions and automation | v1.3 |
| **Self-Hosting Package** | Docker/Kubernetes deployment | v1.4 |
| **Analytics Dashboard** | Collaboration insights and metrics | v1.4 |

### Out of Scope (v1.x)

- Video conferencing (use Twilio, Daily.co)
- File storage/sync (use S3, Cloudflare R2)
- Authentication (use existing auth systems)
- Rich text editing (provide CRDT foundation, not full editor)

---

## Success Metrics

### North Star Metric

**Weekly Active Rooms per Organization**
- Target: 10+ active rooms per org weekly
- Indicates deep integration and ongoing usage
- Correlates with retention and expansion

### Developer Experience Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Time to first presence | < 15 min | Signup → First user appears online |
| Documentation satisfaction | > 4.5/5 | Post-doc survey rating |
| SDK install success | > 95% | Install → Connect success rate |
| Integration completion | > 70% | Started → Deployed to production |

### Engagement Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| DAU/MAU | > 30% | Daily active / Monthly active developers |
| Rooms per org | > 10 | Average active rooms per organization |
| Connections per room | > 3 avg | Average concurrent users per room |
| Features per integration | > 2 | Presence, cursors, comments, etc. |

### Performance Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Presence sync latency | < 50ms | Time for presence to propagate |
| Cursor broadcast latency | < 30ms | Time for cursor to appear |
| Document sync latency | < 100ms | Time for CRDT update to sync |
| Connection success rate | > 99.9% | Successful WebSocket connections |
| Uptime | > 99.95% | Service availability |

### Retention Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| 30-day retention | > 70% | Active after 30 days |
| 90-day retention | > 55% | Active after 90 days |
| Net Revenue Retention | > 120% | Expansion - Churn |
| Churn rate | < 3% monthly | Cancelled / Total paid |

### Support Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| NPS | > 50 | Net Promoter Score |
| Support tickets/user | < 0.3/month | Tickets / Active developers |
| Time to resolution | < 2 hours | Ticket open → Resolved |
| Self-serve resolution | > 80% | Resolved via docs without support |

---

## Competitive Analysis

### Direct Competitors

| Feature | SyncForge | Liveblocks | Cord | Velt |
|---------|-----------|------------|------|------|
| **Self-hosting** | ✅ | ❌ | ❌ | ❌ |
| **Framework agnostic** | ✅ | ⚠️ React-heavy | ⚠️ | ⚠️ |
| **Phoenix/LiveView native** | ✅ | ❌ | ❌ | ❌ |
| **Pre-built UI** | ✅ | ✅ | ✅ | ✅ |
| **CRDT sync** | ✅ | ✅ | ❌ | ⚠️ |
| **Voice rooms** | ✅ | ❌ | ✅ | ❌ |
| **Predictable pricing** | ✅ | ❌ | ❌ | ❌ |
| **Open source option** | ✅ | ❌ | ❌ | ❌ |
| **Starting price** | $49/mo | ~$100/mo | Custom | ~$100/mo |

### Our Differentiation

1. **Self-hosting available** - Only solution offering full self-hosted deployment
2. **Framework agnostic** - Works with React, Vue, Svelte, vanilla JS, and LiveView
3. **Phoenix/LiveView native** - Built on BEAM for unmatched real-time performance
4. **Predictable pricing** - MAU-based pricing with clear tiers, no usage surprises
5. **Developer experience** - Clear docs, fast integration, minimal boilerplate

### Positioning Statement

> For developers building collaborative applications who need real-time features fast, SyncForge is the only collaboration infrastructure that offers self-hosting, framework flexibility, and predictable pricing—powered by the same technology that runs WhatsApp's real-time infrastructure.

---

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **WebSocket scaling** | Performance degradation | Medium | Fly.io global edge, connection pooling, load testing |
| **CRDT complexity** | Sync bugs | Medium | Use battle-tested Yjs, extensive testing, clear mental models |
| **Competitor response** | Market pressure | High | Speed to market, focus on underserved niches (Elixir, self-hosting) |
| **Security breach** | Reputation damage | Low | SOC2, encryption in transit/at rest, regular audits |
| **SDK fragmentation** | Maintenance burden | Medium | Core SDK with framework adapters, automated testing |
| **Pricing pressure** | Margin compression | Medium | Efficient architecture, self-hosting upsell |

---

## Go-to-Market

### Launch Strategy

1. **Alpha (Week 1-4)**
   - 10-15 design partners (Elixir companies, dev tool builders)
   - Daily feedback calls
   - Iterate on SDK ergonomics

2. **Private Beta (Week 5-8)**
   - 50-100 developers
   - Focus on React + Phoenix LiveView SDKs
   - Launch documentation site
   - Start community Discord

3. **Public Beta (Week 9-12)**
   - Open signups
   - Launch on Product Hunt, Hacker News
   - Conference talks (ElixirConf, ReactConf)
   - Content marketing (tutorials, case studies)

4. **General Availability (Week 13+)**
   - Pricing tiers live
   - Self-hosting available
   - Enterprise sales motion begins

### Pricing Strategy

| Plan | Price | MAU | Rooms | Features |
|------|-------|-----|-------|----------|
| **Free** | $0/mo | 50 | 3 | Presence, Cursors (dev only) |
| **Starter** | $49/mo | 1,000 | 10 | + Comments, Notifications |
| **Pro** | $199/mo | 10,000 | 100 | + Voice Rooms, Webhooks, Priority Support |
| **Business** | $499/mo | 50,000 | Unlimited | + Analytics, Custom Domains, SSO |
| **Enterprise** | Custom | Custom | Custom | + Self-Hosting, SLA, Dedicated Support |

### Distribution Channels

1. **Developer content** - Blog posts, tutorials, YouTube videos
2. **Open source** - Phoenix library, SDK on npm
3. **Community** - Discord, GitHub discussions, Twitter/X
4. **Conferences** - ElixirConf, ReactConf, local meetups
5. **Integrations** - Vercel, Railway, Fly.io marketplace

---

## Technical Architecture Highlights

### Why Elixir/Phoenix?

- **Phoenix Channels** - Battle-tested WebSocket infrastructure (2M+ concurrent connections)
- **Phoenix Presence** - Built-in CRDT-based presence tracking
- **BEAM concurrency** - Handles millions of lightweight processes
- **Fault tolerance** - "Let it crash" philosophy for reliability
- **Hot code upgrades** - Deploy without disconnecting users

### Performance Targets

| Metric | Target |
|--------|--------|
| Presence sync | < 50ms globally |
| Cursor broadcast | < 30ms P99 |
| Document sync | < 100ms for 1MB doc |
| Reconnection | < 2 seconds |
| Message throughput | 100K msgs/sec per node |

### Deployment Architecture

```
                    ┌─────────────────────┐
                    │   Global CDN/Edge   │
                    │   (Fly.io Edge)     │
                    └──────────┬──────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
   ┌────▼────┐           ┌────▼────┐           ┌────▼────┐
   │ Region A │           │ Region B │           │ Region C │
   │  (IAD)   │           │  (AMS)   │           │  (SIN)   │
   └────┬────┘           └────┬────┘           └────┬────┘
        │                      │                      │
   ┌────▼────┐           ┌────▼────┐           ┌────▼────┐
   │ Phoenix  │◄────────►│ Phoenix  │◄────────►│ Phoenix  │
   │ Cluster  │  PubSub   │ Cluster  │  PubSub   │ Cluster  │
   └────┬────┘           └────┬────┘           └────┬────┘
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │   PostgreSQL +      │
                    │   Read Replicas     │
                    └─────────────────────┘
```

---

## Related Documents

- [Technical Specifications](SPECS.md)
- [Data Model](DATA_MODEL.md)
- [API Specification](API_SPEC.md)
- [JavaScript SDK Guide](SDK_GUIDE.md)
- [Self-Hosting Guide](SELF_HOSTING.md)
- [Test Plan](TEST_PLAN.md)

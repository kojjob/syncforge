# SyncForge - Technical Specifications

## Overview

Technical specifications for SyncForge, a **Real-Time Collaboration Infrastructure** platform. This document covers functional and non-functional requirements, system constraints, and technical decisions for building multiplayer experiences.

**Tech Stack**: Elixir, Phoenix 1.7+, Phoenix Channels, Phoenix Presence, Yjs (CRDT), PostgreSQL, Oban, Fly.io

---

## Functional Requirements

### FR-1: User Management

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | Developers can sign up with email/password | P0 |
| FR-1.2 | Developers can sign up/in with Google OAuth | P0 |
| FR-1.3 | Developers can sign up/in with GitHub OAuth | P0 |
| FR-1.4 | Developers can reset password via email | P0 |
| FR-1.5 | Developers can enable MFA (TOTP) | P1 |
| FR-1.6 | Developers can update profile information | P0 |
| FR-1.7 | Developers can generate and manage API keys | P0 |
| FR-1.8 | Developers can view API key usage and analytics | P1 |

### FR-2: Organization Management

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Developers can create organizations | P0 |
| FR-2.2 | Owners can invite team members by email | P0 |
| FR-2.3 | Owners can assign roles (Owner, Admin, Member) | P0 |
| FR-2.4 | Owners can remove team members | P0 |
| FR-2.5 | Organizations have separate API key namespaces | P0 |
| FR-2.6 | Organizations have configurable settings and branding | P1 |

### FR-3: Room Management

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | SDK clients can create collaboration rooms | P0 |
| FR-3.2 | SDK clients can join existing rooms by ID | P0 |
| FR-3.3 | SDK clients can leave rooms gracefully | P0 |
| FR-3.4 | Rooms support configurable maximum participants | P0 |
| FR-3.5 | Rooms can be public or require authentication | P0 |
| FR-3.6 | Rooms automatically clean up when empty (configurable TTL) | P1 |
| FR-3.7 | Rooms support metadata storage (JSON config) | P0 |
| FR-3.8 | Dashboard shows active rooms and participant counts | P1 |

### FR-4: Presence System

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | System tracks user presence in rooms in real-time | P0 |
| FR-4.2 | Presence includes user identity and metadata | P0 |
| FR-4.3 | Presence syncs across all connected clients instantly | P0 |
| FR-4.4 | Clients receive presence_diff events for changes | P0 |
| FR-4.5 | System handles disconnect/reconnect gracefully | P0 |
| FR-4.6 | Presence supports custom user metadata (status, cursor, etc.) | P0 |
| FR-4.7 | Presence TTL configurable per room (default 30s) | P1 |
| FR-4.8 | "Others" helper excludes current user from presence list | P0 |

### FR-5: Live Cursors

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-5.1 | Clients can broadcast cursor positions in real-time | P0 |
| FR-5.2 | Cursor positions include x, y coordinates | P0 |
| FR-5.3 | Cursors support element-relative positioning | P1 |
| FR-5.4 | Cursors include user identity for display | P0 |
| FR-5.5 | Cursor updates are throttled to optimize bandwidth | P0 |
| FR-5.6 | Cursors fade out when users become idle | P1 |
| FR-5.7 | SDK provides pre-built cursor UI components | P0 |

### FR-6: Document Sync (CRDT)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-6.1 | Documents support conflict-free concurrent editing | P0 |
| FR-6.2 | System uses Yjs CRDT for document state | P0 |
| FR-6.3 | Document updates broadcast to all room participants | P0 |
| FR-6.4 | New clients receive full document state on join | P0 |
| FR-6.5 | Documents persist to database (debounced) | P0 |
| FR-6.6 | Documents support versioning and history | P1 |
| FR-6.7 | Documents can be restored to previous snapshots | P2 |
| FR-6.8 | Awareness protocol syncs selections and cursors | P0 |

### FR-7: Comments & Threads

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-7.1 | Users can create comments in rooms | P0 |
| FR-7.2 | Comments can be anchored to specific elements | P0 |
| FR-7.3 | Comments support threaded replies | P0 |
| FR-7.4 | Comments can be resolved/unresolved | P0 |
| FR-7.5 | Comments support @mentions with notifications | P1 |
| FR-7.6 | Comments support emoji reactions | P1 |
| FR-7.7 | Comment threads update in real-time | P0 |
| FR-7.8 | SDK provides pre-built comment UI components | P1 |

### FR-8: Notifications

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-8.1 | Users receive real-time in-app notifications | P0 |
| FR-8.2 | Notifications include mentions, replies, and system events | P0 |
| FR-8.3 | Notifications can be marked as read | P0 |
| FR-8.4 | Notifications support custom types and payloads | P1 |
| FR-8.5 | Notifications persist for offline users | P0 |
| FR-8.6 | SDK provides notification inbox component | P1 |
| FR-8.7 | Webhooks trigger for notification events | P2 |

### FR-9: Voice Rooms

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-9.1 | Users can join voice sessions in rooms | P2 |
| FR-9.2 | Voice supports mute/unmute controls | P2 |
| FR-9.3 | Voice sessions show speaking indicators | P2 |
| FR-9.4 | Voice supports spatial audio positioning | P3 |
| FR-9.5 | Voice integrates with presence system | P2 |

### FR-10: Webhooks & Integrations

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-10.1 | Organizations can configure webhook endpoints | P1 |
| FR-10.2 | Webhooks fire on room, presence, and comment events | P1 |
| FR-10.3 | Webhooks include signature for verification | P1 |
| FR-10.4 | Webhook deliveries are retried on failure | P1 |
| FR-10.5 | Dashboard shows webhook delivery history | P2 |

### FR-11: Billing & Plans

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-11.1 | System tracks monthly active users (MAU) | P0 |
| FR-11.2 | System enforces plan limits (MAU, rooms, features) | P0 |
| FR-11.3 | Users can upgrade/downgrade plans | P0 |
| FR-11.4 | Users can enter payment information via Stripe | P0 |
| FR-11.5 | Dashboard shows usage analytics and billing history | P1 |
| FR-11.6 | System sends usage approaching limit notifications | P1 |

---

## Non-Functional Requirements

### NFR-1: Real-Time Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-1.1 | Presence sync latency (P95) | < 50ms |
| NFR-1.2 | Cursor broadcast latency (P95) | < 30ms |
| NFR-1.3 | Document update propagation (P95) | < 100ms |
| NFR-1.4 | WebSocket connection establishment | < 500ms |
| NFR-1.5 | Reconnection with state recovery | < 2 seconds |
| NFR-1.6 | Message throughput per room | 10,000 msg/sec |

### NFR-2: API Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-2.1 | REST API response time (P95) | < 100ms |
| NFR-2.2 | API rate limit (per API key) | 1,000 req/min |
| NFR-2.3 | Webhook delivery latency | < 5 seconds |
| NFR-2.4 | Dashboard page load time (P95) | < 2 seconds |

### NFR-3: Scalability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-3.1 | Concurrent WebSocket connections | 100,000 |
| NFR-3.2 | Active rooms | 50,000 |
| NFR-3.3 | Participants per room | 500 |
| NFR-3.4 | Organizations | 10,000 |
| NFR-3.5 | Monthly active users | 1,000,000 |
| NFR-3.6 | Geographic distribution | 6+ regions |
| NFR-3.7 | Horizontal scaling | Auto-scale 1-100 nodes |

### NFR-4: Reliability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-4.1 | System uptime | 99.95% |
| NFR-4.2 | Data durability | 99.999% |
| NFR-4.3 | Recovery Point Objective (RPO) | 1 minute |
| NFR-4.4 | Recovery Time Objective (RTO) | 5 minutes |
| NFR-4.5 | Zero-downtime deployments | Required |
| NFR-4.6 | Message delivery guarantee | At-least-once |
| NFR-4.7 | Connection recovery success rate | > 99% |

### NFR-5: Security

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-5.1 | Authentication | API keys + JWT tokens |
| NFR-5.2 | Authorization | Room-level permissions |
| NFR-5.3 | Encryption in transit | TLS 1.3 (WebSocket + HTTPS) |
| NFR-5.4 | Encryption at rest | AES-256 |
| NFR-5.5 | API key security | Hashed storage, scoped permissions |
| NFR-5.6 | Webhook verification | HMAC-SHA256 signatures |
| NFR-5.7 | Rate limiting | Per-key and per-IP |
| NFR-5.8 | Compliance | SOC2 Type II (Year 2 goal) |

### NFR-6: Developer Experience

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-6.1 | Time to first presence | < 5 minutes |
| NFR-6.2 | SDK bundle size (gzipped) | < 20 KB |
| NFR-6.3 | SDK framework support | React, Vue, Vanilla JS, LiveView |
| NFR-6.4 | TypeScript coverage | 100% |
| NFR-6.5 | Documentation coverage | 100% of SDK methods |
| NFR-6.6 | Interactive examples | All major features |

### NFR-7: Observability

| ID | Requirement | Target |
|----|-------------|--------|
| NFR-7.1 | Log retention | 30 days |
| NFR-7.2 | Metric granularity | 10 seconds |
| NFR-7.3 | Alert latency | < 30 seconds |
| NFR-7.4 | Distributed tracing | 100% of requests |
| NFR-7.5 | Real-time connection monitoring | Dashboard + alerts |

---

## System Constraints

### Technical Constraints

| Constraint | Description | Mitigation |
|------------|-------------|------------|
| WebSocket limits | Browser connection limits (6-256 per domain) | Connection pooling, domain sharding |
| BEAM process limits | Per-node process limits | Horizontal scaling, process pooling |
| Yjs state size | Large documents impact sync performance | Snapshots, lazy loading, compression |
| Geographic latency | Cross-region latency affects UX | Multi-region deployment on Fly.io |
| Database connections | Connection pool exhaustion | PgBouncer, connection limits per org |

### Business Constraints

| Constraint | Description | Impact |
|------------|-------------|--------|
| MVP timeline | 12 weeks to beta | Feature prioritization required |
| Team size | 2-3 engineers | Focus on core real-time features |
| Infrastructure budget | $3K/month initial | Fly.io cost-optimized deployment |
| Self-hosting requirement | Enterprise customers need on-premise | Containerized deployment from start |

---

## Technical Decisions

### TD-1: Real-Time Architecture

**Decision**: Phoenix Channels with Phoenix Presence on BEAM VM

**Rationale**:
- Phoenix Channels provide production-proven WebSocket handling
- Phoenix Presence offers CRDT-based presence with automatic conflict resolution
- BEAM VM provides per-connection process isolation (millions of connections)
- Built-in fault tolerance with supervisor trees
- Native clustering for horizontal scaling
- Fly.io deployment enables global edge distribution

**Example Channel Implementation**:

```elixir
defmodule SyncForgeWeb.RoomChannel do
  use SyncForgeWeb, :channel

  alias SyncForge.Presence.Tracker
  alias SyncForge.Rooms

  @impl true
  def join("room:" <> room_id, params, socket) do
    case Rooms.authorize_join(room_id, socket.assigns.api_key, params) do
      {:ok, room, user_info} ->
        send(self(), :after_join)
        {:ok, assign(socket, room: room, user_info: user_info)}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    # Track presence with user metadata
    {:ok, _} = Tracker.track(socket, socket.assigns.user_info.id, %{
      user: socket.assigns.user_info,
      joined_at: System.system_time(:second)
    })

    # Push current state
    push(socket, "presence_state", Tracker.list(socket))
    push(socket, "room_state", Rooms.get_state(socket.assigns.room.id))

    {:noreply, socket}
  end

  @impl true
  def handle_in("cursor:update", payload, socket) do
    broadcast_from(socket, "cursor:update", Map.put(payload, :user_id, socket.assigns.user_info.id))
    {:noreply, socket}
  end

  @impl true
  def handle_in("doc:update", %{"update" => update}, socket) do
    broadcast_from(socket, "doc:update", %{update: update})
    Rooms.apply_document_update(socket.assigns.room.id, update)
    {:noreply, socket}
  end
end
```

### TD-2: Document Synchronization

**Decision**: Yjs CRDT with Elixir NIF binding

**Rationale**:
- Yjs is the industry-standard CRDT library (used by Liveblocks, Notion, etc.)
- Conflict-free by design—no server-side conflict resolution needed
- Awareness protocol for cursor/selection sync
- Efficient binary encoding (10-100x smaller than JSON)
- Battle-tested with millions of users
- NIF binding enables server-side document processing

**Document Flow**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      DOCUMENT SYNCHRONIZATION FLOW                           │
│                                                                              │
│  1. CLIENT EDIT         2. ENCODE               3. BROADCAST                 │
│  ────────────           ──────────              ────────────                 │
│  • User types/edits     • Yjs encodes delta     • Phoenix Channel            │
│  • Local Yjs update     • Binary format         • broadcast_from/3           │
│  • Immediate render     • Minimal size          • Skip sender                │
│                                                                              │
│  4. RECEIVE             5. APPLY                6. PERSIST                   │
│  ────────────           ──────────              ────────────                 │
│  • Other clients        • Yjs merges update     • Debounced (5s)             │
│  • Decode binary        • CRDT guarantees       • Snapshot to DB             │
│  • Update local doc     • No conflicts          • Version increment          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### TD-3: Database & Persistence

**Decision**: PostgreSQL with Ecto

**Rationale**:
- Robust JSON/JSONB support for flexible metadata
- Strong consistency for billing and auth data
- Binary column support for Yjs state storage
- Excellent Elixir integration with Ecto
- Good scaling with read replicas
- Fly.io Postgres with global read replicas

**Example Schema**:

```elixir
defmodule SyncForge.Rooms.Room do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "rooms" do
    field :name, :string
    field :type, Ecto.Enum, values: [:collaboration, :whiteboard, :document, :custom]
    field :config, :map, default: %{}
    field :max_participants, :integer, default: 100
    field :is_public, :boolean, default: false

    belongs_to :organization, SyncForge.Accounts.Organization, type: :binary_id
    has_one :document, SyncForge.Documents.Document
    has_many :participants, SyncForge.Rooms.Participant
    has_many :comments, SyncForge.Comments.Comment

    timestamps()
  end
end

defmodule SyncForge.Documents.Document do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "documents" do
    field :state, :binary           # Yjs encoded state
    field :version, :integer, default: 0
    field :last_persisted_at, :utc_datetime

    belongs_to :room, SyncForge.Rooms.Room, type: :binary_id
    has_many :snapshots, SyncForge.Documents.Snapshot

    timestamps()
  end
end
```

### TD-4: Background Jobs

**Decision**: Oban with PostgreSQL

**Rationale**:
- Reliable job processing with PostgreSQL (no Redis dependency)
- Transactional job enqueuing with document updates
- Built-in retry with exponential backoff
- Oban Web for observability
- Job uniqueness for deduplication
- Cron-like scheduling for cleanup tasks

**Example Workers**:

```elixir
# Document persistence (debounced)
defmodule SyncForge.Workers.DocumentPersistWorker do
  use Oban.Worker,
    queue: :documents,
    unique: [period: 5, fields: [:args]]  # Dedupe within 5 seconds

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"room_id" => room_id, "update" => update}}) do
    SyncForge.Documents.apply_and_persist(room_id, update)
  end
end

# Webhook delivery with retries
defmodule SyncForge.Workers.WebhookDeliveryWorker do
  use Oban.Worker,
    queue: :webhooks,
    max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"webhook_id" => id, "event" => event, "payload" => payload}}) do
    SyncForge.Webhooks.deliver(id, event, payload)
  end

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    # Exponential backoff: 10s, 30s, 90s, 270s, 810s
    trunc(:math.pow(3, attempt) * 10)
  end
end

# Room cleanup (scheduled)
defmodule SyncForge.Workers.RoomCleanupWorker do
  use Oban.Worker, queue: :maintenance

  @impl Oban.Worker
  def perform(_job) do
    SyncForge.Rooms.cleanup_stale_rooms()
  end
end
```

### TD-5: Authentication Architecture

**Decision**: API keys for SDK + JWT for dashboard sessions

**Rationale**:
- API keys are developer-friendly for SDK integration
- JWT provides stateless session management for dashboard
- Separate auth flows for different user types
- API keys scoped to organization with permissions
- Rotating keys without downtime

**API Key Authentication**:

```elixir
defmodule SyncForgeWeb.Plugs.ApiKeyAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, api_key} <- extract_api_key(conn),
         {:ok, organization} <- verify_api_key(api_key) do
      conn
      |> assign(:api_key, api_key)
      |> assign(:organization, organization)
    else
      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: reason})
        |> halt()
    end
  end

  defp extract_api_key(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> key] -> {:ok, key}
      _ -> {:error, "Missing API key"}
    end
  end

  defp verify_api_key(key) do
    case SyncForge.Accounts.get_organization_by_api_key(key) do
      nil -> {:error, "Invalid API key"}
      org -> {:ok, org}
    end
  end
end
```

### TD-6: Multi-Region Deployment

**Decision**: Fly.io with global edge deployment

**Rationale**:
- Fly.io optimized for Phoenix/BEAM applications
- Global edge deployment (30+ regions)
- Built-in clustering for Phoenix nodes
- Automatic failover and load balancing
- Fly Postgres with read replicas
- Cost-effective for real-time workloads

**Deployment Architecture**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          GLOBAL DEPLOYMENT                                   │
│                                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐              │
│  │  US-East │    │ US-West  │    │  Europe  │    │   Asia   │              │
│  │  (iad)   │    │  (sjc)   │    │  (ams)   │    │  (nrt)   │              │
│  └────┬─────┘    └────┬─────┘    └────┬─────┘    └────┬─────┘              │
│       │               │               │               │                     │
│       └───────────────┴───────────────┴───────────────┘                     │
│                           │                                                  │
│                    ┌──────┴──────┐                                          │
│                    │   Fly.io    │                                          │
│                    │  Clustering │                                          │
│                    └──────┬──────┘                                          │
│                           │                                                  │
│               ┌───────────┴───────────┐                                     │
│               │     Primary DB        │                                     │
│               │   (Fly Postgres)      │                                     │
│               │   + Read Replicas     │                                     │
│               └───────────────────────┘                                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## API Design Principles

### WebSocket Protocol

```javascript
// Connection
wss://api.syncforge.io/socket?api_key=sk_live_xxx

// Join room
{
  "topic": "room:abc123",
  "event": "phx_join",
  "payload": { "user_id": "user_1", "user_info": { "name": "Alice" } },
  "ref": "1"
}

// Presence events (server -> client)
{
  "topic": "room:abc123",
  "event": "presence_state",
  "payload": { "user_1": { "metas": [{ "name": "Alice", "online_at": 1234567890 }] } }
}

{
  "topic": "room:abc123",
  "event": "presence_diff",
  "payload": { "joins": {}, "leaves": { "user_1": { "metas": [...] } } }
}

// Cursor update (client -> server)
{
  "topic": "room:abc123",
  "event": "cursor:update",
  "payload": { "x": 100, "y": 200 },
  "ref": "2"
}

// Document update (bidirectional)
{
  "topic": "room:abc123",
  "event": "doc:update",
  "payload": { "update": "<base64-encoded-yjs-update>" }
}
```

### REST API Endpoints

```
# Organizations
GET    /api/v1/organizations           # List orgs
POST   /api/v1/organizations           # Create org
GET    /api/v1/organizations/:id       # Get org
PATCH  /api/v1/organizations/:id       # Update org

# Rooms (management API)
GET    /api/v1/rooms                   # List rooms
POST   /api/v1/rooms                   # Create room
GET    /api/v1/rooms/:id               # Get room
DELETE /api/v1/rooms/:id               # Delete room
GET    /api/v1/rooms/:id/participants  # List participants

# Comments
GET    /api/v1/rooms/:id/comments      # List comments
POST   /api/v1/rooms/:id/comments      # Create comment
PATCH  /api/v1/comments/:id            # Update comment
DELETE /api/v1/comments/:id            # Delete comment

# Analytics
GET    /api/v1/analytics/usage         # Usage statistics
GET    /api/v1/analytics/rooms         # Room analytics

# Webhooks
GET    /api/v1/webhooks                # List webhooks
POST   /api/v1/webhooks                # Create webhook
DELETE /api/v1/webhooks/:id            # Delete webhook
```

### Error Response Format

```json
{
  "error": {
    "code": "ROOM_FULL",
    "message": "Room has reached maximum participants",
    "details": {
      "room_id": "room_abc123",
      "current_count": 100,
      "max_count": 100
    }
  },
  "request_id": "req_xyz789"
}
```

### Standard Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `UNAUTHORIZED` | 401 | Invalid or missing API key |
| `FORBIDDEN` | 403 | API key lacks required permissions |
| `ROOM_NOT_FOUND` | 404 | Room does not exist |
| `ROOM_FULL` | 403 | Room at max capacity |
| `RATE_LIMITED` | 429 | Too many requests |
| `PLAN_LIMIT_EXCEEDED` | 403 | Usage exceeds plan limits |
| `VALIDATION_ERROR` | 400 | Invalid request parameters |
| `INTERNAL_ERROR` | 500 | Server error |

---

## JavaScript SDK Architecture

### SDK Design Principles

```javascript
// Simple, intuitive API
import { SyncForge } from "@syncforge/client";

const client = new SyncForge({
  apiKey: "pk_live_xxx",
  // Optional: custom endpoint for self-hosted
  endpoint: "wss://collab.yourapp.com/socket"
});

// Join a room
const room = await client.joinRoom("my-room", {
  userId: "user_123",
  userInfo: { name: "Alice", avatar: "..." }
});

// Presence
room.presence.subscribe((users) => {
  console.log("Users in room:", users);
});

// Others (excludes self)
room.presence.subscribeOthers((others) => {
  console.log("Other users:", others);
});

// Cursors
room.cursors.subscribe((cursors) => {
  // Render cursor positions
});

room.cursors.update({ x: 100, y: 200 });

// Document sync (Yjs)
const doc = room.getDocument();
const text = doc.getText("content");

text.observe((event) => {
  // Handle text changes
});

// Comments
room.comments.subscribe((comments) => {
  // Render comments
});

await room.comments.create({
  body: "Great work!",
  anchorId: "element-123"
});

// Cleanup
room.leave();
```

### React Integration

```jsx
import { SyncForgeProvider, useRoom, usePresence, useCursors } from "@syncforge/react";

function App() {
  return (
    <SyncForgeProvider apiKey="pk_live_xxx">
      <CollaborativeEditor roomId="doc-123" />
    </SyncForgeProvider>
  );
}

function CollaborativeEditor({ roomId }) {
  const { room, status } = useRoom(roomId, {
    userId: currentUser.id,
    userInfo: { name: currentUser.name }
  });

  const { users, others } = usePresence(room);
  const { cursors, updateCursor } = useCursors(room);

  if (status === "connecting") return <Loading />;

  return (
    <div onMouseMove={(e) => updateCursor({ x: e.clientX, y: e.clientY })}>
      <PresenceAvatars users={others} />
      <CursorLayer cursors={cursors} />
      <Editor room={room} />
    </div>
  );
}
```

### LiveView Integration

```elixir
# Native Phoenix LiveView hooks
defmodule SyncForgeWeb.CollaborativeLive do
  use SyncForgeWeb, :live_view

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(SyncForge.PubSub, "room:#{room_id}")
      SyncForge.Rooms.join(room_id, socket.assigns.current_user)
    end

    {:ok,
     socket
     |> assign(:room_id, room_id)
     |> assign(:presence, [])
     |> assign(:cursors, %{})}
  end

  @impl true
  def handle_info({:presence_update, presence}, socket) do
    {:noreply, assign(socket, :presence, presence)}
  end

  @impl true
  def handle_event("cursor:move", %{"x" => x, "y" => y}, socket) do
    SyncForge.Rooms.broadcast_cursor(socket.assigns.room_id, socket.assigns.current_user.id, x, y)
    {:noreply, socket}
  end
end
```

---

## Security Architecture

### Security Layers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          SECURITY ARCHITECTURE                               │
│                                                                              │
│  CLIENT                 EDGE                   APPLICATION                   │
│  ────────────           ────────────           ────────────                  │
│  • TLS 1.3              • Fly.io proxy         • API key validation          │
│  • API key in header    • Rate limiting        • Room authorization          │
│  • CORS validation      • DDoS protection      • Permission checks           │
│                                                                              │
│  WEBSOCKET              DATA LAYER             INFRASTRUCTURE                │
│  ────────────           ────────────           ────────────                  │
│  • Auth on connect      • Encryption at rest   • Secrets in env vars         │
│  • Per-room auth        • Audit logging        • Network isolation           │
│  • Message validation   • Data retention       • Regular backups             │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Room Authorization

```elixir
defmodule SyncForge.Rooms.Authorization do
  @moduledoc """
  Authorization logic for room access.
  """

  def authorize_join(room, api_key, user_params) do
    with :ok <- verify_organization_access(room, api_key),
         :ok <- verify_room_capacity(room),
         :ok <- verify_room_permissions(room, user_params) do
      {:ok, room}
    end
  end

  defp verify_organization_access(room, api_key) do
    if room.organization_id == api_key.organization_id do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  defp verify_room_capacity(room) do
    current = SyncForge.Presence.Tracker.count_participants(room.id)
    if current < room.max_participants do
      :ok
    else
      {:error, :room_full}
    end
  end

  defp verify_room_permissions(room, user_params) do
    if room.is_public or user_params["token"] do
      :ok
    else
      {:error, :forbidden}
    end
  end
end
```

---

## Monitoring & Observability

### Key Metrics

| Category | Metric | Alert Threshold |
|----------|--------|-----------------|
| Real-time | WebSocket connections | > 80% capacity |
| Real-time | Message latency (P95) | > 100ms |
| Real-time | Presence sync failures | > 1% |
| Reliability | Connection drop rate | > 0.5% |
| Reliability | Document sync conflicts | > 0.1% |
| Performance | API latency (P95) | > 200ms |
| Capacity | Rooms per node | > 5,000 |
| Capacity | Connections per node | > 10,000 |

### Telemetry Events

```elixir
defmodule SyncForge.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def metrics do
    [
      # WebSocket metrics
      counter("syncforge.channel.join.total", tags: [:room_type]),
      counter("syncforge.channel.leave.total", tags: [:reason]),
      summary("syncforge.channel.message.duration", unit: {:native, :millisecond}),

      # Presence metrics
      last_value("syncforge.presence.participants.count", tags: [:room_id]),
      counter("syncforge.presence.sync.total", tags: [:status]),

      # Document metrics
      counter("syncforge.document.update.total"),
      summary("syncforge.document.update.size", unit: :byte),
      counter("syncforge.document.persist.total", tags: [:status]),

      # Business metrics
      last_value("syncforge.organizations.count"),
      last_value("syncforge.mau.count"),
      counter("syncforge.api.request.total", tags: [:endpoint, :status])
    ]
  end
end
```

---

## Deployment Configuration

### Fly.io Configuration

```toml
# fly.toml
app = "syncforge"
primary_region = "iad"

[build]
  builder = "heroku/buildpacks:20"

[env]
  PHX_HOST = "api.syncforge.io"
  PORT = "8080"
  POOL_SIZE = "10"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = false  # Keep alive for WebSockets
  auto_start_machines = true
  min_machines_running = 2

  [http_service.concurrency]
    type = "connections"
    hard_limit = 10000
    soft_limit = 8000

[[services]]
  protocol = "tcp"
  internal_port = 8080

  [[services.ports]]
    port = 443
    handlers = ["tls", "http"]

  [[services.tcp_checks]]
    interval = "10s"
    timeout = "2s"
    grace_period = "30s"

[metrics]
  port = 9091
  path = "/metrics"
```

### Release Configuration

```elixir
# mix.exs
def project do
  [
    app: :syncforge,
    version: "0.1.0",
    elixir: "~> 1.15",
    releases: [
      syncforge: [
        include_executables_for: [:unix],
        applications: [runtime_tools: :permanent],
        steps: [:assemble, :tar]
      ]
    ]
  ]
end

# config/runtime.exs
config :syncforge, SyncForgeWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST"), port: 443, scheme: "https"],
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: String.to_integer(System.get_env("PORT") || "4000")
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE")

# Clustering for Fly.io
config :libcluster,
  topologies: [
    fly6pn: [
      strategy: Cluster.Strategy.DNSPoll,
      config: [
        polling_interval: 5_000,
        query: "#{System.get_env("FLY_APP_NAME")}.internal",
        node_basename: System.get_env("FLY_APP_NAME")
      ]
    ]
  ]
```

---

## Related Documents

- [CLAUDE.md](../CLAUDE.md) - Development guidelines and patterns
- [Data Model](DATA_MODEL.md) - Database schema
- [API Specification](API_SPEC.md) - REST + WebSocket API details
- [SDK Guide](SDK_GUIDE.md) - JavaScript SDK documentation
- [Self-Hosting Guide](SELF_HOSTING.md) - On-premise deployment

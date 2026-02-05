# SyncForge - Claude Code Instructions

## Project Overview

SyncForge is a **Real-Time Collaboration Infrastructure** platform for developers. It provides the building blocks for adding multiplayer experiences to any application—presence indicators, live cursors, comments, notifications, and voice rooms.

**Think**: Liveblocks, Cord, or Velt—but with self-hosting options, framework-agnostic design, and native LiveView support built on the BEAM's legendary concurrency.

**Tech Stack**:
- **Language**: Elixir
- **Web Framework**: Phoenix 1.7+
- **Real-time**: Phoenix Channels + Presence
- **CRDT Sync**: Yjs integration
- **Database**: PostgreSQL (via Ecto)
- **Background Jobs**: Oban
- **Styling**: TailwindCSS
- **Deployment**: Fly.io (global edge)

---

## Product Vision

### What We're Building

A full-stack collaboration infrastructure that lets developers add real-time features in minutes:

1. **Presence** - Show who's online, what they're viewing, what they're doing
2. **Cursors** - Live cursor positions for multiplayer editing
3. **Comments** - Threaded discussions anchored to any element
4. **Notifications** - Real-time alerts and activity feeds
5. **Voice Rooms** - Spatial audio for collaboration
6. **Screen Recording** - Async video messages

### Key Differentiators

| Feature | Liveblocks | Cord | Velt | **SyncForge** |
|---------|------------|------|------|---------------|
| Self-hosting | ❌ | ❌ | ❌ | ✅ |
| Framework-agnostic | ❌ (React-heavy) | ❌ | Partial | ✅ |
| Native LiveView | ❌ | ❌ | ❌ | ✅ |
| Pre-built UI | ✅ | ✅ | ✅ | ✅ |
| Predictable pricing | ❌ | ❌ | ❌ | ✅ |

### Target Market

- **Primary**: Elixir/Phoenix developers (underserved, no native solution)
- **Secondary**: Teams wanting self-hosted collaboration infrastructure
- **Tertiary**: Startups needing predictable pricing at scale

---

## Project Structure

```
syncforge/
├── lib/
│   ├── syncforge/                 # Core business domain
│   │   ├── accounts/              # User, Organization, Membership
│   │   ├── rooms/                 # Room management and state
│   │   ├── presence/              # Presence tracking and broadcasting
│   │   ├── documents/             # CRDT document sync (Yjs)
│   │   ├── comments/              # Threaded comments system
│   │   ├── cursors/               # Live cursor tracking
│   │   ├── notifications/         # Real-time notifications
│   │   ├── voice/                 # Voice room infrastructure
│   │   └── application.ex         # Application supervisor
│   ├── syncforge_web/             # Web layer
│   │   ├── channels/              # Phoenix Channels (core real-time)
│   │   ├── components/            # Phoenix components + pre-built UI
│   │   ├── live/                  # LiveView modules
│   │   ├── controllers/           # API controllers (REST + SDK)
│   │   ├── router.ex              # Routes
│   │   └── endpoint.ex            # HTTP/WebSocket endpoint
│   └── syncforge.ex               # Main module
├── priv/
│   ├── repo/
│   │   ├── migrations/            # Ecto migrations
│   │   └── seeds.exs              # Seed data
│   └── static/                    # Static assets + JS SDK
├── assets/
│   ├── js/
│   │   ├── sdk/                   # JavaScript SDK source
│   │   ├── hooks/                 # LiveView hooks
│   │   └── yjs/                   # Yjs CRDT integration
│   └── css/                       # TailwindCSS
├── test/
│   ├── syncforge/                 # Domain tests
│   ├── syncforge_web/             # Web layer tests
│   └── support/                   # Test helpers
├── config/                        # Configuration files
├── docs/                          # Project documentation
└── prompts/                       # AI development prompts
```

---

## Development Standards

### Code Style

**Elixir Conventions**:
- Use `snake_case` for functions, variables, and atoms
- Use `PascalCase` for module names
- Prefer pattern matching over conditionals
- Use pipe operator `|>` for data transformations
- Keep functions small (< 15 lines)

**Naming**:
- Modules: `PascalCase` (SyncForge.Rooms.Room)
- Functions: `snake_case` (join_room, track_cursor)
- Atoms: `snake_case` (:room_state, :cursor_position)
- Files: `snake_case.ex` (room.ex, presence_tracker.ex)

**Module Organization**:
```elixir
defmodule SyncForge.Rooms.Room do
  @moduledoc """
  Represents a collaboration room where users interact in real-time.
  """

  # 1. Use statements
  use Ecto.Schema

  # 2. Aliases (alphabetized)
  alias SyncForge.Accounts.Organization
  alias SyncForge.Presence.UserPresence

  # 3. Imports
  import Ecto.Changeset

  # 4. Requires
  require Logger

  # 5. Module attributes
  @max_participants 100

  # 6. Schema/struct definition
  schema "rooms" do
    # ...
  end

  # 7. Public functions
  def create(attrs) do
    # ...
  end

  # 8. Private functions
  defp validate_capacity(changeset) do
    # ...
  end
end
```

### Testing Requirements

- **Write tests BEFORE implementation** (TDD)
- Minimum 80% coverage for new code
- 100% coverage for real-time sync and presence logic
- Use factories for test data via `ExMachina`

```bash
# Run tests
mix test                          # All tests
mix test test/syncforge/rooms     # Specific directory
mix test --cover                  # With coverage
mix test --stale                  # Only changed
```

### Git Workflow

1. Create feature branch: `feature/<ticket>-<description>`
2. Write failing tests
3. Implement feature
4. All tests pass
5. Create PR with description
6. Merge after review

**Commit Format**:
```
<type>(<scope>): <description>

Types: feat, fix, test, refactor, docs, chore
Scope: presence, rooms, cursors, comments, voice, sdk
```

---

## Key Patterns

### Phoenix Channel Pattern (Core Real-Time)

```elixir
# lib/syncforge_web/channels/room_channel.ex
defmodule SyncForgeWeb.RoomChannel do
  use SyncForgeWeb, :channel

  alias SyncForge.Rooms
  alias SyncForge.Presence.Tracker

  @impl true
  def join("room:" <> room_id, params, socket) do
    case Rooms.authorize_join(room_id, socket.assigns.current_user) do
      {:ok, room} ->
        send(self(), :after_join)
        {:ok, assign(socket, :room, room)}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    # Track presence
    {:ok, _} = Tracker.track(socket, socket.assigns.current_user.id, %{
      online_at: System.system_time(:second),
      user: socket.assigns.current_user
    })

    # Push current presence state
    push(socket, "presence_state", Tracker.list(socket))

    # Push current room state (cursors, selections, etc.)
    push(socket, "room_state", Rooms.get_state(socket.assigns.room.id))

    {:noreply, socket}
  end

  @impl true
  def handle_in("cursor:update", %{"x" => x, "y" => y}, socket) do
    broadcast_from(socket, "cursor:update", %{
      user_id: socket.assigns.current_user.id,
      x: x,
      y: y
    })
    {:noreply, socket}
  end

  @impl true
  def handle_in("doc:update", %{"update" => update}, socket) do
    # Yjs CRDT update - broadcast to all other clients
    broadcast_from(socket, "doc:update", %{update: update})

    # Persist to database (debounced)
    Rooms.apply_document_update(socket.assigns.room.id, update)

    {:noreply, socket}
  end
end
```

### Presence Tracking Pattern

```elixir
# lib/syncforge/presence/tracker.ex
defmodule SyncForge.Presence.Tracker do
  @moduledoc """
  Tracks user presence across rooms using Phoenix Presence.
  """

  use Phoenix.Presence,
    otp_app: :syncforge,
    pubsub_server: SyncForge.PubSub

  alias SyncForge.Rooms

  @doc """
  Track a user's presence in a room with metadata.
  """
  def track_user(socket, user, metadata \\ %{}) do
    track(socket, user.id, Map.merge(%{
      user_id: user.id,
      name: user.name,
      avatar_url: user.avatar_url,
      joined_at: DateTime.utc_now()
    }, metadata))
  end

  @doc """
  Update user's presence metadata (e.g., cursor position, status).
  """
  def update_user(socket, user_id, metadata) do
    update(socket, user_id, fn existing ->
      Map.merge(existing, metadata)
    end)
  end

  @doc """
  Get all users present in a room.
  """
  def list_room_users(room_id) do
    list("room:#{room_id}")
    |> Enum.map(fn {_user_id, %{metas: [meta | _]}} -> meta end)
  end
end
```

### CRDT Document Sync Pattern (Yjs Integration)

```elixir
# lib/syncforge/documents/document.ex
defmodule SyncForge.Documents.Document do
  @moduledoc """
  Handles CRDT document synchronization using Yjs.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias SyncForge.Rooms.Room

  schema "documents" do
    field :name, :string
    field :state, :binary  # Yjs encoded state
    field :version, :integer, default: 0

    belongs_to :room, Room

    timestamps()
  end

  @doc """
  Apply a Yjs update to the document state.
  """
  def apply_update(document, update_binary) do
    # Merge Yjs update with existing state
    new_state = YjsNif.merge_update(document.state, update_binary)

    document
    |> change(%{state: new_state, version: document.version + 1})
    |> Repo.update()
  end

  @doc """
  Get the current document state for a new client.
  """
  def get_sync_state(document) do
    %{
      state: document.state,
      version: document.version
    }
  end
end
```

### Comments System Pattern

```elixir
# lib/syncforge/comments/comment.ex
defmodule SyncForge.Comments.Comment do
  @moduledoc """
  Threaded comments that can be anchored to any element.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :body, :string
    field :anchor_id, :string      # Element ID this comment is attached to
    field :anchor_type, :string    # Type of anchor (element, selection, point)
    field :position, :map          # {x, y} or selection range
    field :resolved_at, :utc_datetime

    belongs_to :room, SyncForge.Rooms.Room
    belongs_to :user, SyncForge.Accounts.User
    belongs_to :parent, __MODULE__  # For threading
    has_many :replies, __MODULE__, foreign_key: :parent_id

    timestamps()
  end

  def create_changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :anchor_id, :anchor_type, :position, :room_id, :user_id, :parent_id])
    |> validate_required([:body, :room_id, :user_id])
    |> foreign_key_constraint(:room_id)
    |> foreign_key_constraint(:user_id)
  end
end
```

### LiveView Integration Pattern

```elixir
# lib/syncforge_web/live/collaborative_editor_live.ex
defmodule SyncForgeWeb.CollaborativeEditorLive do
  use SyncForgeWeb, :live_view

  alias SyncForge.Rooms
  alias SyncForge.Documents

  @impl true
  def mount(%{"room_id" => room_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to room updates
      Phoenix.PubSub.subscribe(SyncForge.PubSub, "room:#{room_id}")
    end

    room = Rooms.get_room!(room_id)
    document = Documents.get_document!(room.document_id)

    {:ok,
     socket
     |> assign(:room, room)
     |> assign(:document, document)
     |> assign(:presence, [])
     |> push_event("sync:init", %{state: document.state})}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    presence = SyncForge.Presence.Tracker.list("room:#{socket.assigns.room.id}")
    {:noreply, assign(socket, :presence, presence)}
  end

  @impl true
  def handle_event("cursor:move", %{"x" => x, "y" => y}, socket) do
    # Broadcast cursor position to other users
    Phoenix.PubSub.broadcast(
      SyncForge.PubSub,
      "room:#{socket.assigns.room.id}",
      {:cursor_update, socket.assigns.current_user.id, x, y}
    )
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="collaborative-editor" phx-hook="CollaborativeEditor">
      <!-- Presence indicators -->
      <.presence_avatars users={@presence} />

      <!-- Live cursors layer -->
      <.cursor_layer cursors={@cursors} />

      <!-- Editor content -->
      <div id="editor-content" phx-update="ignore">
        <!-- Yjs-managed content -->
      </div>

      <!-- Comments panel -->
      <.comments_panel room_id={@room.id} />
    </div>
    """
  end
end
```

---

## JavaScript SDK Architecture

```javascript
// assets/js/sdk/syncforge.js
import { Socket, Presence } from "phoenix";
import * as Y from "yjs";

export class SyncForge {
  constructor(config) {
    this.apiKey = config.apiKey;
    this.endpoint = config.endpoint || "wss://api.syncforge.io/socket";
    this.socket = null;
    this.rooms = new Map();
  }

  connect() {
    this.socket = new Socket(this.endpoint, {
      params: { api_key: this.apiKey }
    });
    this.socket.connect();
    return this;
  }

  joinRoom(roomId, options = {}) {
    const channel = this.socket.channel(`room:${roomId}`, options);
    const room = new Room(channel, options);

    channel.join()
      .receive("ok", (resp) => room.emit("connected", resp))
      .receive("error", (resp) => room.emit("error", resp));

    this.rooms.set(roomId, room);
    return room;
  }
}

class Room extends EventEmitter {
  constructor(channel, options) {
    super();
    this.channel = channel;
    this.presence = new Presence(channel);
    this.doc = new Y.Doc();
    this.cursors = new Map();

    this.setupPresence();
    this.setupDocSync();
    this.setupCursors();
  }

  setupPresence() {
    this.presence.onSync(() => {
      const users = this.presence.list((id, { metas }) => metas[0]);
      this.emit("presence", users);
    });
  }

  setupDocSync() {
    // Yjs awareness for cursors/selections
    this.awareness = new awarenessProtocol.Awareness(this.doc);

    this.channel.on("doc:update", ({ update }) => {
      Y.applyUpdate(this.doc, new Uint8Array(update));
    });

    this.doc.on("update", (update) => {
      this.channel.push("doc:update", { update: Array.from(update) });
    });
  }

  updateCursor(position) {
    this.channel.push("cursor:update", position);
  }

  addComment(comment) {
    return new Promise((resolve, reject) => {
      this.channel.push("comment:create", comment)
        .receive("ok", resolve)
        .receive("error", reject);
    });
  }
}
```

---

## Common Commands

```bash
# Development
mix phx.server        # Start development server
iex -S mix phx.server # Start with IEx shell
mix compile           # Compile the project

# Database
mix ecto.create       # Create database
mix ecto.migrate      # Run migrations
mix ecto.rollback     # Rollback last migration
mix ecto.reset        # Drop, create, migrate, seed

# Testing
mix test              # Run all tests
mix test --cover      # With coverage report
mix test --stale      # Only changed tests
mix test.watch        # Watch mode (with mix_test_watch)

# Code Quality
mix format            # Format code
mix credo             # Static analysis
mix dialyzer          # Type checking

# SDK Development
cd assets && npm run build:sdk   # Build JavaScript SDK
cd assets && npm run test:sdk    # Test JavaScript SDK
```

---

## Environment Variables

```env
# Database
DATABASE_URL="ecto://user:pass@localhost:5432/syncforge_dev"

# Phoenix
SECRET_KEY_BASE="min-64-character-secret-for-phoenix"
PHX_HOST="localhost"
PORT=4000

# Real-time Configuration
PRESENCE_TTL=30000              # Presence timeout in ms
MAX_ROOM_PARTICIPANTS=100       # Max users per room
DOCUMENT_PERSIST_INTERVAL=5000  # CRDT persist debounce

# API Keys
API_KEY_SALT="your-salt-for-api-key-generation"

# External Services (Production)
FLY_APP_NAME="syncforge"
FLY_REGION="iad"

# Stripe (Billing)
STRIPE_SECRET_KEY="sk_test_..."
STRIPE_WEBHOOK_SECRET="whsec_..."
STRIPE_PRICE_STARTER="price_..."
STRIPE_PRICE_PRO="price_..."
STRIPE_PRICE_BUSINESS="price_..."
```

---

## Key Documentation

| Document | Path | Purpose |
|----------|------|---------  |
| PRD | `docs/PRD.md` | Product requirements |
| Specs | `docs/SPECS.md` | Technical specifications |
| Data Model | `docs/DATA_MODEL.md` | Database schema |
| API Spec | `docs/API_SPEC.md` | REST + WebSocket API |
| SDK Guide | `docs/SDK_GUIDE.md` | JavaScript SDK docs |
| Self-Hosting | `docs/SELF_HOSTING.md` | Self-deployment guide |

---

## AI Development Prompts

Use these prompts from `prompts/` for common tasks:

- `scaffold.md` - Create new channels, presence features, or components
- `implement.md` - Implement specific functionality
- `test.md` - Generate tests for existing code
- `debug.md` - Diagnose and fix real-time issues
- `refactor.md` - Improve code quality
- `review.md` - Review code for issues

---

## Definition of Done

Before marking any task complete:

- [ ] Code compiles without warnings (`mix compile --warnings-as-errors`)
- [ ] All tests pass (`mix test`)
- [ ] New code has tests (80%+ coverage)
- [ ] Code passes linting (`mix credo --strict`)
- [ ] Code is formatted (`mix format --check-formatted`)
- [ ] Real-time features tested with multiple clients
- [ ] WebSocket reconnection handled gracefully
- [ ] Database changes have migrations
- [ ] No IO.inspect or debug statements
- [ ] Error handling is appropriate
- [ ] SDK changes documented and tested

---

## Quick Reference

### Core Entities

| Entity | Key Fields | Purpose |
|--------|------------|---------  |
| User | email, api_key | Authentication |
| Organization | name, plan_type | Multi-tenancy |
| Room | name, type, config | Collaboration space |
| Document | state (binary), version | CRDT sync state |
| Comment | body, anchor_id, position | Threaded discussions |
| Notification | type, payload, read_at | Activity alerts |

### Channel Events

| Event | Direction | Purpose |
|-------|-----------|---------|
| `presence_state` | Server → Client | Initial presence |
| `presence_diff` | Server → Client | Presence changes |
| `cursor:update` | Bidirectional | Cursor positions |
| `doc:update` | Bidirectional | CRDT updates |
| `comment:create` | Client → Server | New comment |
| `comment:resolve` | Client → Server | Resolve thread |

### Pricing Tiers

| Plan | Price | MAU | Rooms | Features |
|------|-------|-----|-------|----------|
| Starter | $49/mo | 1,000 | 10 | Presence, Cursors |
| Pro | $199/mo | 10,000 | 100 | + Comments, Notifications |
| Business | $499/mo | 50,000 | Unlimited | + Voice, Analytics |
| Enterprise | $999+/mo | Custom | Custom | + Self-hosting, SLA |


<claude-mem-context>
# Recent Activity

<!-- This section is auto-generated by claude-mem. Edit content outside the tags. -->

*No recent activity*
</claude-mem-context>
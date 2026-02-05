# Implement Prompt - SyncForge

Use this prompt when implementing specific functionality, features, or user stories.

---

## Context

I'm working on SyncForge, a **Real-Time Collaboration Infrastructure** platform.

**Tech Stack**:
- Elixir
- Phoenix 1.7+ (with Channels and Presence)
- PostgreSQL (via Ecto)
- Oban for background jobs
- Yjs for CRDT document sync

**Relevant Documentation**:
- `docs/PRD.md` - Product requirements
- `docs/SPECS.md` - Technical specifications
- `docs/DATA_MODEL.md` - Database schema
- `docs/API_SPEC.md` - API endpoints

---

## Implementation Request

### User Story / Task:
[Paste the user story or describe the feature]

### Acceptance Criteria:
[List the acceptance criteria that define "done"]

### Existing Code:
[Reference any existing files that will be modified or extended]

### Dependencies:
[List any external APIs, packages, or services needed]

---

## TDD Approach

Follow Test-Driven Development:

1. **Red**: Write failing tests first
2. **Green**: Write minimum code to pass
3. **Refactor**: Clean up while tests stay green

### Test Structure

```elixir
defmodule SyncForge.Presence.TrackerTest do
  use SyncForge.DataCase, async: true

  alias SyncForge.Presence.Tracker

  import SyncForge.Factory

  describe "track_user/3" do
    test "tracks user presence in room with metadata" do
      user = insert(:user)
      room = insert(:room)

      {:ok, socket} = connect_socket(user, room)

      assert {:ok, _ref} = Tracker.track_user(socket, user, %{status: "active"})
      assert [presence] = Tracker.list_room_users(room.id)
      assert presence.user_id == user.id
      assert presence.status == "active"
    end

    test "allows multiple devices for same user" do
      user = insert(:user)
      room = insert(:room)

      {:ok, socket1} = connect_socket(user, room)
      {:ok, socket2} = connect_socket(user, room)

      Tracker.track_user(socket1, user, %{device: "desktop"})
      Tracker.track_user(socket2, user, %{device: "mobile"})

      presences = Tracker.list_room_users(room.id)
      assert length(presences) == 1  # Deduplicated by user
    end
  end
end
```

---

## Example Implementations

### Example 1: Implement Cursor Broadcasting

**User Story**:
```
As a user in a collaboration room, I want to see other users' cursor
positions in real-time so I can follow their activity.
```

**Acceptance Criteria**:
- Cursor position updates broadcast within 30ms
- Show cursor with user's name and color
- Hide cursor after 5 seconds of inactivity
- Support 100+ concurrent cursors

**Implementation Approach**:
1. Add cursor:update handler to RoomChannel
2. Create CursorTracker for presence metadata
3. Implement throttling on client side
4. Add cursor rendering component

**Files to Create/Modify**:
- `lib/syncforge_web/channels/room_channel.ex` (modify)
- `lib/syncforge/presence/cursor_tracker.ex` (create)
- `assets/js/hooks/cursor_hook.js` (create)
- `lib/syncforge_web/components/cursor_components.ex` (create)
- `test/syncforge/presence/cursor_tracker_test.exs` (create)

**Implementation**:

```elixir
# lib/syncforge_web/channels/room_channel.ex
defmodule SyncForgeWeb.RoomChannel do
  use SyncForgeWeb, :channel

  alias SyncForge.Rooms
  alias SyncForge.Presence.CursorTracker

  @impl true
  def join("room:" <> room_id, _params, socket) do
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
    user = socket.assigns.current_user

    # Track cursor presence
    {:ok, _} = CursorTracker.track_cursor(socket, user)

    # Push current cursors to joining user
    push(socket, "presence_state", CursorTracker.list(socket))

    {:noreply, socket}
  end

  @impl true
  def handle_in("cursor:update", %{"x" => x, "y" => y}, socket) do
    user_id = socket.assigns.current_user.id

    # Update cursor position in presence
    CursorTracker.update_position(socket, user_id, x, y)

    # Broadcast to others (presence_diff handles this automatically)
    broadcast_from!(socket, "cursor:move", %{
      user_id: user_id,
      x: x,
      y: y
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("cursor:selection", %{"selection" => selection}, socket) do
    user_id = socket.assigns.current_user.id

    CursorTracker.update_selection(socket, user_id, selection)

    broadcast_from!(socket, "cursor:selection", %{
      user_id: user_id,
      selection: selection
    })

    {:noreply, socket}
  end
end
```

```elixir
# lib/syncforge/presence/cursor_tracker.ex
defmodule SyncForge.Presence.CursorTracker do
  @moduledoc """
  Tracks cursor positions for users in collaboration rooms.
  """

  use Phoenix.Presence,
    otp_app: :syncforge,
    pubsub_server: SyncForge.PubSub

  @colors ~w(#FF6B6B #4ECDC4 #45B7D1 #96CEB4 #FFEAA7 #DDA0DD #98D8C8 #F7DC6F)

  @spec track_cursor(Phoenix.Socket.t(), map(), map()) :: {:ok, binary()} | {:error, term()}
  def track_cursor(socket, user, initial \\ %{}) do
    track(socket, user.id, %{
      user_id: user.id,
      name: user.name,
      color: assign_color(user.id),
      x: Map.get(initial, :x, 0),
      y: Map.get(initial, :y, 0),
      selection: nil,
      last_active: now()
    })
  end

  @spec update_position(Phoenix.Socket.t(), String.t(), number(), number()) :: {:ok, map()}
  def update_position(socket, user_id, x, y) do
    update(socket, user_id, fn meta ->
      %{meta | x: x, y: y, last_active: now()}
    end)
  end

  @spec update_selection(Phoenix.Socket.t(), String.t(), map() | nil) :: {:ok, map()}
  def update_selection(socket, user_id, selection) do
    update(socket, user_id, fn meta ->
      %{meta | selection: selection, last_active: now()}
    end)
  end

  @spec list_active_cursors(String.t(), integer()) :: [map()]
  def list_active_cursors(topic, timeout_ms \\ 5_000) do
    cutoff = now() - timeout_ms

    list(topic)
    |> Enum.flat_map(fn {_id, %{metas: metas}} -> metas end)
    |> Enum.filter(fn meta -> meta.last_active > cutoff end)
  end

  defp assign_color(user_id) do
    Enum.at(@colors, :erlang.phash2(user_id, length(@colors)))
  end

  defp now, do: System.system_time(:millisecond)
end
```

### Example 2: Implement Comment Threading

**User Story**:
```
As a user, I want to reply to comments so I can have threaded discussions
about specific parts of the document.
```

**Acceptance Criteria**:
- Reply to any top-level comment
- Show replies nested under parent
- Real-time updates when replies added
- Resolve entire thread at once

**Implementation Approach**:
1. Add parent_id to comments schema
2. Create reply action in Comments context
3. Broadcast reply events via PubSub
4. Update comment components for threading

**Files to Create/Modify**:
- `lib/syncforge/comments/comment.ex` (modify)
- `lib/syncforge/comments.ex` (modify)
- `lib/syncforge_web/channels/room_channel.ex` (modify)
- `lib/syncforge_web/components/comment_components.ex` (modify)
- `test/syncforge/comments_test.exs` (modify)

**Implementation**:

```elixir
# lib/syncforge/comments.ex
defmodule SyncForge.Comments do
  @moduledoc """
  The Comments context for threaded discussions.
  """

  alias SyncForge.Repo
  alias SyncForge.Comments.Comment

  import Ecto.Query

  @doc """
  Creates a new comment or reply.
  """
  @spec create(map(), map(), map()) :: {:ok, Comment.t()} | {:error, Ecto.Changeset.t()}
  def create(user, room, attrs) do
    %Comment{}
    |> Comment.create_changeset(Map.merge(attrs, %{
      user_id: user.id,
      room_id: room.id
    }))
    |> Repo.insert()
    |> case do
      {:ok, comment} ->
        comment = Repo.preload(comment, [:user, :replies])
        broadcast_comment_added(room.id, comment)
        {:ok, comment}

      error ->
        error
    end
  end

  @doc """
  Creates a reply to an existing comment.
  """
  @spec reply(Comment.t(), map(), map()) :: {:ok, Comment.t()} | {:error, Ecto.Changeset.t()}
  def reply(parent_comment, user, attrs) do
    %Comment{}
    |> Comment.create_changeset(Map.merge(attrs, %{
      user_id: user.id,
      room_id: parent_comment.room_id,
      parent_id: parent_comment.id,
      anchor_id: parent_comment.anchor_id,
      anchor_type: parent_comment.anchor_type
    }))
    |> Repo.insert()
    |> case do
      {:ok, reply} ->
        reply = Repo.preload(reply, :user)
        broadcast_reply_added(parent_comment.room_id, parent_comment.id, reply)
        {:ok, reply}

      error ->
        error
    end
  end

  @doc """
  Resolves a comment thread (parent and all replies).
  """
  @spec resolve(String.t(), String.t()) :: {:ok, Comment.t()} | {:error, term()}
  def resolve(comment_id, resolved_by_id) do
    Repo.transaction(fn ->
      comment = Repo.get!(Comment, comment_id)

      # Resolve parent
      {:ok, resolved} =
        comment
        |> Comment.resolve_changeset(resolved_by_id)
        |> Repo.update()

      # Resolve all replies
      from(c in Comment, where: c.parent_id == ^comment_id)
      |> Repo.update_all(set: [
        resolved_at: DateTime.utc_now(),
        resolved_by_id: resolved_by_id
      ])

      broadcast_comment_resolved(comment.room_id, comment_id)

      resolved
    end)
  end

  @doc """
  Lists all comments for a room with replies.
  """
  @spec list_for_room(String.t()) :: [Comment.t()]
  def list_for_room(room_id) do
    Comment.for_room(room_id)
    |> Repo.all()
  end

  # Broadcasting helpers

  defp broadcast_comment_added(room_id, comment) do
    Phoenix.PubSub.broadcast(
      SyncForge.PubSub,
      "room:#{room_id}:comments",
      {:comment_added, comment}
    )
  end

  defp broadcast_reply_added(room_id, parent_id, reply) do
    Phoenix.PubSub.broadcast(
      SyncForge.PubSub,
      "room:#{room_id}:comments",
      {:reply_added, parent_id, reply}
    )
  end

  defp broadcast_comment_resolved(room_id, comment_id) do
    Phoenix.PubSub.broadcast(
      SyncForge.PubSub,
      "room:#{room_id}:comments",
      {:comment_resolved, comment_id}
    )
  end
end
```

### Example 3: Implement Document Sync

**User Story**:
```
As a user, I want my document changes to sync in real-time with other
users so we can collaborate without conflicts.
```

**Acceptance Criteria**:
- Changes sync within 100ms
- No conflicts with concurrent edits (CRDT)
- Document state persists to database
- New users get full document state on join

**Implementation Approach**:
1. Integrate Yjs NIF for CRDT operations
2. Handle doc:update events in channel
3. Persist document state (debounced)
4. Send initial state on join

**Implementation**:

```elixir
# lib/syncforge/documents/sync.ex
defmodule SyncForge.Documents.Sync do
  @moduledoc """
  Handles CRDT document synchronization using Yjs.
  """

  alias SyncForge.Repo
  alias SyncForge.Documents.Document

  require Logger

  @doc """
  Apply a Yjs update to a document.
  """
  @spec apply_update(String.t(), binary()) :: {:ok, Document.t()} | {:error, term()}
  def apply_update(document_id, update_binary) do
    document = Repo.get!(Document, document_id)

    case merge_yjs_update(document.state, update_binary) do
      {:ok, new_state} ->
        document
        |> Ecto.Changeset.change(%{
          state: new_state,
          version: document.version + 1,
          updated_at: DateTime.utc_now()
        })
        |> Repo.update()

      {:error, reason} ->
        Logger.error("Failed to apply Yjs update",
          document_id: document_id,
          reason: reason
        )
        {:error, reason}
    end
  end

  @doc """
  Get the sync state for a client joining.
  """
  @spec get_sync_state(String.t()) :: {:ok, map()} | {:error, :not_found}
  def get_sync_state(document_id) do
    case Repo.get(Document, document_id) do
      nil ->
        {:error, :not_found}

      document ->
        {:ok, %{
          state: Base.encode64(document.state || <<>>),
          version: document.version
        }}
    end
  end

  @doc """
  Create a snapshot of the document for recovery.
  """
  @spec create_snapshot(String.t()) :: {:ok, map()} | {:error, term()}
  def create_snapshot(document_id) do
    document = Repo.get!(Document, document_id)

    snapshot = %{
      document_id: document_id,
      state: document.state,
      version: document.version,
      created_at: DateTime.utc_now()
    }

    # Store snapshot (implementation depends on storage strategy)
    {:ok, snapshot}
  end

  # Yjs NIF integration (or Rustler binding)
  defp merge_yjs_update(existing_state, update) do
    # This would call into Yjs via NIF or Rustler
    # For now, simple concatenation as placeholder
    try do
      existing = existing_state || <<>>
      {:ok, existing <> update}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end
end
```

```elixir
# lib/syncforge_web/channels/room_channel.ex - doc sync handlers
@impl true
def handle_in("doc:update", %{"update" => update_base64}, socket) do
  update_binary = Base.decode64!(update_base64)
  document_id = socket.assigns.room.document_id

  # Broadcast to all other clients immediately
  broadcast_from!(socket, "doc:update", %{
    update: update_base64,
    user_id: socket.assigns.current_user.id
  })

  # Persist asynchronously (debounced)
  SyncForge.Documents.Sync.schedule_persist(document_id, update_binary)

  {:noreply, socket}
end

@impl true
def handle_in("doc:sync_request", _params, socket) do
  document_id = socket.assigns.room.document_id

  case SyncForge.Documents.Sync.get_sync_state(document_id) do
    {:ok, state} ->
      {:reply, {:ok, state}, socket}

    {:error, _} ->
      {:reply, {:error, %{reason: "Document not found"}}, socket}
  end
end
```

---

## Implementation Checklist

During implementation:

- [ ] Write tests FIRST (TDD)
- [ ] Handle all error cases
- [ ] Add proper typespecs (@spec)
- [ ] Implement real-time broadcasts
- [ ] Handle reconnection scenarios
- [ ] Add telemetry events
- [ ] Update API docs if needed
- [ ] Add database migrations if needed

After implementation:

- [ ] All tests pass (`mix test`)
- [ ] No compile warnings (`mix compile --warnings-as-errors`)
- [ ] Credo passes (`mix credo --strict`)
- [ ] Manual testing with multiple clients
- [ ] Performance acceptable (check latency)

---

## Common Patterns

### Channel Event Handler

```elixir
@impl true
def handle_in("event:name", payload, socket) do
  # 1. Validate payload
  with {:ok, validated} <- validate_payload(payload),
       # 2. Authorize action
       :ok <- authorize_action(socket.assigns.current_user, validated),
       # 3. Execute business logic
       {:ok, result} <- execute_action(validated) do

    # 4. Broadcast to others
    broadcast_from!(socket, "event:result", result)

    # 5. Reply to sender
    {:reply, {:ok, result}, socket}
  else
    {:error, :unauthorized} ->
      {:reply, {:error, %{reason: "unauthorized"}}, socket}

    {:error, reason} ->
      {:reply, {:error, %{reason: reason}}, socket}
  end
end
```

### Presence Update Pattern

```elixir
def update_user_state(socket, user_id, updates) do
  Tracker.update(socket, user_id, fn existing ->
    existing
    |> Map.merge(updates)
    |> Map.put(:last_active, System.system_time(:millisecond))
  end)
end
```

### PubSub Broadcast Pattern

```elixir
defp broadcast_event(room_id, event, payload) do
  Phoenix.PubSub.broadcast(
    SyncForge.PubSub,
    "room:#{room_id}",
    {event, payload}
  )
end
```

---

## Output Format

When implementing, provide:

1. **Test file(s)** - Full test code with ExUnit
2. **Implementation file(s)** - Full implementation code
3. **Type specifications** - @spec for public functions
4. **Migration** - If database changes needed
5. **API documentation** - Updates to API_SPEC.md
6. **Verification steps** - How to manually test with multiple clients

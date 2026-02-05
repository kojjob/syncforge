# Refactor Prompt - SyncForge

Use this prompt when improving code quality, restructuring, or eliminating technical debt.

---

## Context

I'm working on SyncForge, a **Real-Time Collaboration Infrastructure** platform.

**Tech Stack**:
- Elixir
- Phoenix 1.7+ (with Channels and Presence)
- PostgreSQL (via Ecto)
- Oban for background jobs
- Yjs for CRDT document sync

**Quality Standards**:
- Maximum cyclomatic complexity: 10
- Maximum function length: 15 lines
- Maximum module length: 200 lines
- DRY: No duplication
- SOLID: All principles applied
- Real-time: <50ms for presence, <100ms for document sync

---

## Refactoring Request

### Code to refactor:
[Paste the code or reference the file path]

### Why refactor:
- [ ] Code smell detected
- [ ] Performance issue
- [ ] Readability improvement
- [ ] Testability improvement
- [ ] Removing duplication
- [ ] Applying design pattern
- [ ] Preparing for new feature

### Constraints:
[Any constraints on the refactoring - backwards compatibility, etc.]

---

## Refactoring Principles

### 1. Ensure Test Coverage

Before refactoring:
```bash
mix test --cover
# Verify the code you're changing has tests
```

If no tests exist, write them first:
```elixir
# Document current behavior before changing it
defmodule SyncForge.CurrentImplementationTest do
  use SyncForge.DataCase

  describe "current behavior" do
    test "behaves this way currently" do
      # Capture existing behavior
    end
  end
end
```

### 2. Make Small, Incremental Changes

Each commit should:
- Pass all tests
- Be independently deployable
- Not mix multiple refactorings

### 3. Keep Behavior Identical

Refactoring = changing structure without changing behavior.

```elixir
# Before
def process_presence(presence_list) do
  result = []
  for presence <- presence_list do
    if presence.online do
      result = result ++ [%{id: presence.user_id, name: presence.name}]
    end
  end
  result
end

# After (same behavior, cleaner code)
def process_presence(presence_list) do
  presence_list
  |> Enum.filter(& &1.online)
  |> Enum.map(&%{id: &1.user_id, name: &1.name})
end
```

---

## Common Refactorings

### Extract Function

```elixir
# Before: Long function doing multiple things
def join_room(socket, room_id, user) do
  # Validation (10 lines)
  if is_nil(user) do
    {:error, :unauthorized}
  else
    if String.length(room_id) != 36 do
      {:error, :invalid_room_id}
    else
      # Authorization (5 lines)
      room = Rooms.get_room!(room_id)
      membership = Memberships.get_membership(user.organization_id, room.organization_id)

      if is_nil(membership) do
        {:error, :forbidden}
      else
        # Join logic (10 lines)
        Tracker.track_user(socket, user)
        broadcast_join(socket, user)
        {:ok, socket}
      end
    end
  end
end

# After: Extracted functions with early returns
def join_room(socket, room_id, user) do
  with :ok <- validate_user(user),
       :ok <- validate_room_id(room_id),
       {:ok, room} <- get_room(room_id),
       :ok <- authorize_join(user, room) do
    complete_join(socket, user)
  end
end

defp validate_user(nil), do: {:error, :unauthorized}
defp validate_user(_user), do: :ok

defp validate_room_id(room_id) when byte_size(room_id) == 36, do: :ok
defp validate_room_id(_), do: {:error, :invalid_room_id}

defp get_room(room_id) do
  case Rooms.get_room(room_id) do
    nil -> {:error, :not_found}
    room -> {:ok, room}
  end
end

defp authorize_join(user, room) do
  if Memberships.has_access?(user, room), do: :ok, else: {:error, :forbidden}
end

defp complete_join(socket, user) do
  Tracker.track_user(socket, user)
  broadcast_join(socket, user)
  {:ok, socket}
end
```

### Extract Module

```elixir
# Before: Large channel with many concerns
defmodule SyncForgeWeb.RoomChannel do
  # Presence logic (50 lines)
  def track_presence(socket, user) do
    # ...
  end

  def update_presence(socket, user_id, meta) do
    # ...
  end

  def list_presence(topic) do
    # ...
  end

  # Cursor logic (50 lines)
  def track_cursor(socket, user) do
    # ...
  end

  def update_cursor(socket, user_id, x, y) do
    # ...
  end

  # Comment logic (50 lines)
  def add_comment(socket, attrs) do
    # ...
  end

  # ... more
end

# After: Extracted into focused modules
defmodule SyncForgeWeb.RoomChannel do
  alias SyncForge.Presence.Tracker
  alias SyncForge.Cursors.CursorManager
  alias SyncForge.Comments

  @impl true
  def handle_in("cursor:update", payload, socket) do
    CursorManager.update(socket, payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("comment:add", payload, socket) do
    Comments.create(socket.assigns.user, socket.assigns.room, payload)
    {:noreply, socket}
  end
end

# lib/syncforge/presence/tracker.ex
defmodule SyncForge.Presence.Tracker do
  # All presence logic here
end

# lib/syncforge/cursors/cursor_manager.ex
defmodule SyncForge.Cursors.CursorManager do
  # All cursor logic here
end
```

### Replace Conditional with Pattern Matching

```elixir
# Before: Nested conditionals
def handle_event(event_type, payload, socket) do
  if event_type == "cursor:update" do
    update_cursor(socket, payload)
  else
    if event_type == "cursor:hide" do
      hide_cursor(socket)
    else
      if event_type == "presence:update" do
        update_presence(socket, payload)
      else
        {:error, :unknown_event}
      end
    end
  end
end

# After: Pattern matching
def handle_event("cursor:update", payload, socket) do
  update_cursor(socket, payload)
end

def handle_event("cursor:hide", _payload, socket) do
  hide_cursor(socket)
end

def handle_event("presence:update", payload, socket) do
  update_presence(socket, payload)
end

def handle_event(_event_type, _payload, _socket) do
  {:error, :unknown_event}
end
```

### Replace Switch with Behaviour

```elixir
# Before: Case statement for notification channels
def deliver(notification, channel) do
  case channel do
    :email ->
      # Email delivery logic
      Mailer.deliver(notification.user.email, build_email(notification))

    :push ->
      # Push notification logic
      PushService.send(notification.user.push_token, build_push(notification))

    :in_app ->
      # In-app notification logic
      InAppNotifications.create(notification)

    _ ->
      {:error, :unknown_channel}
  end
end

# After: Behaviour-based polymorphism
defmodule SyncForge.Notifications.Channel do
  @callback deliver(Notification.t()) :: {:ok, term()} | {:error, term()}
end

defmodule SyncForge.Notifications.Channels.Email do
  @behaviour SyncForge.Notifications.Channel

  @impl true
  def deliver(notification) do
    Mailer.deliver(notification.user.email, build_email(notification))
  end
end

defmodule SyncForge.Notifications.Channels.Push do
  @behaviour SyncForge.Notifications.Channel

  @impl true
  def deliver(notification) do
    PushService.send(notification.user.push_token, build_push(notification))
  end
end

# Registry for channel lookup
@channels %{
  email: SyncForge.Notifications.Channels.Email,
  push: SyncForge.Notifications.Channels.Push,
  in_app: SyncForge.Notifications.Channels.InApp
}

def deliver(notification, channel) do
  case Map.get(@channels, channel) do
    nil -> {:error, :unknown_channel}
    module -> module.deliver(notification)
  end
end
```

### Extract GenServer for State Management

```elixir
# Before: State scattered in channel assigns
defmodule SyncForgeWeb.RoomChannel do
  def join("room:" <> room_id, _params, socket) do
    socket = socket
    |> assign(:cursors, %{})
    |> assign(:document_state, nil)
    |> assign(:last_sync, nil)

    {:ok, socket}
  end

  def handle_in("cursor:update", payload, socket) do
    cursors = Map.put(socket.assigns.cursors, payload["user_id"], payload)
    {:noreply, assign(socket, :cursors, cursors)}
  end
end

# After: GenServer for room state
defmodule SyncForge.Rooms.RoomState do
  use GenServer

  def start_link(room_id) do
    GenServer.start_link(__MODULE__, room_id, name: via_tuple(room_id))
  end

  def update_cursor(room_id, user_id, position) do
    GenServer.cast(via_tuple(room_id), {:update_cursor, user_id, position})
  end

  def get_cursors(room_id) do
    GenServer.call(via_tuple(room_id), :get_cursors)
  end

  @impl true
  def init(room_id) do
    {:ok, %{room_id: room_id, cursors: %{}, document_state: nil}}
  end

  @impl true
  def handle_cast({:update_cursor, user_id, position}, state) do
    cursors = Map.put(state.cursors, user_id, position)
    {:noreply, %{state | cursors: cursors}}
  end

  @impl true
  def handle_call(:get_cursors, _from, state) do
    {:reply, state.cursors, state}
  end

  defp via_tuple(room_id), do: {:via, Registry, {RoomRegistry, room_id}}
end
```

### Use Pipeline for Data Transformation

```elixir
# Before: Nested function calls and temporary variables
def format_presence_list(raw_presence) do
  # Filter online users
  online = Enum.filter(raw_presence, fn {_id, %{metas: metas}} ->
    List.first(metas).online
  end)

  # Extract user data
  users = Enum.map(online, fn {user_id, %{metas: metas}} ->
    meta = List.first(metas)
    %{id: user_id, name: meta.name, avatar: meta.avatar_url}
  end)

  # Sort by name
  sorted = Enum.sort_by(users, & &1.name)

  # Add index for UI
  indexed = Enum.with_index(sorted, fn user, index ->
    Map.put(user, :index, index)
  end)

  indexed
end

# After: Clean pipeline
def format_presence_list(raw_presence) do
  raw_presence
  |> Stream.filter(&user_online?/1)
  |> Stream.map(&extract_user_data/1)
  |> Enum.sort_by(& &1.name)
  |> Enum.with_index(&Map.put(&1, :index, &2))
end

defp user_online?({_id, %{metas: [meta | _]}}), do: meta.online
defp user_online?(_), do: false

defp extract_user_data({user_id, %{metas: [meta | _]}}) do
  %{id: user_id, name: meta.name, avatar: meta.avatar_url}
end
```

### Simplify with Guards

```elixir
# Before: Runtime checks in function body
def broadcast_cursor(socket, x, y) do
  if is_number(x) and is_number(y) and x >= 0 and y >= 0 do
    broadcast!(socket, "cursor:move", %{x: x, y: y})
    {:ok, socket}
  else
    {:error, :invalid_coordinates}
  end
end

# After: Guards for validation
def broadcast_cursor(socket, x, y)
    when is_number(x) and is_number(y) and x >= 0 and y >= 0 do
  broadcast!(socket, "cursor:move", %{x: x, y: y})
  {:ok, socket}
end

def broadcast_cursor(_socket, _x, _y) do
  {:error, :invalid_coordinates}
end
```

---

## Code Smells to Address

| Smell | Symptom | Refactoring |
|-------|---------|-------------|
| Long Function | > 15 lines | Extract Function |
| Large Module | > 200 lines | Extract Module |
| Duplicate Code | Copy-paste | Extract shared function |
| Feature Envy | Uses other module's data | Move function |
| Data Clump | Same params everywhere | Define struct |
| Case Statement | Type checking | Pattern matching / Behaviour |
| Long Parameter List | > 3 params | Keyword list or struct |
| Primitive Obsession | Strings for everything | Define types |
| Nested Conditionals | if/else chains | with statement / pattern matching |
| Dead Code | Unreachable code | Delete |

---

## Real-Time Specific Refactorings

### Optimize Presence Updates

```elixir
# Before: Full presence list on every update
def handle_info({:presence_diff, diff}, socket) do
  presence = Tracker.list("room:#{socket.assigns.room_id}")
  {:noreply, assign(socket, :presence, presence)}
end

# After: Apply diff incrementally
def handle_info({:presence_diff, %{joins: joins, leaves: leaves}}, socket) do
  presence =
    socket.assigns.presence
    |> apply_joins(joins)
    |> apply_leaves(leaves)

  {:noreply, assign(socket, :presence, presence)}
end

defp apply_joins(presence, joins) do
  Enum.reduce(joins, presence, fn {user_id, %{metas: metas}}, acc ->
    Map.put(acc, user_id, List.first(metas))
  end)
end

defp apply_leaves(presence, leaves) do
  Enum.reduce(leaves, presence, fn {user_id, _}, acc ->
    Map.delete(acc, user_id)
  end)
end
```

### Batch Database Operations

```elixir
# Before: Individual inserts in a loop
def persist_cursor_history(cursors) do
  Enum.each(cursors, fn cursor ->
    Repo.insert!(%CursorHistory{
      user_id: cursor.user_id,
      x: cursor.x,
      y: cursor.y,
      recorded_at: DateTime.utc_now()
    })
  end)
end

# After: Batch insert
def persist_cursor_history(cursors) do
  now = DateTime.utc_now()

  entries =
    Enum.map(cursors, fn cursor ->
      %{
        user_id: cursor.user_id,
        x: cursor.x,
        y: cursor.y,
        recorded_at: now,
        inserted_at: now,
        updated_at: now
      }
    end)

  Repo.insert_all(CursorHistory, entries)
end
```

---

## Refactoring Checklist

Before:
- [ ] Tests exist for code being changed
- [ ] All tests pass

During:
- [ ] Make one change at a time
- [ ] Run tests after each change
- [ ] Commit working states

After:
- [ ] All tests still pass
- [ ] No compile warnings
- [ ] Credo passes (`mix credo --strict`)
- [ ] Code is measurably better (less complex, shorter, clearer)
- [ ] Real-time performance maintained (<50ms presence, <100ms sync)
- [ ] Documentation updated if API changed

---

## Output Format

When providing refactoring:

1. **Smell identification** - What's wrong with current code
2. **Refactoring technique** - Which technique you'll apply
3. **Before code** - Current implementation
4. **After code** - Refactored implementation
5. **Tests** - Any new or modified tests
6. **Verification** - How to confirm behavior unchanged

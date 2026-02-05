# Scaffold Prompt - SyncForge

Use this prompt when creating new Phoenix Channels, Presence features, LiveViews, or collaboration components.

---

## Context

I'm working on SyncForge, a **Real-Time Collaboration Infrastructure** platform.

**Tech Stack**:
- Elixir
- Phoenix 1.7+ (with Channels and Presence)
- PostgreSQL (via Ecto)
- Oban for background jobs
- Yjs for CRDT document sync

**Key Patterns**:
- Phoenix Channels for real-time communication
- Phoenix Presence for user tracking
- Ecto Schemas for domain entities
- GenServer for stateful processes
- Behaviours for extensibility

---

## Scaffold Request

### What I need:
[Describe what you want to scaffold - channel, presence feature, component, etc.]

### Type:
- [ ] Phoenix Channel (real-time room communication)
- [ ] Presence Tracker (user presence tracking)
- [ ] Phoenix LiveView (real-time UI)
- [ ] Ecto Schema (domain entity)
- [ ] GenServer (stateful process)
- [ ] Oban Worker (background job)
- [ ] Full Feature (all layers)

### Related entities:
[List any existing modules this relates to]

### Requirements:
[List specific requirements or behaviors]

---

## Example Usage

### Scaffold a Phoenix Channel

**Request**:
```
Scaffold a Phoenix Channel for voice room communication.

Type: Phoenix Channel
Related: Room, User, Presence
Requirements:
- Users join voice rooms
- Track speaking status
- Broadcast mute/unmute events
- Handle WebRTC signaling
```

**Expected Output**:
- `lib/syncforge_web/channels/voice_channel.ex`
- Channel callbacks for join, handle_in, terminate
- Presence tracking integration
- Proper authorization

**Example Channel**:
```elixir
# lib/syncforge_web/channels/voice_channel.ex
defmodule SyncForgeWeb.VoiceChannel do
  @moduledoc """
  Phoenix Channel for voice room communication.

  Handles WebRTC signaling, speaking status, and audio controls.
  """

  use SyncForgeWeb, :channel

  alias SyncForge.Rooms
  alias SyncForge.Voice
  alias SyncForge.Presence.Tracker

  require Logger

  @impl true
  def join("voice:" <> room_id, params, socket) do
    user = socket.assigns.current_user

    case Rooms.authorize_join(room_id, user) do
      {:ok, room} ->
        send(self(), :after_join)

        {:ok,
         socket
         |> assign(:room, room)
         |> assign(:room_id, room_id)
         |> assign(:muted, Map.get(params, "muted", true))
         |> assign(:speaking, false)}

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    user = socket.assigns.current_user

    # Track voice presence with audio state
    {:ok, _} = Tracker.track(socket, user.id, %{
      user_id: user.id,
      name: user.name,
      avatar_url: user.avatar_url,
      muted: socket.assigns.muted,
      speaking: false,
      joined_at: System.system_time(:second)
    })

    # Push current voice participants
    push(socket, "presence_state", Tracker.list(socket))

    # Notify others of new participant
    broadcast_from!(socket, "user:joined", %{
      user_id: user.id,
      name: user.name
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("mute:toggle", _params, socket) do
    new_muted = !socket.assigns.muted
    user_id = socket.assigns.current_user.id

    # Update presence metadata
    Tracker.update(socket, user_id, fn meta ->
      Map.put(meta, :muted, new_muted)
    end)

    broadcast!(socket, "user:muted", %{
      user_id: user_id,
      muted: new_muted
    })

    {:reply, {:ok, %{muted: new_muted}}, assign(socket, :muted, new_muted)}
  end

  @impl true
  def handle_in("speaking:update", %{"speaking" => speaking}, socket) do
    user_id = socket.assigns.current_user.id

    # Update speaking status in presence
    Tracker.update(socket, user_id, fn meta ->
      Map.put(meta, :speaking, speaking)
    end)

    broadcast_from!(socket, "user:speaking", %{
      user_id: user_id,
      speaking: speaking
    })

    {:noreply, assign(socket, :speaking, speaking)}
  end

  @impl true
  def handle_in("signal:offer", %{"to" => to_user_id, "offer" => offer}, socket) do
    # WebRTC signaling - send offer to specific user
    broadcast!(socket, "signal:offer", %{
      from: socket.assigns.current_user.id,
      to: to_user_id,
      offer: offer
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("signal:answer", %{"to" => to_user_id, "answer" => answer}, socket) do
    # WebRTC signaling - send answer to specific user
    broadcast!(socket, "signal:answer", %{
      from: socket.assigns.current_user.id,
      to: to_user_id,
      answer: answer
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("signal:ice", %{"to" => to_user_id, "candidate" => candidate}, socket) do
    # WebRTC signaling - send ICE candidate
    broadcast!(socket, "signal:ice", %{
      from: socket.assigns.current_user.id,
      to: to_user_id,
      candidate: candidate
    })

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    user_id = socket.assigns.current_user.id

    broadcast!(socket, "user:left", %{user_id: user_id})

    Logger.info("User #{user_id} left voice room #{socket.assigns.room_id}")

    :ok
  end
end
```

### Scaffold a Presence Tracker

**Request**:
```
Scaffold a Presence Tracker for cursor positions.

Type: Presence Tracker
Related: Room, User
Requirements:
- Track cursor x, y positions
- Include user metadata (name, color)
- Efficient updates (throttled)
- Handle multi-device presence
```

**Expected Output**:
- `lib/syncforge/presence/cursor_tracker.ex`
- Presence tracking with metadata
- Update functions
- Query functions

**Example Tracker**:
```elixir
# lib/syncforge/presence/cursor_tracker.ex
defmodule SyncForge.Presence.CursorTracker do
  @moduledoc """
  Tracks cursor positions for users in collaboration rooms.

  Uses Phoenix Presence for distributed cursor synchronization.
  """

  use Phoenix.Presence,
    otp_app: :syncforge,
    pubsub_server: SyncForge.PubSub

  alias SyncForge.Accounts.User

  @colors [
    "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
    "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F"
  ]

  @doc """
  Track a user's cursor in a room with initial metadata.
  """
  @spec track_cursor(Phoenix.Socket.t(), User.t(), map()) :: {:ok, binary()} | {:error, term()}
  def track_cursor(socket, user, initial_position \\ %{x: 0, y: 0}) do
    track(socket, user.id, %{
      user_id: user.id,
      name: user.name,
      avatar_url: user.avatar_url,
      color: assign_cursor_color(user.id),
      x: initial_position.x,
      y: initial_position.y,
      selection: nil,
      last_active: System.system_time(:millisecond)
    })
  end

  @doc """
  Update cursor position for a user.
  """
  @spec update_position(Phoenix.Socket.t(), String.t(), number(), number()) :: {:ok, map()} | {:error, term()}
  def update_position(socket, user_id, x, y) do
    update(socket, user_id, fn meta ->
      meta
      |> Map.put(:x, x)
      |> Map.put(:y, y)
      |> Map.put(:last_active, System.system_time(:millisecond))
    end)
  end

  @doc """
  Update user's text selection.
  """
  @spec update_selection(Phoenix.Socket.t(), String.t(), map() | nil) :: {:ok, map()} | {:error, term()}
  def update_selection(socket, user_id, selection) do
    update(socket, user_id, fn meta ->
      meta
      |> Map.put(:selection, selection)
      |> Map.put(:last_active, System.system_time(:millisecond))
    end)
  end

  @doc """
  Get all cursors in a room, deduplicating multi-device presence.
  """
  @spec list_cursors(String.t()) :: [map()]
  def list_cursors(room_topic) do
    list(room_topic)
    |> Enum.map(fn {_user_id, %{metas: metas}} ->
      # Take the most recent cursor position for each user
      metas
      |> Enum.sort_by(& &1.last_active, :desc)
      |> List.first()
    end)
    |> Enum.filter(& &1)
  end

  @doc """
  Get active cursors (moved within last 5 seconds).
  """
  @spec list_active_cursors(String.t()) :: [map()]
  def list_active_cursors(room_topic) do
    cutoff = System.system_time(:millisecond) - 5_000

    list_cursors(room_topic)
    |> Enum.filter(fn cursor -> cursor.last_active > cutoff end)
  end

  # Assign a consistent color based on user ID
  defp assign_cursor_color(user_id) do
    index = :erlang.phash2(user_id, length(@colors))
    Enum.at(@colors, index)
  end
end
```

### Scaffold an Ecto Schema

**Request**:
```
Scaffold an Ecto Schema for Comments.

Type: Ecto Schema
Related: Room, User
Requirements:
- Threaded comments (parent/replies)
- Anchor to elements (id, type, position)
- Resolution tracking
- Soft delete support
```

**Expected Output**:
- `lib/syncforge/comments/comment.ex`
- Schema with associations
- Changesets for create/update
- Query functions

**Example Schema**:
```elixir
# lib/syncforge/comments/comment.ex
defmodule SyncForge.Comments.Comment do
  @moduledoc """
  Threaded comments anchored to elements in collaboration rooms.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias SyncForge.Repo
  alias SyncForge.Rooms.Room
  alias SyncForge.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "comments" do
    field :body, :string
    field :anchor_id, :string
    field :anchor_type, Ecto.Enum, values: [:element, :selection, :point]
    field :position, :map
    field :resolved_at, :utc_datetime
    field :resolved_by_id, :binary_id
    field :deleted_at, :utc_datetime

    belongs_to :room, Room
    belongs_to :user, User
    belongs_to :parent, __MODULE__
    has_many :replies, __MODULE__, foreign_key: :parent_id

    timestamps()
  end

  @required_fields [:body, :room_id, :user_id]
  @optional_fields [:anchor_id, :anchor_type, :position, :parent_id]

  @doc """
  Changeset for creating a new comment.
  """
  def create_changeset(comment, attrs) do
    comment
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:body, min: 1, max: 10_000)
    |> validate_anchor()
    |> foreign_key_constraint(:room_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:parent_id)
  end

  @doc """
  Changeset for updating a comment.
  """
  def update_changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 10_000)
  end

  @doc """
  Changeset for resolving a comment thread.
  """
  def resolve_changeset(comment, resolved_by_id) do
    comment
    |> change(%{
      resolved_at: DateTime.utc_now(),
      resolved_by_id: resolved_by_id
    })
  end

  @doc """
  Changeset for soft-deleting a comment.
  """
  def delete_changeset(comment) do
    change(comment, %{deleted_at: DateTime.utc_now()})
  end

  # Query helpers

  @doc """
  Base query excluding soft-deleted comments.
  """
  def base_query do
    from(c in __MODULE__, where: is_nil(c.deleted_at))
  end

  @doc """
  Query for comments in a room with user preloaded.
  """
  def for_room(room_id) do
    from(c in base_query(),
      where: c.room_id == ^room_id,
      where: is_nil(c.parent_id),
      order_by: [asc: c.inserted_at],
      preload: [:user, replies: :user]
    )
  end

  @doc """
  Query for unresolved comments in a room.
  """
  def unresolved_for_room(room_id) do
    from(c in for_room(room_id),
      where: is_nil(c.resolved_at)
    )
  end

  # Validation helpers

  defp validate_anchor(changeset) do
    anchor_type = get_field(changeset, :anchor_type)
    anchor_id = get_field(changeset, :anchor_id)

    cond do
      anchor_type && !anchor_id ->
        add_error(changeset, :anchor_id, "is required when anchor_type is set")

      anchor_type == :point && !get_field(changeset, :position) ->
        add_error(changeset, :position, "is required for point anchors")

      true ->
        changeset
    end
  end
end
```

### Scaffold an Oban Worker

**Request**:
```
Scaffold an Oban worker for sending notifications.

Type: Oban Worker
Related: Notification, User
Requirements:
- Process notification queue
- Support multiple channels (email, push, in-app)
- Handle retries with backoff
- Batch processing for efficiency
```

**Expected Output**:
- `lib/syncforge/workers/notification_worker.ex`
- Oban configuration
- Error handling
- Telemetry events

**Example Worker**:
```elixir
# lib/syncforge/workers/notification_worker.ex
defmodule SyncForge.Workers.NotificationWorker do
  @moduledoc """
  Processes notifications across multiple delivery channels.
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 5,
    unique: [period: 60, fields: [:args, :queue]]

  alias SyncForge.Notifications
  alias SyncForge.Notifications.{Notification, Delivery}
  alias SyncForge.Accounts

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"notification_id" => notification_id, "channel" => channel}}) do
    Logger.info("Processing notification", notification_id: notification_id, channel: channel)

    with {:ok, notification} <- Notifications.get_notification(notification_id),
         {:ok, user} <- Accounts.get_user(notification.user_id),
         :ok <- deliver(notification, user, channel) do
      Notifications.mark_delivered(notification_id, channel)
      {:ok, :delivered}
    else
      {:error, :not_found} ->
        Logger.warn("Notification not found", notification_id: notification_id)
        {:cancel, "Notification not found"}

      {:error, :user_not_found} ->
        Logger.warn("User not found for notification", notification_id: notification_id)
        {:cancel, "User not found"}

      {:error, reason} = error ->
        Logger.error("Notification delivery failed",
          notification_id: notification_id,
          channel: channel,
          reason: inspect(reason)
        )
        error
    end
  end

  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}) do
    # Exponential backoff: 1m, 5m, 15m, 30m, 60m
    trunc(:math.pow(2, attempt) * 30)
  end

  # Channel-specific delivery

  defp deliver(notification, user, "email") do
    case user.email_notifications_enabled do
      true ->
        SyncForge.Mailer.deliver_notification(user.email, notification)
      false ->
        Logger.info("Email notifications disabled for user", user_id: user.id)
        {:ok, :skipped}
    end
  end

  defp deliver(notification, user, "push") do
    case user.push_token do
      nil ->
        Logger.info("No push token for user", user_id: user.id)
        {:ok, :skipped}

      token ->
        SyncForge.Push.send_notification(token, notification)
    end
  end

  defp deliver(notification, _user, "in_app") do
    # In-app notifications are created immediately, just mark as ready
    {:ok, :in_app}
  end

  defp deliver(_notification, _user, channel) do
    {:error, "Unknown notification channel: #{channel}"}
  end

  # Batch job creation helper

  @doc """
  Enqueue notifications for all specified channels.
  """
  def enqueue_all_channels(notification_id, channels \\ ["email", "push", "in_app"]) do
    jobs =
      Enum.map(channels, fn channel ->
        %{notification_id: notification_id, channel: channel}
        |> new()
        |> Oban.insert()
      end)

    {:ok, jobs}
  end
end
```

### Scaffold a LiveView

**Request**:
```
Scaffold a LiveView for the collaboration room.

Type: Phoenix LiveView
Related: Room, Presence, Comments
Requirements:
- Display room participants (presence)
- Show live cursors
- Comments sidebar
- Real-time document updates
```

**Expected Output**:
- `lib/syncforge_web/live/room_live/show.ex`
- Presence subscription
- Event handlers
- Component composition

**Example LiveView**:
```elixir
# lib/syncforge_web/live/room_live/show.ex
defmodule SyncForgeWeb.RoomLive.Show do
  @moduledoc """
  LiveView for real-time collaboration room.
  """

  use SyncForgeWeb, :live_view

  alias SyncForge.Rooms
  alias SyncForge.Comments
  alias SyncForge.Presence.Tracker

  @impl true
  def mount(%{"id" => room_id}, _session, socket) do
    if connected?(socket) do
      # Subscribe to room updates
      Phoenix.PubSub.subscribe(SyncForge.PubSub, "room:#{room_id}")
      Phoenix.PubSub.subscribe(SyncForge.PubSub, "room:#{room_id}:comments")
    end

    room = Rooms.get_room!(room_id)
    comments = Comments.list_for_room(room_id)

    {:ok,
     socket
     |> assign(:room, room)
     |> assign(:comments, comments)
     |> assign(:cursors, [])
     |> assign(:participants, [])
     |> assign(:comments_open, false)
     |> push_event("room:init", %{room_id: room_id})}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: _diff}, socket) do
    participants = Tracker.list_room_users(socket.assigns.room.id)
    {:noreply, assign(socket, :participants, participants)}
  end

  @impl true
  def handle_info({:cursor_update, user_id, x, y}, socket) do
    cursors =
      socket.assigns.cursors
      |> Enum.reject(fn c -> c.user_id == user_id end)
      |> Enum.concat([%{user_id: user_id, x: x, y: y, timestamp: System.system_time(:millisecond)}])

    {:noreply, assign(socket, :cursors, cursors)}
  end

  @impl true
  def handle_info({:comment_added, comment}, socket) do
    comments = [comment | socket.assigns.comments]
    {:noreply, assign(socket, :comments, comments)}
  end

  @impl true
  def handle_info({:comment_resolved, comment_id}, socket) do
    comments =
      Enum.map(socket.assigns.comments, fn c ->
        if c.id == comment_id, do: %{c | resolved_at: DateTime.utc_now()}, else: c
      end)

    {:noreply, assign(socket, :comments, comments)}
  end

  @impl true
  def handle_event("toggle_comments", _params, socket) do
    {:noreply, assign(socket, :comments_open, !socket.assigns.comments_open)}
  end

  @impl true
  def handle_event("add_comment", %{"body" => body, "anchor" => anchor}, socket) do
    case Comments.create(socket.assigns.current_user, socket.assigns.room, %{
      body: body,
      anchor_id: anchor["id"],
      anchor_type: anchor["type"],
      position: anchor["position"]
    }) do
      {:ok, comment} ->
        # Broadcast happens in Comments context
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add comment")}
    end
  end

  @impl true
  def handle_event("resolve_comment", %{"id" => comment_id}, socket) do
    case Comments.resolve(comment_id, socket.assigns.current_user.id) do
      {:ok, _} -> {:noreply, socket}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to resolve comment")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-screen">
      <!-- Main collaboration area -->
      <div class="flex-1 relative" id="collaboration-area" phx-hook="CollaborationArea">
        <!-- Presence avatars -->
        <.presence_bar participants={@participants} />

        <!-- Live cursors layer -->
        <.cursor_layer cursors={@cursors} current_user_id={@current_user.id} />

        <!-- Document content (managed by JS) -->
        <div id="document-content" phx-update="ignore" class="h-full">
          <!-- Yjs-managed content renders here -->
        </div>

        <!-- Comments toggle -->
        <button
          phx-click="toggle_comments"
          class="fixed bottom-4 right-4 bg-blue-600 text-white rounded-full p-3 shadow-lg"
        >
          <.icon name="hero-chat-bubble-left" class="w-6 h-6" />
          <span :if={unresolved_count(@comments) > 0} class="absolute -top-1 -right-1 bg-red-500 text-white text-xs rounded-full w-5 h-5 flex items-center justify-center">
            <%= unresolved_count(@comments) %>
          </span>
        </button>
      </div>

      <!-- Comments sidebar -->
      <.comments_sidebar
        :if={@comments_open}
        comments={@comments}
        current_user={@current_user}
      />
    </div>
    """
  end

  defp unresolved_count(comments) do
    Enum.count(comments, fn c -> is_nil(c.resolved_at) end)
  end
end
```

---

## Output Requirements

When scaffolding, include:

1. **File structure** - Where each file should go
2. **Module documentation** - @moduledoc with purpose
3. **Type specifications** - @spec for public functions
4. **Test file stubs** - Empty test files with describe blocks
5. **Integration notes** - How this connects to existing code

---

## Quality Checklist

After scaffolding, verify:

- [ ] Follows Elixir naming conventions (snake_case)
- [ ] Module structure matches project patterns
- [ ] Uses Phoenix Channels patterns for real-time
- [ ] Has proper error handling structure
- [ ] Includes @moduledoc and @doc where appropriate
- [ ] Test file created alongside implementation
- [ ] Presence tracking follows project patterns
- [ ] Broadcasting uses correct PubSub topics

defmodule SyncforgeWeb.RoomChannel do
  @moduledoc """
  Channel for real-time room collaboration.

  Handles:
  - User presence tracking (who's in the room)
  - Live cursor positions
  - Real-time events (typing, selections, etc.)
  - Threaded comments with anchoring
  - Document sync (future: CRDT via Yjs)

  ## Topic Format

  Rooms are joined via topic "room:{room_id}" where room_id is a UUID.

  ## Events

  ### Client → Server
  - `cursor:update` - Update cursor position
  - `presence:update` - Update presence metadata (status, etc.)
  - `selection:update` - Update text/element selection
  - `comment:create` - Create a new comment
  - `comment:update` - Update an existing comment
  - `comment:delete` - Delete a comment
  - `comment:resolve` - Resolve or unresolve a comment

  ### Server → Client
  - `cursor:update` - Broadcast cursor positions
  - `presence_state` - Initial presence state on join
  - `presence_diff` - Presence changes (joins/leaves)
  - `comment:created` - New comment was created
  - `comment:updated` - Comment was updated
  - `comment:deleted` - Comment was deleted
  - `comment:resolved` - Comment resolution status changed
  """

  use SyncforgeWeb, :channel

  alias Syncforge.Cursors.Throttler
  alias SyncforgeWeb.Presence

  require Logger

  @impl true
  def join("room:" <> room_id, _params, socket) do
    # TODO: Add room authorization check here
    # case Syncforge.Rooms.authorize_join(room_id, socket.assigns.current_user) do
    #   {:ok, room} -> ...
    #   {:error, reason} -> {:error, %{reason: reason}}
    # end

    send(self(), :after_join)

    socket =
      socket
      |> assign(:room_id, room_id)

    {:ok, %{presence: %{}}, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    # Track user presence in this room
    {:ok, _ref} =
      Presence.track(socket, user.id, %{
        user_id: user.id,
        name: user.name,
        avatar_url: Map.get(user, :avatar_url),
        status: "active",
        joined_at: DateTime.utc_now()
      })

    # Push current presence state to the joining user
    push(socket, "presence_state", Presence.list(socket))

    # Push current room state (comments, room metadata) to the joining user
    room_state = Syncforge.Rooms.get_state(room_id)
    push(socket, "room_state", room_state)

    Logger.info("User #{user.id} joined room #{room_id}")

    {:noreply, socket}
  end

  # Default cursor colors for users without a custom color
  @default_cursor_colors [
    "#3B82F6",
    "#EF4444",
    "#10B981",
    "#F59E0B",
    "#8B5CF6",
    "#EC4899",
    "#06B6D4",
    "#F97316"
  ]

  @impl true
  def handle_in("cursor:update", %{"x" => x, "y" => y} = params, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    # Only broadcast if throttle allows (prevents flooding at high cursor rates)
    if Throttler.should_broadcast?(room_id, user.id) do
      # Determine cursor color - use user's custom color or generate a default based on user_id
      cursor_color = get_cursor_color(user)

      # Build cursor payload with name and color for cursor labels
      payload = %{
        user_id: user.id,
        name: user.name,
        color: cursor_color,
        x: x,
        y: y,
        timestamp: System.system_time(:millisecond)
      }

      payload =
        case params do
          %{"element_id" => element_id} -> Map.put(payload, :element_id, element_id)
          _ -> payload
        end

      # Broadcast cursor position to all OTHER users in the room
      broadcast_from!(socket, "cursor:update", payload)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_in("presence:update", params, socket) do
    user = socket.assigns.current_user

    # Update presence metadata
    Presence.update(socket, user.id, fn meta ->
      meta
      |> maybe_update(:status, params["status"])
      |> maybe_update(:cursor_visible, params["cursor_visible"])
      |> Map.put(:updated_at, DateTime.utc_now())
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_in("selection:update", params, socket) do
    user = socket.assigns.current_user

    # Broadcast selection to other users
    broadcast_from!(socket, "selection:update", %{
      user_id: user.id,
      selection: params["selection"],
      element_id: params["element_id"],
      timestamp: System.system_time(:millisecond)
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("typing:start", _params, socket) do
    user = socket.assigns.current_user

    broadcast_from!(socket, "typing:start", %{
      user_id: user.id
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("typing:stop", _params, socket) do
    user = socket.assigns.current_user

    broadcast_from!(socket, "typing:stop", %{
      user_id: user.id
    })

    {:noreply, socket}
  end

  # Comment events for real-time comment sync

  @impl true
  def handle_in("comment:create", params, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    # Build comment attributes with room and user from socket context
    attrs =
      params
      |> Map.put("room_id", room_id)
      |> Map.put("user_id", user.id)

    case Syncforge.Comments.create_comment(attrs) do
      {:ok, comment} ->
        # Broadcast the new comment to all room members
        broadcast!(socket, "comment:created", %{comment: serialize_comment(comment)})
        {:reply, {:ok, %{comment: serialize_comment(comment)}}, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_changeset_errors(changeset)}}, socket}
    end
  end

  @impl true
  def handle_in("comment:update", %{"id" => comment_id} = params, socket) do
    case Syncforge.Comments.get_comment(comment_id) do
      nil ->
        {:reply, {:error, %{reason: :not_found}}, socket}

      comment ->
        # Only allow updating certain fields
        update_attrs = Map.take(params, ["body", "anchor_id", "anchor_type", "position"])

        case Syncforge.Comments.update_comment(comment, update_attrs) do
          {:ok, updated} ->
            broadcast!(socket, "comment:updated", %{comment: serialize_comment(updated)})
            {:reply, {:ok, %{comment: serialize_comment(updated)}}, socket}

          {:error, changeset} ->
            {:reply, {:error, %{errors: format_changeset_errors(changeset)}}, socket}
        end
    end
  end

  @impl true
  def handle_in("comment:delete", %{"id" => comment_id}, socket) do
    case Syncforge.Comments.get_comment(comment_id) do
      nil ->
        {:reply, {:error, %{reason: :not_found}}, socket}

      comment ->
        case Syncforge.Comments.delete_comment(comment) do
          {:ok, _deleted} ->
            broadcast!(socket, "comment:deleted", %{comment_id: comment_id})
            {:reply, {:ok, %{}}, socket}

          {:error, _changeset} ->
            {:reply, {:error, %{reason: :delete_failed}}, socket}
        end
    end
  end

  @impl true
  def handle_in("comment:resolve", %{"id" => comment_id, "resolved" => resolved}, socket) do
    case Syncforge.Comments.get_comment(comment_id) do
      nil ->
        {:reply, {:error, %{reason: :not_found}}, socket}

      comment ->
        result =
          if resolved do
            Syncforge.Comments.resolve_comment(comment)
          else
            Syncforge.Comments.unresolve_comment(comment)
          end

        case result do
          {:ok, updated} ->
            broadcast!(socket, "comment:resolved", %{comment: serialize_comment(updated)})
            {:reply, {:ok, %{comment: serialize_comment(updated)}}, socket}

          {:error, changeset} ->
            {:reply, {:error, %{errors: format_changeset_errors(changeset)}}, socket}
        end
    end
  end

  @impl true
  def terminate(_reason, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    # Cleanup cursor throttle tracking for this user
    Throttler.cleanup(room_id, user.id)

    Logger.info("User #{user.id} left room #{room_id}")

    # Presence is automatically cleaned up by Phoenix.Presence
    :ok
  end

  # Private helpers

  defp maybe_update(map, _key, nil), do: map
  defp maybe_update(map, key, value), do: Map.put(map, key, value)

  # Get cursor color - use user's custom color or generate a deterministic default
  defp get_cursor_color(user) do
    case Map.get(user, :cursor_color) do
      nil -> default_color_for_user(user.id)
      color -> color
    end
  end

  # Generate a deterministic default color based on user_id
  defp default_color_for_user(user_id) do
    # Use hash of user_id to deterministically pick a color
    index = :erlang.phash2(user_id, length(@default_cursor_colors))
    Enum.at(@default_cursor_colors, index)
  end

  # Serialize a comment struct for JSON response
  defp serialize_comment(comment) do
    %{
      id: comment.id,
      body: comment.body,
      anchor_id: comment.anchor_id,
      anchor_type: comment.anchor_type,
      position: comment.position,
      resolved_at: comment.resolved_at,
      user_id: comment.user_id,
      room_id: comment.room_id,
      parent_id: comment.parent_id,
      inserted_at: comment.inserted_at,
      updated_at: comment.updated_at
    }
  end

  # Format Ecto changeset errors for JSON response
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

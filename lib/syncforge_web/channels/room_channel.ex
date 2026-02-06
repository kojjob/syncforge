defmodule SyncforgeWeb.RoomChannel do
  @moduledoc """
  Channel for real-time room collaboration.

  Handles:
  - User presence tracking (who's in the room)
  - Live cursor positions
  - Real-time events (typing, selections, etc.)
  - Threaded comments with anchoring
  - Activity feed (room-level event history)
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
  - `reaction:add` - Add an emoji reaction to a comment
  - `reaction:remove` - Remove an emoji reaction from a comment
  - `reaction:toggle` - Toggle an emoji reaction (add if missing, remove if exists)
  - `activity:list` - List paginated activities for the room

  ### Server → Client
  - `cursor:update` - Broadcast cursor positions
  - `presence_state` - Initial presence state on join
  - `presence_diff` - Presence changes (joins/leaves)
  - `comment:created` - New comment was created
  - `comment:updated` - Comment was updated
  - `comment:deleted` - Comment was deleted
  - `comment:resolved` - Comment resolution status changed
  - `reaction:added` - Reaction was added to a comment
  - `reaction:removed` - Reaction was removed from a comment
  - `activity:created` - New activity was recorded (broadcast to room)
  """

  use SyncforgeWeb, :channel

  alias Syncforge.Activity
  alias Syncforge.Cursors.Throttler
  alias SyncforgeWeb.Presence

  require Logger

  @impl true
  def join("room:" <> room_id, _params, socket) do
    with {:ok, room, role} <-
           Syncforge.Rooms.authorize_join(room_id, socket.assigns.current_user),
         org <- load_organization(room),
         :ok <- check_connection_limit(org) do
      send(self(), :after_join)

      socket =
        socket
        |> assign(:room_id, room.id)
        |> assign(:membership_role, role)
        |> assign(:organization, org)

      {:ok, %{presence: %{}}, socket}
    else
      {:error, reason} ->
        {:error, %{reason: reason}}
    end
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

    SyncforgeWeb.Telemetry.emit_room_join(%{room_id: room_id})

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
    if not can_write?(socket), do: throw(:forbidden)

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
  catch
    :forbidden -> {:reply, {:error, %{reason: :forbidden}}, socket}
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
    if not can_write?(socket), do: throw(:forbidden)

    user = socket.assigns.current_user

    # Get user color for selection highlighting (same as cursor color)
    selection_color = get_cursor_color(user)

    # Broadcast selection to other users
    broadcast_from!(socket, "selection:update", %{
      user_id: user.id,
      name: user.name,
      color: selection_color,
      selection: params["selection"],
      element_id: params["element_id"],
      timestamp: System.system_time(:millisecond)
    })

    {:noreply, socket}
  catch
    :forbidden -> {:reply, {:error, %{reason: :forbidden}}, socket}
  end

  @impl true
  def handle_in("typing:start", _params, socket) do
    if not can_write?(socket), do: throw(:forbidden)

    user = socket.assigns.current_user

    broadcast_from!(socket, "typing:start", %{
      user_id: user.id
    })

    {:noreply, socket}
  catch
    :forbidden -> {:reply, {:error, %{reason: :forbidden}}, socket}
  end

  @impl true
  def handle_in("typing:stop", _params, socket) do
    if not can_write?(socket), do: throw(:forbidden)

    user = socket.assigns.current_user

    broadcast_from!(socket, "typing:stop", %{
      user_id: user.id
    })

    {:noreply, socket}
  catch
    :forbidden -> {:reply, {:error, %{reason: :forbidden}}, socket}
  end

  # Comment events for real-time comment sync

  @impl true
  def handle_in("comment:create", params, socket) do
    if not can_write?(socket), do: throw(:forbidden)
    if check_feature(socket, :comments) != :ok, do: throw(:feature_not_available)

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

        # Create and broadcast activity
        create_and_broadcast_activity(socket, "comment_created", %{
          subject_id: comment.id,
          subject_type: "comment",
          payload: %{body_preview: String.slice(comment.body || "", 0, 100)}
        })

        {:reply, {:ok, %{comment: serialize_comment(comment)}}, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_changeset_errors(changeset)}}, socket}
    end
  catch
    :forbidden -> {:reply, {:error, %{reason: :forbidden}}, socket}
    :feature_not_available -> {:reply, {:error, %{reason: :feature_not_available}}, socket}
  end

  @impl true
  def handle_in("comment:update", %{"id" => comment_id} = params, socket) do
    if not can_write?(socket), do: throw(:forbidden)

    user = socket.assigns.current_user

    case Syncforge.Comments.get_comment(comment_id) do
      nil ->
        {:reply, {:error, %{reason: :not_found}}, socket}

      comment ->
        if comment.room_id != socket.assigns.room_id or comment.user_id != user.id do
          {:reply, {:error, %{reason: :unauthorized}}, socket}
        else
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
  catch
    :forbidden -> {:reply, {:error, %{reason: :forbidden}}, socket}
  end

  @impl true
  def handle_in("comment:delete", %{"id" => comment_id}, socket) do
    if not can_write?(socket), do: throw(:forbidden)

    user = socket.assigns.current_user

    case Syncforge.Comments.get_comment(comment_id) do
      nil ->
        {:reply, {:error, %{reason: :not_found}}, socket}

      comment ->
        if comment.room_id != socket.assigns.room_id or comment.user_id != user.id do
          {:reply, {:error, %{reason: :unauthorized}}, socket}
        else
          case Syncforge.Comments.delete_comment(comment) do
            {:ok, _deleted} ->
              broadcast!(socket, "comment:deleted", %{comment_id: comment_id})

              create_and_broadcast_activity(socket, "comment_deleted", %{
                subject_id: comment_id,
                subject_type: "comment",
                payload: %{}
              })

              {:reply, {:ok, %{}}, socket}

            {:error, _changeset} ->
              {:reply, {:error, %{reason: :delete_failed}}, socket}
          end
        end
    end
  catch
    :forbidden -> {:reply, {:error, %{reason: :forbidden}}, socket}
  end

  @impl true
  def handle_in("comment:resolve", %{"id" => comment_id, "resolved" => resolved}, socket) do
    if not can_write?(socket), do: throw(:forbidden)

    user = socket.assigns.current_user

    case Syncforge.Comments.get_comment(comment_id) do
      nil ->
        {:reply, {:error, %{reason: :not_found}}, socket}

      comment ->
        if comment.room_id != socket.assigns.room_id or comment.user_id != user.id do
          {:reply, {:error, %{reason: :unauthorized}}, socket}
        else
          result =
            if resolved do
              Syncforge.Comments.resolve_comment(comment)
            else
              Syncforge.Comments.unresolve_comment(comment)
            end

          case result do
            {:ok, updated} ->
              broadcast!(socket, "comment:resolved", %{comment: serialize_comment(updated)})

              if resolved do
                create_and_broadcast_activity(socket, "comment_resolved", %{
                  subject_id: comment_id,
                  subject_type: "comment",
                  payload: %{}
                })
              end

              {:reply, {:ok, %{comment: serialize_comment(updated)}}, socket}

            {:error, changeset} ->
              {:reply, {:error, %{errors: format_changeset_errors(changeset)}}, socket}
          end
        end
    end
  catch
    :forbidden -> {:reply, {:error, %{reason: :forbidden}}, socket}
  end

  # Reaction events for emoji reactions on comments

  @impl true
  def handle_in("reaction:add", %{"comment_id" => comment_id, "emoji" => emoji}, socket) do
    if not can_write?(socket), do: throw(:forbidden)

    user = socket.assigns.current_user

    attrs = %{
      comment_id: comment_id,
      user_id: user.id,
      emoji: emoji
    }

    case Syncforge.Reactions.add_reaction(attrs) do
      {:ok, reaction} ->
        broadcast!(socket, "reaction:added", %{reaction: serialize_reaction(reaction)})

        # Create and broadcast activity
        create_and_broadcast_activity(socket, "reaction_added", %{
          subject_id: comment_id,
          subject_type: "comment",
          payload: %{emoji: emoji}
        })

        {:reply, {:ok, %{reaction: serialize_reaction(reaction)}}, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_changeset_errors(changeset)}}, socket}
    end
  catch
    :forbidden -> {:reply, {:error, %{reason: :forbidden}}, socket}
  end

  @impl true
  def handle_in("reaction:remove", %{"comment_id" => comment_id, "emoji" => emoji}, socket) do
    if not can_write?(socket), do: throw(:forbidden)

    user = socket.assigns.current_user

    case Syncforge.Reactions.remove_reaction(comment_id, user.id, emoji) do
      {:ok, reaction} ->
        broadcast!(socket, "reaction:removed", %{
          reaction_id: reaction.id,
          comment_id: comment_id,
          user_id: user.id,
          emoji: emoji
        })

        # Create and broadcast activity
        create_and_broadcast_activity(socket, "reaction_removed", %{
          subject_id: comment_id,
          subject_type: "comment",
          payload: %{emoji: emoji}
        })

        {:reply, {:ok, %{}}, socket}

      {:error, :not_found} ->
        {:reply, {:error, %{reason: :not_found}}, socket}
    end
  catch
    :forbidden -> {:reply, {:error, %{reason: :forbidden}}, socket}
  end

  # Fallback for reaction:add with missing params
  @impl true
  def handle_in("reaction:add", _params, socket) do
    {:reply, {:error, %{errors: %{emoji: ["can't be blank"], comment_id: ["can't be blank"]}}},
     socket}
  end

  # Fallback for reaction:remove with missing params
  @impl true
  def handle_in("reaction:remove", _params, socket) do
    {:reply, {:error, %{reason: :missing_params}}, socket}
  end

  @impl true
  def handle_in("reaction:toggle", %{"comment_id" => comment_id, "emoji" => emoji}, socket) do
    if not can_write?(socket), do: throw(:forbidden)

    user = socket.assigns.current_user

    attrs = %{
      comment_id: comment_id,
      user_id: user.id,
      emoji: emoji
    }

    case Syncforge.Reactions.toggle_reaction(attrs) do
      {:ok, :added, reaction} ->
        broadcast!(socket, "reaction:added", %{reaction: serialize_reaction(reaction)})
        {:reply, {:ok, %{action: :added, reaction: serialize_reaction(reaction)}}, socket}

      {:ok, :removed, reaction} ->
        broadcast!(socket, "reaction:removed", %{
          reaction_id: reaction.id,
          comment_id: comment_id,
          user_id: user.id,
          emoji: emoji
        })

        {:reply, {:ok, %{action: :removed}}, socket}

      {:error, changeset} ->
        {:reply, {:error, %{errors: format_changeset_errors(changeset)}}, socket}
    end
  catch
    :forbidden -> {:reply, {:error, %{reason: :forbidden}}, socket}
  end

  # Activity feed events

  @impl true
  def handle_in("activity:list", params, socket) do
    room_id = socket.assigns.room_id

    opts = [
      limit: Map.get(params, "limit", 50),
      offset: Map.get(params, "offset", 0)
    ]

    activities =
      Activity.list_room_activities(room_id, opts)
      |> Enum.map(&Activity.serialize_activity/1)

    {:reply, {:ok, %{activities: activities}}, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    # Cleanup cursor throttle tracking for this user
    Throttler.cleanup(room_id, user.id)

    Logger.info("User #{user.id} left room #{room_id}")

    SyncforgeWeb.Telemetry.emit_room_leave(%{room_id: room_id})

    # Presence is automatically cleaned up by Phoenix.Presence
    :ok
  end

  # Private helpers

  # Viewers can read (presence, activities) but cannot write (cursors, comments, reactions)
  # nil role (no org or non-member of public room) is allowed to write for backward compat
  defp can_write?(socket), do: socket.assigns.membership_role != "viewer"

  # Load the organization for a room (nil if room has no org)
  defp load_organization(%{organization_id: nil}), do: nil

  defp load_organization(%{organization_id: org_id}) do
    Syncforge.Repo.get(Syncforge.Accounts.Organization, org_id)
  end

  # Check MAU limit — org is already loaded and cached in assigns
  defp check_connection_limit(nil), do: :ok
  defp check_connection_limit(org), do: Syncforge.Billing.can_connect?(org)

  # Check feature availability — reads org from socket assigns (no DB query)
  defp check_feature(socket, feature) do
    case socket.assigns.organization do
      nil ->
        :ok

      org ->
        if Syncforge.Billing.feature_enabled?(org, feature),
          do: :ok,
          else: {:error, :feature_not_available}
    end
  end

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

  # Serialize a reaction struct for JSON response
  defp serialize_reaction(reaction) do
    %{
      id: reaction.id,
      emoji: reaction.emoji,
      comment_id: reaction.comment_id,
      user_id: reaction.user_id,
      inserted_at: reaction.inserted_at
    }
  end

  # Create an activity record and broadcast it to the room
  defp create_and_broadcast_activity(socket, type, opts) do
    user = socket.assigns.current_user
    room_id = socket.assigns.room_id

    attrs =
      %{
        type: type,
        room_id: room_id,
        actor_id: user.id,
        subject_id: Map.get(opts, :subject_id),
        subject_type: Map.get(opts, :subject_type),
        payload: Map.get(opts, :payload, %{})
      }

    case Activity.create_activity(attrs) do
      {:ok, activity} ->
        broadcast!(socket, "activity:created", %{
          activity: Activity.serialize_activity(activity)
        })

      {:error, reason} ->
        Logger.warning("Failed to create activity: #{inspect(reason)}")
    end
  end
end

defmodule SyncforgeWeb.NotificationChannel do
  @moduledoc """
  Channel for real-time notification delivery to users.

  Each user subscribes to their own notification topic: "notification:{user_id}"
  and receives notifications in real-time as they occur.

  ## Events

  ### Server → Client
  - `notification:new` - A new notification was created
  - `notification:unread_count` - Updated unread notification count

  ### Client → Server
  - `notification:mark_read` - Mark a specific notification as read
  - `notification:mark_all_read` - Mark all notifications as read
  - `notification:list` - Get paginated list of notifications
  """

  use SyncforgeWeb, :channel

  alias Syncforge.Notifications

  require Logger

  @impl true
  def join("notification:" <> user_id, _params, socket) do
    # Users can only join their own notification channel
    if socket.assigns.user_id == user_id do
      unread_count = Notifications.count_unread(user_id)

      {:ok, %{unread_count: unread_count}, socket}
    else
      {:error, %{reason: :unauthorized}}
    end
  end

  @impl true
  def handle_in("notification:mark_read", %{"id" => notification_id}, socket) do
    user_id = socket.assigns.user_id

    case Notifications.get_notification(notification_id) do
      nil ->
        {:reply, {:error, %{reason: :not_found}}, socket}

      notification ->
        # Verify the notification belongs to this user
        if notification.user_id == user_id do
          case Notifications.mark_as_read(notification) do
            {:ok, updated} ->
              # Broadcast updated unread count
              unread_count = Notifications.count_unread(user_id)
              push(socket, "notification:unread_count", %{count: unread_count})

              {:reply, {:ok, %{notification: serialize_notification(updated)}}, socket}

            {:error, _changeset} ->
              {:reply, {:error, %{reason: :update_failed}}, socket}
          end
        else
          {:reply, {:error, %{reason: :not_found}}, socket}
        end
    end
  end

  @impl true
  def handle_in("notification:mark_all_read", _params, socket) do
    user_id = socket.assigns.user_id

    {count, _} = Notifications.mark_all_as_read(user_id)

    # Broadcast zero unread count
    push(socket, "notification:unread_count", %{count: 0})

    {:reply, {:ok, %{count: count}}, socket}
  end

  @impl true
  def handle_in("notification:list", params, socket) do
    user_id = socket.assigns.user_id
    limit = Map.get(params, "limit", 20)
    offset = Map.get(params, "offset", 0)

    notifications =
      Notifications.list_notifications(user_id, limit: limit, offset: offset)
      |> Enum.map(&serialize_notification/1)

    unread_count = Notifications.count_unread(user_id)

    {:reply, {:ok, %{notifications: notifications, total_unread: unread_count}}, socket}
  end

  @doc """
  Broadcasts a notification to the user's notification channel.

  Called by the Notifications context when a new notification is created.
  """
  def broadcast_notification(notification) do
    SyncforgeWeb.Endpoint.broadcast(
      "notification:#{notification.user_id}",
      "notification:new",
      serialize_notification(notification)
    )
  end

  # Serialize notification for JSON response
  defp serialize_notification(notification) do
    %{
      id: notification.id,
      type: notification.type,
      payload: notification.payload || %{},
      read_at: notification.read_at,
      actor_id: notification.actor_id,
      room_id: notification.room_id,
      inserted_at: notification.inserted_at
    }
  end
end

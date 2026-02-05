defmodule SyncforgeWeb.NotificationChannelTest do
  @moduledoc """
  Tests for the NotificationChannel that delivers real-time notifications to users.
  """

  use SyncforgeWeb.ChannelCase

  alias SyncforgeWeb.{NotificationChannel, UserSocket}
  alias Syncforge.Notifications

  setup do
    # Create a test user context
    user = %{
      id: Ecto.UUID.generate(),
      name: "Test User",
      avatar_url: "https://example.com/avatar.png"
    }

    {:ok, socket} =
      connect(UserSocket, %{"token" => generate_test_token(user)}, connect_info: %{})

    {:ok, socket: socket, user: user}
  end

  describe "join/3" do
    test "joins notification channel for own user_id", %{socket: socket, user: user} do
      assert {:ok, _reply, _socket} =
               subscribe_and_join(socket, NotificationChannel, "notification:#{user.id}")
    end

    test "rejects joining another user's notification channel", %{socket: socket} do
      other_user_id = Ecto.UUID.generate()

      assert {:error, %{reason: :unauthorized}} =
               subscribe_and_join(socket, NotificationChannel, "notification:#{other_user_id}")
    end

    test "returns unread count on join", %{socket: socket, user: user} do
      # Create some unread notifications for the user
      {:ok, _n1} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user.id,
          actor_id: Ecto.UUID.generate()
        })

      {:ok, _n2} =
        Notifications.create_notification(%{
          type: "comment_reply",
          user_id: user.id,
          actor_id: Ecto.UUID.generate()
        })

      {:ok, reply, _socket} =
        subscribe_and_join(socket, NotificationChannel, "notification:#{user.id}")

      assert reply.unread_count == 2
    end

    test "returns zero unread count when no notifications exist", %{socket: socket, user: user} do
      {:ok, reply, _socket} =
        subscribe_and_join(socket, NotificationChannel, "notification:#{user.id}")

      assert reply.unread_count == 0
    end
  end

  describe "receiving notifications in real-time" do
    test "receives new notification broadcast", %{socket: socket, user: user} do
      {:ok, _reply, _socket} =
        subscribe_and_join(socket, NotificationChannel, "notification:#{user.id}")

      # Create a notification which should be broadcast
      {:ok, notification} =
        Notifications.create_and_broadcast_notification(%{
          type: "comment_mention",
          user_id: user.id,
          actor_id: Ecto.UUID.generate(),
          payload: %{"comment_id" => Ecto.UUID.generate(), "message" => "mentioned you"}
        })

      # Should receive the notification via the channel
      assert_push "notification:new", payload
      assert payload.id == notification.id
      assert payload.type == "comment_mention"
      assert payload.payload["message"] == "mentioned you"
    end
  end

  describe "handle_in notification:mark_read" do
    setup %{socket: socket, user: user} do
      {:ok, _reply, socket} =
        subscribe_and_join(socket, NotificationChannel, "notification:#{user.id}")

      # Create a notification to mark as read
      {:ok, notification} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user.id,
          actor_id: Ecto.UUID.generate()
        })

      {:ok, socket: socket, user: user, notification: notification}
    end

    test "marks notification as read", %{socket: socket, notification: notification} do
      ref = push(socket, "notification:mark_read", %{"id" => notification.id})

      assert_reply ref, :ok, %{notification: updated}
      assert updated.read_at != nil
    end

    test "returns error for non-existent notification", %{socket: socket} do
      fake_id = Ecto.UUID.generate()

      ref = push(socket, "notification:mark_read", %{"id" => fake_id})

      assert_reply ref, :error, %{reason: :not_found}
    end

    test "broadcasts unread count update after marking read", %{
      socket: socket,
      notification: notification,
      user: user
    } do
      # Create another notification so we can see count change
      {:ok, _n2} =
        Notifications.create_notification(%{
          type: "comment_reply",
          user_id: user.id,
          actor_id: Ecto.UUID.generate()
        })

      ref = push(socket, "notification:mark_read", %{"id" => notification.id})
      assert_reply ref, :ok, _reply

      # Should broadcast updated unread count
      assert_push "notification:unread_count", %{count: 1}
    end
  end

  describe "handle_in notification:mark_all_read" do
    setup %{socket: socket, user: user} do
      {:ok, _reply, socket} =
        subscribe_and_join(socket, NotificationChannel, "notification:#{user.id}")

      # Create multiple notifications
      {:ok, _n1} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user.id,
          actor_id: Ecto.UUID.generate()
        })

      {:ok, _n2} =
        Notifications.create_notification(%{
          type: "comment_reply",
          user_id: user.id,
          actor_id: Ecto.UUID.generate()
        })

      {:ok, socket: socket, user: user}
    end

    test "marks all notifications as read", %{socket: socket, user: user} do
      ref = push(socket, "notification:mark_all_read", %{})

      assert_reply ref, :ok, %{count: 2}

      # Verify all are read
      unread = Notifications.list_unread_notifications(user.id)
      assert unread == []
    end

    test "broadcasts zero unread count after marking all read", %{socket: socket} do
      ref = push(socket, "notification:mark_all_read", %{})
      assert_reply ref, :ok, _reply

      assert_push "notification:unread_count", %{count: 0}
    end
  end

  describe "handle_in notification:list" do
    setup %{socket: socket, user: user} do
      {:ok, _reply, socket} =
        subscribe_and_join(socket, NotificationChannel, "notification:#{user.id}")

      # Create notifications with a small delay to ensure different timestamps
      {:ok, n1} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user.id,
          actor_id: Ecto.UUID.generate(),
          payload: %{"message" => "first"}
        })

      # Ensure n2 has a later timestamp than n1
      Process.sleep(10)

      {:ok, n2} =
        Notifications.create_notification(%{
          type: "comment_reply",
          user_id: user.id,
          actor_id: Ecto.UUID.generate(),
          payload: %{"message" => "second"}
        })

      {:ok, socket: socket, user: user, notifications: [n1, n2]}
    end

    test "returns paginated notifications", %{socket: socket, notifications: notifications} do
      ref = push(socket, "notification:list", %{"limit" => 10, "offset" => 0})

      assert_reply ref, :ok, %{notifications: list, total_unread: 2}
      assert length(list) == 2

      # Both notifications should be in the list
      [n1, n2] = notifications
      list_ids = Enum.map(list, & &1.id)
      assert n1.id in list_ids
      assert n2.id in list_ids
    end

    test "respects pagination limit", %{socket: socket} do
      ref = push(socket, "notification:list", %{"limit" => 1, "offset" => 0})

      assert_reply ref, :ok, %{notifications: list}
      assert length(list) == 1
    end

    test "respects pagination offset", %{socket: socket, notifications: [n1, n2]} do
      ref = push(socket, "notification:list", %{"limit" => 10, "offset" => 1})

      assert_reply ref, :ok, %{notifications: list}
      assert length(list) == 1

      # The returned notification should be one of the two created
      returned_id = hd(list).id
      assert returned_id == n1.id or returned_id == n2.id
    end
  end

  # Helper to generate test tokens
  defp generate_test_token(user) do
    Phoenix.Token.sign(SyncforgeWeb.Endpoint, "user socket", user)
  end
end

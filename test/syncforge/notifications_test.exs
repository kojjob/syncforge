defmodule Syncforge.NotificationsTest do
  @moduledoc """
  Tests for the Notifications context.
  """

  use Syncforge.DataCase, async: true

  alias Syncforge.Notifications
  alias Syncforge.Notifications.Notification
  alias Syncforge.Rooms

  describe "notifications" do
    setup do
      # Create a room for notification context
      {:ok, room} =
        Rooms.create_room(%{
          name: "Test Room",
          type: "general"
        })

      user_id = Ecto.UUID.generate()
      actor_id = Ecto.UUID.generate()

      %{room: room, user_id: user_id, actor_id: actor_id}
    end

    test "create_notification/1 creates a notification with valid data", %{
      room: room,
      user_id: user_id,
      actor_id: actor_id
    } do
      attrs = %{
        type: "comment_mention",
        user_id: user_id,
        actor_id: actor_id,
        room_id: room.id,
        payload: %{"comment_id" => Ecto.UUID.generate(), "body" => "Hey @user!"}
      }

      assert {:ok, %Notification{} = notification} = Notifications.create_notification(attrs)
      assert notification.type == "comment_mention"
      assert notification.user_id == user_id
      assert notification.actor_id == actor_id
      assert notification.room_id == room.id
      assert notification.read_at == nil
    end

    test "create_notification/1 returns error with missing type", %{user_id: user_id} do
      attrs = %{user_id: user_id}

      assert {:error, changeset} = Notifications.create_notification(attrs)
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_notification/1 returns error with missing user_id" do
      attrs = %{type: "comment_mention"}

      assert {:error, changeset} = Notifications.create_notification(attrs)
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_notification/1 validates notification type", %{user_id: user_id} do
      attrs = %{type: "invalid_type", user_id: user_id}

      assert {:error, changeset} = Notifications.create_notification(attrs)
      assert %{type: ["is invalid"]} = errors_on(changeset)
    end

    test "get_notification/1 returns the notification", %{user_id: user_id, actor_id: actor_id} do
      {:ok, notification} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user_id,
          actor_id: actor_id
        })

      fetched = Notifications.get_notification(notification.id)
      assert fetched.id == notification.id
      assert fetched.type == notification.type
      assert fetched.user_id == notification.user_id
      assert fetched.actor_id == notification.actor_id
    end

    test "get_notification/1 returns nil for non-existent id" do
      assert Notifications.get_notification(Ecto.UUID.generate()) == nil
    end

    test "list_notifications/1 returns all notifications for a user", %{
      user_id: user_id,
      actor_id: actor_id
    } do
      {:ok, _n1} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user_id,
          actor_id: actor_id
        })

      {:ok, _n2} =
        Notifications.create_notification(%{
          type: "comment_reply",
          user_id: user_id,
          actor_id: actor_id
        })

      # Different user's notification
      other_user_id = Ecto.UUID.generate()

      {:ok, _n3} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: other_user_id,
          actor_id: actor_id
        })

      notifications = Notifications.list_notifications(user_id)
      assert length(notifications) == 2
      assert Enum.all?(notifications, fn n -> n.user_id == user_id end)
    end

    test "list_notifications/1 returns notifications ordered by newest first", %{
      user_id: user_id,
      actor_id: actor_id
    } do
      {:ok, n1} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user_id,
          actor_id: actor_id
        })

      {:ok, n2} =
        Notifications.create_notification(%{
          type: "comment_reply",
          user_id: user_id,
          actor_id: actor_id
        })

      # Manually set timestamps to ensure n1 is older than n2
      old_time = DateTime.add(DateTime.utc_now(), -60, :second)

      Syncforge.Repo.update_all(
        from(n in Notification, where: n.id == ^n1.id),
        set: [inserted_at: old_time]
      )

      notifications = Notifications.list_notifications(user_id)
      assert hd(notifications).id == n2.id
      assert List.last(notifications).id == n1.id
    end

    test "list_unread_notifications/1 returns only unread notifications", %{
      user_id: user_id,
      actor_id: actor_id
    } do
      {:ok, _unread} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user_id,
          actor_id: actor_id
        })

      {:ok, read} =
        Notifications.create_notification(%{
          type: "comment_reply",
          user_id: user_id,
          actor_id: actor_id
        })

      # Mark one as read
      {:ok, _} = Notifications.mark_as_read(read)

      unread_notifications = Notifications.list_unread_notifications(user_id)
      assert length(unread_notifications) == 1
      assert hd(unread_notifications).read_at == nil
    end

    test "mark_as_read/1 marks notification as read", %{user_id: user_id, actor_id: actor_id} do
      {:ok, notification} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user_id,
          actor_id: actor_id
        })

      assert notification.read_at == nil

      {:ok, updated} = Notifications.mark_as_read(notification)
      assert updated.read_at != nil
    end

    test "mark_as_read/1 is idempotent", %{user_id: user_id, actor_id: actor_id} do
      {:ok, notification} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user_id,
          actor_id: actor_id
        })

      {:ok, first_read} = Notifications.mark_as_read(notification)
      original_read_at = first_read.read_at

      {:ok, second_read} = Notifications.mark_as_read(first_read)
      assert second_read.read_at == original_read_at
    end

    test "mark_all_as_read/1 marks all user notifications as read", %{
      user_id: user_id,
      actor_id: actor_id
    } do
      {:ok, _n1} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user_id,
          actor_id: actor_id
        })

      {:ok, _n2} =
        Notifications.create_notification(%{
          type: "comment_reply",
          user_id: user_id,
          actor_id: actor_id
        })

      assert {2, _} = Notifications.mark_all_as_read(user_id)

      unread = Notifications.list_unread_notifications(user_id)
      assert unread == []
    end

    test "count_unread/1 returns count of unread notifications", %{
      user_id: user_id,
      actor_id: actor_id
    } do
      {:ok, _n1} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user_id,
          actor_id: actor_id
        })

      {:ok, n2} =
        Notifications.create_notification(%{
          type: "comment_reply",
          user_id: user_id,
          actor_id: actor_id
        })

      assert Notifications.count_unread(user_id) == 2

      {:ok, _} = Notifications.mark_as_read(n2)
      assert Notifications.count_unread(user_id) == 1
    end

    test "delete_notification/1 deletes the notification", %{
      user_id: user_id,
      actor_id: actor_id
    } do
      {:ok, notification} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user_id,
          actor_id: actor_id
        })

      assert {:ok, %Notification{}} = Notifications.delete_notification(notification)
      assert Notifications.get_notification(notification.id) == nil
    end

    test "delete_old_notifications/1 deletes notifications older than given days", %{
      user_id: user_id,
      actor_id: actor_id
    } do
      # Create a recent notification
      {:ok, recent} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user_id,
          actor_id: actor_id
        })

      # Create an old notification by manipulating inserted_at
      {:ok, old} =
        Notifications.create_notification(%{
          type: "comment_reply",
          user_id: user_id,
          actor_id: actor_id
        })

      # Manually update the old notification's timestamp
      old_date = DateTime.add(DateTime.utc_now(), -31, :day)

      Syncforge.Repo.update_all(
        from(n in Notification, where: n.id == ^old.id),
        set: [inserted_at: old_date]
      )

      # Delete notifications older than 30 days
      {deleted_count, _} = Notifications.delete_old_notifications(30)
      assert deleted_count == 1

      # Recent notification should still exist
      assert Notifications.get_notification(recent.id) != nil
      # Old notification should be gone
      assert Notifications.get_notification(old.id) == nil
    end
  end

  describe "notification types" do
    setup do
      user_id = Ecto.UUID.generate()
      actor_id = Ecto.UUID.generate()
      %{user_id: user_id, actor_id: actor_id}
    end

    test "supports comment_mention type", %{user_id: user_id, actor_id: actor_id} do
      {:ok, notification} =
        Notifications.create_notification(%{
          type: "comment_mention",
          user_id: user_id,
          actor_id: actor_id,
          payload: %{"comment_id" => Ecto.UUID.generate()}
        })

      assert notification.type == "comment_mention"
    end

    test "supports comment_reply type", %{user_id: user_id, actor_id: actor_id} do
      {:ok, notification} =
        Notifications.create_notification(%{
          type: "comment_reply",
          user_id: user_id,
          actor_id: actor_id,
          payload: %{"comment_id" => Ecto.UUID.generate()}
        })

      assert notification.type == "comment_reply"
    end

    test "supports comment_resolved type", %{user_id: user_id, actor_id: actor_id} do
      {:ok, notification} =
        Notifications.create_notification(%{
          type: "comment_resolved",
          user_id: user_id,
          actor_id: actor_id
        })

      assert notification.type == "comment_resolved"
    end

    test "supports reaction_added type", %{user_id: user_id, actor_id: actor_id} do
      {:ok, notification} =
        Notifications.create_notification(%{
          type: "reaction_added",
          user_id: user_id,
          actor_id: actor_id,
          payload: %{"emoji" => "👍"}
        })

      assert notification.type == "reaction_added"
    end

    test "supports room_invite type", %{user_id: user_id, actor_id: actor_id} do
      {:ok, notification} =
        Notifications.create_notification(%{
          type: "room_invite",
          user_id: user_id,
          actor_id: actor_id
        })

      assert notification.type == "room_invite"
    end

    test "supports user_joined type", %{user_id: user_id, actor_id: actor_id} do
      {:ok, notification} =
        Notifications.create_notification(%{
          type: "user_joined",
          user_id: user_id,
          actor_id: actor_id
        })

      assert notification.type == "user_joined"
    end
  end

  describe "create_and_broadcast_notification/1" do
    setup do
      user_id = Ecto.UUID.generate()
      actor_id = Ecto.UUID.generate()
      %{user_id: user_id, actor_id: actor_id}
    end

    test "creates notification with valid data", %{user_id: user_id, actor_id: actor_id} do
      attrs = %{
        type: "comment_mention",
        user_id: user_id,
        actor_id: actor_id,
        payload: %{"message" => "mentioned you"}
      }

      assert {:ok, %Notification{} = notification} =
               Notifications.create_and_broadcast_notification(attrs)

      assert notification.type == "comment_mention"
      assert notification.user_id == user_id
      assert notification.actor_id == actor_id
      assert notification.payload["message"] == "mentioned you"
    end

    test "returns error with invalid data" do
      attrs = %{type: "invalid_type", user_id: Ecto.UUID.generate()}

      assert {:error, changeset} = Notifications.create_and_broadcast_notification(attrs)
      assert %{type: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "pagination" do
    setup do
      user_id = Ecto.UUID.generate()
      actor_id = Ecto.UUID.generate()

      # Create 15 notifications
      for i <- 1..15 do
        {:ok, _} =
          Notifications.create_notification(%{
            type: "comment_mention",
            user_id: user_id,
            actor_id: actor_id,
            payload: %{"index" => i}
          })

        Process.sleep(5)
      end

      %{user_id: user_id}
    end

    test "list_notifications/2 supports limit option", %{user_id: user_id} do
      notifications = Notifications.list_notifications(user_id, limit: 5)
      assert length(notifications) == 5
    end

    test "list_notifications/2 supports offset option", %{user_id: user_id} do
      first_page = Notifications.list_notifications(user_id, limit: 5)
      second_page = Notifications.list_notifications(user_id, limit: 5, offset: 5)

      # Pages should be different
      first_ids = Enum.map(first_page, & &1.id)
      second_ids = Enum.map(second_page, & &1.id)
      assert Enum.all?(second_ids, fn id -> id not in first_ids end)
    end

    test "list_notifications/2 returns all when no limit specified", %{user_id: user_id} do
      notifications = Notifications.list_notifications(user_id)
      assert length(notifications) == 15
    end
  end
end

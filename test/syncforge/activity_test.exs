defmodule Syncforge.ActivityTest do
  @moduledoc """
  Tests for the Activity context.
  """

  use Syncforge.DataCase, async: true

  alias Syncforge.Activity
  alias Syncforge.Activity.Activity, as: ActivitySchema
  alias Syncforge.Rooms

  describe "activities" do
    setup do
      # Create a room for activity context
      {:ok, room} =
        Rooms.create_room(%{
          name: "Test Room",
          type: "general"
        })

      actor_id = Ecto.UUID.generate()

      %{room: room, actor_id: actor_id}
    end

    test "create_activity/1 creates an activity with valid data", %{
      room: room,
      actor_id: actor_id
    } do
      attrs = %{
        type: "user_joined",
        room_id: room.id,
        actor_id: actor_id,
        payload: %{"name" => "Alice"}
      }

      assert {:ok, %ActivitySchema{} = activity} = Activity.create_activity(attrs)
      assert activity.type == "user_joined"
      assert activity.room_id == room.id
      assert activity.actor_id == actor_id
      assert activity.payload == %{"name" => "Alice"}
    end

    test "create_activity/1 returns error with missing room_id", %{actor_id: actor_id} do
      attrs = %{
        type: "user_joined",
        actor_id: actor_id
      }

      assert {:error, changeset} = Activity.create_activity(attrs)
      assert %{room_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_activity/1 returns error with invalid type", %{
      room: room,
      actor_id: actor_id
    } do
      attrs = %{
        type: "invalid_type",
        room_id: room.id,
        actor_id: actor_id
      }

      assert {:error, changeset} = Activity.create_activity(attrs)
      assert %{type: ["is invalid"]} = errors_on(changeset)
    end

    test "get_activity/1 returns the activity", %{room: room, actor_id: actor_id} do
      {:ok, activity} =
        Activity.create_activity(%{
          type: "user_joined",
          room_id: room.id,
          actor_id: actor_id
        })

      fetched = Activity.get_activity(activity.id)
      assert fetched.id == activity.id
      assert fetched.type == activity.type
      assert fetched.room_id == activity.room_id
    end

    test "get_activity/1 returns nil for non-existent id" do
      assert Activity.get_activity(Ecto.UUID.generate()) == nil
    end

    test "list_room_activities/1 returns all activities for a room", %{
      room: room,
      actor_id: actor_id
    } do
      {:ok, _a1} =
        Activity.create_activity(%{
          type: "user_joined",
          room_id: room.id,
          actor_id: actor_id
        })

      {:ok, _a2} =
        Activity.create_activity(%{
          type: "comment_created",
          room_id: room.id,
          actor_id: actor_id,
          subject_id: Ecto.UUID.generate(),
          subject_type: "comment"
        })

      # Different room's activity
      {:ok, other_room} =
        Rooms.create_room(%{
          name: "Other Room",
          type: "general"
        })

      {:ok, _a3} =
        Activity.create_activity(%{
          type: "user_joined",
          room_id: other_room.id,
          actor_id: actor_id
        })

      activities = Activity.list_room_activities(room.id)
      assert length(activities) == 2
      assert Enum.all?(activities, fn a -> a.room_id == room.id end)
    end

    test "list_room_activities/1 returns activities ordered by newest first", %{
      room: room,
      actor_id: actor_id
    } do
      {:ok, a1} =
        Activity.create_activity(%{
          type: "user_joined",
          room_id: room.id,
          actor_id: actor_id
        })

      {:ok, a2} =
        Activity.create_activity(%{
          type: "comment_created",
          room_id: room.id,
          actor_id: actor_id
        })

      # Manually set timestamps to ensure a1 is older than a2
      old_time = DateTime.add(DateTime.utc_now(), -60, :second)

      Syncforge.Repo.update_all(
        from(a in ActivitySchema, where: a.id == ^a1.id),
        set: [inserted_at: old_time]
      )

      activities = Activity.list_room_activities(room.id)
      assert hd(activities).id == a2.id
      assert List.last(activities).id == a1.id
    end

    test "list_room_activities/2 supports limit option", %{room: room, actor_id: actor_id} do
      # Create 15 activities
      for i <- 1..15 do
        {:ok, _} =
          Activity.create_activity(%{
            type: "comment_created",
            room_id: room.id,
            actor_id: actor_id,
            payload: %{"index" => i}
          })

        Process.sleep(5)
      end

      activities = Activity.list_room_activities(room.id, limit: 5)
      assert length(activities) == 5
    end

    test "list_room_activities/2 supports offset option", %{room: room, actor_id: actor_id} do
      # Create 15 activities
      for i <- 1..15 do
        {:ok, _} =
          Activity.create_activity(%{
            type: "comment_created",
            room_id: room.id,
            actor_id: actor_id,
            payload: %{"index" => i}
          })

        Process.sleep(5)
      end

      first_page = Activity.list_room_activities(room.id, limit: 5)
      second_page = Activity.list_room_activities(room.id, limit: 5, offset: 5)

      # Pages should be different
      first_ids = Enum.map(first_page, & &1.id)
      second_ids = Enum.map(second_page, & &1.id)
      assert Enum.all?(second_ids, fn id -> id not in first_ids end)
    end

    test "delete_old_activities/1 deletes activities older than given days", %{
      room: room,
      actor_id: actor_id
    } do
      # Create a recent activity
      {:ok, recent} =
        Activity.create_activity(%{
          type: "user_joined",
          room_id: room.id,
          actor_id: actor_id
        })

      # Create an old activity
      {:ok, old} =
        Activity.create_activity(%{
          type: "comment_created",
          room_id: room.id,
          actor_id: actor_id
        })

      # Manually update the old activity's timestamp
      old_date = DateTime.add(DateTime.utc_now(), -31, :day)

      Syncforge.Repo.update_all(
        from(a in ActivitySchema, where: a.id == ^old.id),
        set: [inserted_at: old_date]
      )

      # Delete activities older than 30 days
      {deleted_count, _} = Activity.delete_old_activities(30)
      assert deleted_count == 1

      # Recent activity should still exist
      assert Activity.get_activity(recent.id) != nil
      # Old activity should be gone
      assert Activity.get_activity(old.id) == nil
    end
  end

  describe "activity types" do
    setup do
      {:ok, room} =
        Rooms.create_room(%{
          name: "Test Room",
          type: "general"
        })

      actor_id = Ecto.UUID.generate()
      %{room: room, actor_id: actor_id}
    end

    test "supports user_joined type", %{room: room, actor_id: actor_id} do
      {:ok, activity} =
        Activity.create_activity(%{
          type: "user_joined",
          room_id: room.id,
          actor_id: actor_id,
          payload: %{"name" => "Alice"}
        })

      assert activity.type == "user_joined"
    end

    test "supports user_left type", %{room: room, actor_id: actor_id} do
      {:ok, activity} =
        Activity.create_activity(%{
          type: "user_left",
          room_id: room.id,
          actor_id: actor_id
        })

      assert activity.type == "user_left"
    end

    test "supports comment_created type", %{room: room, actor_id: actor_id} do
      {:ok, activity} =
        Activity.create_activity(%{
          type: "comment_created",
          room_id: room.id,
          actor_id: actor_id,
          subject_id: Ecto.UUID.generate(),
          subject_type: "comment",
          payload: %{"body_preview" => "Test comment..."}
        })

      assert activity.type == "comment_created"
    end

    test "supports comment_resolved type", %{room: room, actor_id: actor_id} do
      {:ok, activity} =
        Activity.create_activity(%{
          type: "comment_resolved",
          room_id: room.id,
          actor_id: actor_id,
          subject_id: Ecto.UUID.generate(),
          subject_type: "comment"
        })

      assert activity.type == "comment_resolved"
    end

    test "supports comment_deleted type", %{room: room, actor_id: actor_id} do
      {:ok, activity} =
        Activity.create_activity(%{
          type: "comment_deleted",
          room_id: room.id,
          actor_id: actor_id,
          subject_id: Ecto.UUID.generate(),
          subject_type: "comment"
        })

      assert activity.type == "comment_deleted"
    end

    test "supports reaction_added type", %{room: room, actor_id: actor_id} do
      {:ok, activity} =
        Activity.create_activity(%{
          type: "reaction_added",
          room_id: room.id,
          actor_id: actor_id,
          subject_id: Ecto.UUID.generate(),
          subject_type: "comment",
          payload: %{"emoji" => "👍"}
        })

      assert activity.type == "reaction_added"
    end

    test "supports reaction_removed type", %{room: room, actor_id: actor_id} do
      {:ok, activity} =
        Activity.create_activity(%{
          type: "reaction_removed",
          room_id: room.id,
          actor_id: actor_id,
          subject_id: Ecto.UUID.generate(),
          subject_type: "comment",
          payload: %{"emoji" => "👍"}
        })

      assert activity.type == "reaction_removed"
    end
  end
end

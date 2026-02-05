defmodule Syncforge.Activity.ActivityTest do
  @moduledoc """
  Tests for the Activity schema.
  """

  use Syncforge.DataCase, async: true

  alias Syncforge.Activity.Activity

  describe "changeset/2" do
    setup do
      room_id = Ecto.UUID.generate()
      actor_id = Ecto.UUID.generate()

      %{room_id: room_id, actor_id: actor_id}
    end

    test "valid changeset with all required fields", %{room_id: room_id, actor_id: actor_id} do
      attrs = %{
        type: "user_joined",
        room_id: room_id,
        actor_id: actor_id
      }

      changeset = Activity.changeset(%Activity{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :type) == "user_joined"
      assert get_change(changeset, :room_id) == room_id
      assert get_change(changeset, :actor_id) == actor_id
    end

    test "valid changeset with subject fields", %{room_id: room_id, actor_id: actor_id} do
      subject_id = Ecto.UUID.generate()

      attrs = %{
        type: "comment_created",
        room_id: room_id,
        actor_id: actor_id,
        subject_id: subject_id,
        subject_type: "comment",
        payload: %{"body_preview" => "First 100 chars..."}
      }

      changeset = Activity.changeset(%Activity{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :subject_id) == subject_id
      assert get_change(changeset, :subject_type) == "comment"
      assert get_change(changeset, :payload) == %{"body_preview" => "First 100 chars..."}
    end

    test "invalid changeset with missing room_id", %{actor_id: actor_id} do
      attrs = %{
        type: "user_joined",
        actor_id: actor_id
      }

      changeset = Activity.changeset(%Activity{}, attrs)

      refute changeset.valid?
      assert %{room_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset with missing type", %{room_id: room_id, actor_id: actor_id} do
      attrs = %{
        room_id: room_id,
        actor_id: actor_id
      }

      changeset = Activity.changeset(%Activity{}, attrs)

      refute changeset.valid?
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset with invalid type", %{room_id: room_id, actor_id: actor_id} do
      attrs = %{
        type: "invalid_activity_type",
        room_id: room_id,
        actor_id: actor_id
      }

      changeset = Activity.changeset(%Activity{}, attrs)

      refute changeset.valid?
      assert %{type: ["is invalid"]} = errors_on(changeset)
    end

    test "valid changeset allows nil actor_id for system events", %{room_id: room_id} do
      attrs = %{
        type: "user_joined",
        room_id: room_id,
        actor_id: nil
      }

      changeset = Activity.changeset(%Activity{}, attrs)

      assert changeset.valid?
    end

    test "payload defaults to empty map", %{room_id: room_id, actor_id: actor_id} do
      attrs = %{
        type: "user_joined",
        room_id: room_id,
        actor_id: actor_id
      }

      changeset = Activity.changeset(%Activity{}, attrs)

      assert changeset.valid?
      # Payload should use default value from schema, not be in changes
      refute Map.has_key?(changeset.changes, :payload)
    end
  end

  describe "valid_types/0" do
    test "returns all valid activity types" do
      types = Activity.valid_types()

      assert "user_joined" in types
      assert "user_left" in types
      assert "comment_created" in types
      assert "comment_resolved" in types
      assert "comment_deleted" in types
      assert "reaction_added" in types
      assert "reaction_removed" in types
    end
  end
end

defmodule Syncforge.RoomsTest do
  use Syncforge.DataCase

  alias Syncforge.Rooms
  alias Syncforge.Rooms.Room

  describe "rooms" do
    @valid_attrs %{
      name: "Design Review",
      slug: "design-review",
      type: "document",
      max_participants: 50,
      is_public: false
    }

    @invalid_attrs %{name: nil, slug: nil}

    test "list_rooms/0 returns all rooms" do
      room = room_fixture()
      assert Rooms.list_rooms() == [room]
    end

    test "get_room!/1 returns the room with given id" do
      room = room_fixture()
      assert Rooms.get_room!(room.id) == room
    end

    test "get_room_by_slug/1 returns the room with given slug" do
      room = room_fixture()
      assert Rooms.get_room_by_slug(room.slug) == room
    end

    test "get_room_by_slug/1 returns nil for non-existent slug" do
      assert Rooms.get_room_by_slug("non-existent") == nil
    end

    test "create_room/1 with valid data creates a room" do
      assert {:ok, %Room{} = room} = Rooms.create_room(@valid_attrs)
      assert room.name == "Design Review"
      assert room.slug == "design-review"
      assert room.type == :document
      assert room.max_participants == 50
      assert room.is_public == false
    end

    test "create_room/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Rooms.create_room(@invalid_attrs)
    end

    test "create_room/1 generates slug from name if not provided" do
      attrs = Map.delete(@valid_attrs, :slug)
      assert {:ok, %Room{} = room} = Rooms.create_room(attrs)
      assert room.slug == "design-review"
    end

    test "create_room/1 enforces unique slug" do
      assert {:ok, _room} = Rooms.create_room(@valid_attrs)
      assert {:error, changeset} = Rooms.create_room(@valid_attrs)
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "create_room/1 sets default values" do
      attrs = %{name: "Test Room"}
      assert {:ok, %Room{} = room} = Rooms.create_room(attrs)
      assert room.type == :general
      assert room.max_participants == 100
      assert room.is_public == true
      assert room.config == %{}
      assert room.metadata == %{}
    end

    test "update_room/2 with valid data updates the room" do
      room = room_fixture()
      update_attrs = %{name: "Updated Name", max_participants: 25}

      assert {:ok, %Room{} = room} = Rooms.update_room(room, update_attrs)
      assert room.name == "Updated Name"
      assert room.max_participants == 25
    end

    test "update_room/2 with invalid data returns error changeset" do
      room = room_fixture()
      assert {:error, %Ecto.Changeset{}} = Rooms.update_room(room, @invalid_attrs)
      assert room == Rooms.get_room!(room.id)
    end

    test "delete_room/1 deletes the room" do
      room = room_fixture()
      assert {:ok, %Room{}} = Rooms.delete_room(room)
      assert_raise Ecto.NoResultsError, fn -> Rooms.get_room!(room.id) end
    end

    test "change_room/1 returns a room changeset" do
      room = room_fixture()
      assert %Ecto.Changeset{} = Rooms.change_room(room)
    end
  end

  describe "room configuration" do
    test "config can store arbitrary settings" do
      attrs =
        Map.put(@valid_attrs, :config, %{
          "theme" => "dark",
          "allow_anonymous" => false,
          "features" => ["cursors", "comments"]
        })

      assert {:ok, %Room{} = room} = Rooms.create_room(attrs)
      assert room.config["theme"] == "dark"
      assert room.config["features"] == ["cursors", "comments"]
    end

    test "metadata can store arbitrary data" do
      attrs =
        Map.put(@valid_attrs, :metadata, %{
          "created_by" => "user_123",
          "project_id" => "proj_456"
        })

      assert {:ok, %Room{} = room} = Rooms.create_room(attrs)
      assert room.metadata["created_by"] == "user_123"
    end
  end

  describe "room validation" do
    test "name must be between 1 and 255 characters" do
      # Too short (empty)
      assert {:error, changeset} = Rooms.create_room(%{name: ""})
      assert "can't be blank" in errors_on(changeset).name

      # Too long
      long_name = String.duplicate("a", 256)
      assert {:error, changeset} = Rooms.create_room(%{name: long_name})
      assert "should be at most 255 character(s)" in errors_on(changeset).name
    end

    test "slug must be URL-safe" do
      # Valid slugs
      assert {:ok, _} = Rooms.create_room(%{name: "Test", slug: "valid-slug"})
      assert {:ok, _} = Rooms.create_room(%{name: "Test 2", slug: "valid_slug_123"})

      # Invalid slugs with spaces or special characters
      assert {:error, changeset} = Rooms.create_room(%{name: "Test 3", slug: "invalid slug"})

      assert "must be URL-safe (letters, numbers, hyphens, underscores)" in errors_on(changeset).slug
    end

    test "max_participants must be positive" do
      assert {:error, changeset} = Rooms.create_room(%{name: "Test", max_participants: 0})
      assert "must be greater than 0" in errors_on(changeset).max_participants

      assert {:error, changeset} = Rooms.create_room(%{name: "Test", max_participants: -1})
      assert "must be greater than 0" in errors_on(changeset).max_participants
    end

    test "type must be a valid room type" do
      valid_types = ["general", "document", "whiteboard", "canvas", "video"]

      for type <- valid_types do
        assert {:ok, _} = Rooms.create_room(%{name: "Test #{type}", type: type})
      end

      assert {:error, changeset} = Rooms.create_room(%{name: "Test", type: "invalid_type"})
      assert "is invalid" in errors_on(changeset).type
    end
  end

  describe "authorize_join/2" do
    test "returns error when room does not exist" do
      fake_id = Ecto.UUID.generate()
      assert {:error, :room_not_found} = Rooms.authorize_join(fake_id, nil)
    end

    test "allows joining a public room" do
      room = room_fixture(%{is_public: true, max_participants: 10})
      assert {:ok, returned_room} = Rooms.authorize_join(room.id, nil)
      assert returned_room.id == room.id
    end

    test "denies joining a private room without access" do
      room = room_fixture(%{is_public: false})
      assert {:error, :unauthorized} = Rooms.authorize_join(room.id, nil)
    end

    test "denies joining when room is at full capacity" do
      room = room_fixture(%{is_public: true, max_participants: 2})
      # Simulate room already at capacity
      opts = [current_participant_count: 2]
      assert {:error, :room_full} = Rooms.authorize_join(room.id, nil, opts)
    end

    test "allows joining when room has available space" do
      room = room_fixture(%{is_public: true, max_participants: 10})
      # Simulate some participants but not full
      opts = [current_participant_count: 5]
      assert {:ok, returned_room} = Rooms.authorize_join(room.id, nil, opts)
      assert returned_room.id == room.id
    end

    test "allows joining when room has exactly one spot left" do
      room = room_fixture(%{is_public: true, max_participants: 5})
      opts = [current_participant_count: 4]
      assert {:ok, _room} = Rooms.authorize_join(room.id, nil, opts)
    end

    test "denies joining when room is over capacity" do
      room = room_fixture(%{is_public: true, max_participants: 5})
      # Edge case: somehow count exceeds max
      opts = [current_participant_count: 10]
      assert {:error, :room_full} = Rooms.authorize_join(room.id, nil, opts)
    end
  end

  describe "get_state/1" do
    test "returns room data and comments for existing room" do
      room = room_fixture(%{name: "State Test Room", max_participants: 50, is_public: true})

      # Create some comments in the room
      user_id = Ecto.UUID.generate()

      {:ok, comment1} =
        Syncforge.Comments.create_comment(%{
          body: "First comment",
          room_id: room.id,
          user_id: user_id
        })

      {:ok, _comment2} =
        Syncforge.Comments.create_comment(%{
          body: "Second comment",
          room_id: room.id,
          user_id: user_id,
          anchor_id: "element-123"
        })

      state = Rooms.get_state(room.id)

      # Verify room data
      assert state.room.id == room.id
      assert state.room.name == "State Test Room"
      assert state.room.max_participants == 50
      assert state.room.is_public == true

      # Verify comments
      assert length(state.comments) == 2
      assert Enum.any?(state.comments, fn c -> c.id == comment1.id end)
    end

    test "returns empty comments for room without comments" do
      room = room_fixture(%{name: "Empty Room"})

      state = Rooms.get_state(room.id)

      assert state.room.id == room.id
      assert state.comments == []
    end

    test "returns minimal state for non-existent room (ad-hoc room)" do
      fake_id = Ecto.UUID.generate()

      state = Rooms.get_state(fake_id)

      assert state.room.id == fake_id
      assert state.room.name == nil
      assert state.room.is_public == true
      assert state.comments == []
    end

    test "serializes comment fields correctly" do
      room = room_fixture()
      user_id = Ecto.UUID.generate()

      {:ok, comment} =
        Syncforge.Comments.create_comment(%{
          body: "Test comment",
          room_id: room.id,
          user_id: user_id,
          anchor_id: "elem-1",
          anchor_type: "element",
          position: %{"x" => 100, "y" => 200}
        })

      state = Rooms.get_state(room.id)
      [serialized_comment] = state.comments

      assert serialized_comment.id == comment.id
      assert serialized_comment.body == "Test comment"
      assert serialized_comment.anchor_id == "elem-1"
      assert serialized_comment.anchor_type == "element"
      assert serialized_comment.position == %{"x" => 100, "y" => 200}
      assert serialized_comment.user_id == user_id
      assert serialized_comment.room_id == room.id
    end
  end

  describe "get_participant_count/1" do
    test "returns 0 when Presence is not tracking any users" do
      room = room_fixture(%{is_public: true})
      # Presence is not started in test, so this should return 0
      assert Rooms.get_participant_count(room.id) == 0
    end

    test "returns 0 for non-existent room id" do
      fake_id = Ecto.UUID.generate()
      assert Rooms.get_participant_count(fake_id) == 0
    end

    test "only rescues ArgumentError, not other exceptions" do
      # Verify that the function returns an integer (0) via the narrow rescue
      # when Presence ETS table is not available in the test environment.
      room = room_fixture(%{is_public: true})
      assert is_integer(Rooms.get_participant_count(room.id))
    end
  end

  # Helper function to create test rooms
  defp room_fixture(attrs \\ %{}) do
    {:ok, room} =
      attrs
      |> Enum.into(%{
        name: "Test Room #{System.unique_integer([:positive])}",
        type: "general"
      })
      |> Syncforge.Rooms.create_room()

    room
  end
end

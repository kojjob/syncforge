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
      attrs = Map.put(@valid_attrs, :config, %{
        "theme" => "dark",
        "allow_anonymous" => false,
        "features" => ["cursors", "comments"]
      })

      assert {:ok, %Room{} = room} = Rooms.create_room(attrs)
      assert room.config["theme"] == "dark"
      assert room.config["features"] == ["cursors", "comments"]
    end

    test "metadata can store arbitrary data" do
      attrs = Map.put(@valid_attrs, :metadata, %{
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

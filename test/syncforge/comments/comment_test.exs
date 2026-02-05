defmodule Syncforge.Comments.CommentTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Comments.Comment
  alias Syncforge.Rooms.Room

  describe "schema" do
    test "has expected fields" do
      fields = Comment.__schema__(:fields)

      assert :id in fields
      assert :body in fields
      assert :anchor_id in fields
      assert :anchor_type in fields
      assert :position in fields
      assert :resolved_at in fields
      assert :room_id in fields
      assert :user_id in fields
      assert :parent_id in fields
      assert :inserted_at in fields
      assert :updated_at in fields
    end

    test "uses binary_id for primary key" do
      assert Comment.__schema__(:primary_key) == [:id]
      assert Comment.__schema__(:type, :id) == :binary_id
    end

    test "has association to room" do
      assocs = Comment.__schema__(:associations)
      assert :room in assocs
    end

    test "has self-referential association for threading" do
      assocs = Comment.__schema__(:associations)
      assert :parent in assocs
      assert :replies in assocs
    end
  end

  describe "create_changeset/2" do
    setup do
      {:ok, room} =
        %Room{}
        |> Room.create_changeset(%{name: "Test Room"})
        |> Syncforge.Repo.insert()

      user_id = Ecto.UUID.generate()

      %{room: room, user_id: user_id}
    end

    test "valid with required fields", %{room: room, user_id: user_id} do
      attrs = %{
        body: "This is a comment",
        room_id: room.id,
        user_id: user_id
      }

      changeset = Comment.create_changeset(%Comment{}, attrs)

      assert changeset.valid?
    end

    test "valid with all fields", %{room: room, user_id: user_id} do
      attrs = %{
        body: "This is a comment",
        anchor_id: "element-123",
        anchor_type: "element",
        position: %{"x" => 100, "y" => 200},
        room_id: room.id,
        user_id: user_id
      }

      changeset = Comment.create_changeset(%Comment{}, attrs)

      assert changeset.valid?
    end

    test "invalid without body", %{room: room, user_id: user_id} do
      attrs = %{
        room_id: room.id,
        user_id: user_id
      }

      changeset = Comment.create_changeset(%Comment{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).body
    end

    test "invalid without room_id", %{user_id: user_id} do
      attrs = %{
        body: "This is a comment",
        user_id: user_id
      }

      changeset = Comment.create_changeset(%Comment{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).room_id
    end

    test "invalid without user_id", %{room: room} do
      attrs = %{
        body: "This is a comment",
        room_id: room.id
      }

      changeset = Comment.create_changeset(%Comment{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "validates body length", %{room: room, user_id: user_id} do
      # Empty body
      attrs = %{body: "", room_id: room.id, user_id: user_id}
      changeset = Comment.create_changeset(%Comment{}, attrs)
      refute changeset.valid?

      # Very long body (over 10000 chars)
      long_body = String.duplicate("a", 10001)
      attrs = %{body: long_body, room_id: room.id, user_id: user_id}
      changeset = Comment.create_changeset(%Comment{}, attrs)
      refute changeset.valid?
    end

    test "validates anchor_type inclusion", %{room: room, user_id: user_id} do
      valid_types = ["element", "selection", "point"]

      for type <- valid_types do
        attrs = %{body: "Comment", anchor_type: type, room_id: room.id, user_id: user_id}
        changeset = Comment.create_changeset(%Comment{}, attrs)
        assert changeset.valid?, "Expected #{type} to be valid"
      end

      # Invalid type
      attrs = %{body: "Comment", anchor_type: "invalid", room_id: room.id, user_id: user_id}
      changeset = Comment.create_changeset(%Comment{}, attrs)
      refute changeset.valid?
    end

    test "can set parent_id for threading", %{room: room, user_id: user_id} do
      # Create parent comment
      {:ok, parent} =
        %Comment{}
        |> Comment.create_changeset(%{body: "Parent comment", room_id: room.id, user_id: user_id})
        |> Syncforge.Repo.insert()

      # Create reply
      attrs = %{
        body: "This is a reply",
        room_id: room.id,
        user_id: user_id,
        parent_id: parent.id
      }

      changeset = Comment.create_changeset(%Comment{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :parent_id) == parent.id
    end
  end

  describe "update_changeset/2" do
    setup do
      {:ok, room} =
        %Room{}
        |> Room.create_changeset(%{name: "Test Room"})
        |> Syncforge.Repo.insert()

      user_id = Ecto.UUID.generate()

      {:ok, comment} =
        %Comment{}
        |> Comment.create_changeset(%{
          body: "Original comment",
          room_id: room.id,
          user_id: user_id
        })
        |> Syncforge.Repo.insert()

      %{comment: comment, room: room, user_id: user_id}
    end

    test "can update body", %{comment: comment} do
      changeset = Comment.update_changeset(comment, %{body: "Updated comment"})

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :body) == "Updated comment"
    end

    test "can update anchor fields", %{comment: comment} do
      attrs = %{
        anchor_id: "new-element-456",
        anchor_type: "selection",
        position: %{"start" => 0, "end" => 10}
      }

      changeset = Comment.update_changeset(comment, attrs)

      assert changeset.valid?
    end

    test "cannot change room_id", %{comment: comment} do
      new_room_id = Ecto.UUID.generate()
      changeset = Comment.update_changeset(comment, %{room_id: new_room_id})

      # room_id should not be in the changes
      refute Map.has_key?(changeset.changes, :room_id)
    end

    test "cannot change user_id", %{comment: comment} do
      new_user_id = Ecto.UUID.generate()
      changeset = Comment.update_changeset(comment, %{user_id: new_user_id})

      # user_id should not be in the changes
      refute Map.has_key?(changeset.changes, :user_id)
    end
  end

  describe "resolve_changeset/2" do
    setup do
      {:ok, room} =
        %Room{}
        |> Room.create_changeset(%{name: "Test Room"})
        |> Syncforge.Repo.insert()

      user_id = Ecto.UUID.generate()

      {:ok, comment} =
        %Comment{}
        |> Comment.create_changeset(%{body: "A comment", room_id: room.id, user_id: user_id})
        |> Syncforge.Repo.insert()

      %{comment: comment}
    end

    test "sets resolved_at timestamp", %{comment: comment} do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      changeset = Comment.resolve_changeset(comment, now)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :resolved_at) == now
    end

    test "can unresolve by setting to nil", %{comment: comment} do
      # First resolve
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, resolved_comment} =
        comment
        |> Comment.resolve_changeset(now)
        |> Syncforge.Repo.update()

      assert resolved_comment.resolved_at == now

      # Then unresolve
      changeset = Comment.resolve_changeset(resolved_comment, nil)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :resolved_at) == nil
    end
  end

  describe "database constraints" do
    setup do
      {:ok, room} =
        %Room{}
        |> Room.create_changeset(%{name: "Test Room"})
        |> Syncforge.Repo.insert()

      user_id = Ecto.UUID.generate()

      %{room: room, user_id: user_id}
    end

    test "enforces foreign key constraint for room_id", %{user_id: user_id} do
      fake_room_id = Ecto.UUID.generate()

      result =
        %Comment{}
        |> Comment.create_changeset(%{body: "Comment", room_id: fake_room_id, user_id: user_id})
        |> Syncforge.Repo.insert()

      assert {:error, changeset} = result
      assert "does not exist" in errors_on(changeset).room_id
    end

    test "enforces foreign key constraint for parent_id", %{room: room, user_id: user_id} do
      fake_parent_id = Ecto.UUID.generate()

      result =
        %Comment{}
        |> Comment.create_changeset(%{
          body: "Reply",
          room_id: room.id,
          user_id: user_id,
          parent_id: fake_parent_id
        })
        |> Syncforge.Repo.insert()

      assert {:error, changeset} = result
      assert "does not exist" in errors_on(changeset).parent_id
    end

    test "deletes replies when parent is deleted", %{room: room, user_id: user_id} do
      # Create parent
      {:ok, parent} =
        %Comment{}
        |> Comment.create_changeset(%{body: "Parent", room_id: room.id, user_id: user_id})
        |> Syncforge.Repo.insert()

      # Create reply
      {:ok, _reply} =
        %Comment{}
        |> Comment.create_changeset(%{
          body: "Reply",
          room_id: room.id,
          user_id: user_id,
          parent_id: parent.id
        })
        |> Syncforge.Repo.insert()

      # Delete parent - reply should be cascade deleted
      Syncforge.Repo.delete!(parent)

      # Verify no comments remain
      assert Syncforge.Repo.all(Comment) == []
    end
  end
end

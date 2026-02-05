defmodule SyncforgeWeb.RoomChannelTest do
  use SyncforgeWeb.ChannelCase

  alias SyncforgeWeb.{RoomChannel, UserSocket}

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
    test "joins room successfully with valid token", %{socket: socket} do
      room_id = Ecto.UUID.generate()

      assert {:ok, _reply, _socket} =
               subscribe_and_join(socket, RoomChannel, "room:#{room_id}")
    end

    test "assigns room_id to socket", %{socket: socket} do
      room_id = Ecto.UUID.generate()

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room_id}")

      assert socket.assigns.room_id == room_id
    end

    test "tracks presence on join", %{socket: socket, user: user} do
      room_id = Ecto.UUID.generate()

      {:ok, _reply, _socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room_id}")

      # Give presence time to sync
      Process.sleep(50)

      presence = SyncforgeWeb.Presence.list("room:#{room_id}")
      assert Map.has_key?(presence, user.id)
    end

    test "receives presence_state after join", %{socket: socket} do
      room_id = Ecto.UUID.generate()

      {:ok, reply, _socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room_id}")

      assert Map.has_key?(reply, :presence)
    end
  end

  describe "handle_in cursor:update" do
    test "broadcasts cursor position to other clients", %{socket: socket} do
      room_id = Ecto.UUID.generate()

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room_id}")

      push(socket, "cursor:update", %{"x" => 100, "y" => 200})

      # Should broadcast to others (not self due to broadcast_from)
      # In test, we verify the message was handled without error
      assert_broadcast "cursor:update", %{x: 100, y: 200, user_id: _}
    end

    test "includes user_id in cursor broadcast", %{socket: socket, user: user} do
      room_id = Ecto.UUID.generate()

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room_id}")

      push(socket, "cursor:update", %{"x" => 50, "y" => 75})

      assert_broadcast "cursor:update", payload
      assert payload.user_id == user.id
      assert payload.x == 50
      assert payload.y == 75
    end

    test "includes user name for cursor label", %{socket: socket, user: user} do
      room_id = Ecto.UUID.generate()

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room_id}")

      push(socket, "cursor:update", %{"x" => 100, "y" => 200})

      assert_broadcast "cursor:update", payload
      assert payload.name == user.name
    end

    test "includes cursor color when user has one", %{socket: _socket} do
      # Create user with a cursor color
      user_with_color = %{
        id: Ecto.UUID.generate(),
        name: "Colored User",
        avatar_url: "https://example.com/avatar.png",
        cursor_color: "#FF5733"
      }

      {:ok, socket_with_color} =
        connect(UserSocket, %{"token" => generate_test_token(user_with_color)}, connect_info: %{})

      room_id = Ecto.UUID.generate()

      {:ok, _reply, socket_with_color} =
        subscribe_and_join(socket_with_color, RoomChannel, "room:#{room_id}")

      push(socket_with_color, "cursor:update", %{"x" => 100, "y" => 200})

      assert_broadcast "cursor:update", payload
      assert payload.color == "#FF5733"
    end

    test "uses default color when user has no cursor_color", %{socket: socket} do
      room_id = Ecto.UUID.generate()

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room_id}")

      push(socket, "cursor:update", %{"x" => 100, "y" => 200})

      assert_broadcast "cursor:update", payload
      # Should have a default color
      assert is_binary(payload.color)
      assert String.starts_with?(payload.color, "#")
    end

    test "includes optional element_id when provided", %{socket: socket} do
      room_id = Ecto.UUID.generate()

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room_id}")

      push(socket, "cursor:update", %{"x" => 100, "y" => 200, "element_id" => "editor-panel"})

      assert_broadcast "cursor:update", payload
      assert payload.element_id == "editor-panel"
    end
  end

  describe "handle_in presence:update" do
    test "updates user presence metadata", %{socket: socket} do
      room_id = Ecto.UUID.generate()

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room_id}")

      push(socket, "presence:update", %{"status" => "typing"})

      # Give presence time to update
      Process.sleep(50)

      # Presence update should be processed without error
      refute_receive {:error, _}
    end
  end

  describe "terminate/2" do
    test "cleans up presence on disconnect", %{socket: socket, user: user} do
      room_id = Ecto.UUID.generate()

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room_id}")

      # Give presence time to track
      Process.sleep(50)

      # Verify user is tracked
      presence = SyncforgeWeb.Presence.list("room:#{room_id}")
      assert Map.has_key?(presence, user.id)

      # Get the channel pid before leaving
      channel_pid = socket.channel_pid

      # Unlink from the channel process to prevent test crash on :left
      Process.unlink(channel_pid)

      # Leave the channel - this will cause the channel to terminate
      leave(socket)

      # Give presence time to untrack
      Process.sleep(100)

      # Verify user is no longer tracked
      presence = SyncforgeWeb.Presence.list("room:#{room_id}")
      refute Map.has_key?(presence, user.id)
    end
  end

  describe "handle_in comment:create" do
    setup %{socket: socket, user: user} do
      # Create a room in the database for comments to belong to
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Test Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      {:ok, socket: socket, user: user, room: room}
    end

    test "creates comment and broadcasts to room", %{socket: socket, user: user, room: room} do
      comment_attrs = %{
        "body" => "This is a test comment",
        "anchor_id" => "element-123",
        "anchor_type" => "element"
      }

      ref = push(socket, "comment:create", comment_attrs)

      # Should reply with the created comment
      assert_reply ref, :ok, %{comment: comment}
      assert comment.body == "This is a test comment"
      assert comment.anchor_id == "element-123"
      assert comment.anchor_type == "element"
      assert comment.user_id == user.id
      assert comment.room_id == room.id

      # Should broadcast the new comment to all room members
      assert_broadcast "comment:created", %{comment: broadcast_comment}
      assert broadcast_comment.body == "This is a test comment"
      assert broadcast_comment.user_id == user.id
    end

    test "creates threaded reply comment", %{socket: socket, user: _user, room: _room} do
      # First create a parent comment
      parent_attrs = %{"body" => "Parent comment"}
      ref = push(socket, "comment:create", parent_attrs)
      assert_reply ref, :ok, %{comment: parent}

      # Clear the broadcast from parent creation
      assert_broadcast "comment:created", _parent_broadcast

      # Create a reply
      reply_attrs = %{
        "body" => "This is a reply",
        "parent_id" => parent.id
      }

      ref = push(socket, "comment:create", reply_attrs)
      assert_reply ref, :ok, %{comment: reply}
      assert reply.parent_id == parent.id
      assert reply.body == "This is a reply"
    end

    test "returns error for invalid comment", %{socket: socket} do
      # Empty body should fail validation
      invalid_attrs = %{"body" => ""}

      ref = push(socket, "comment:create", invalid_attrs)

      assert_reply ref, :error, %{errors: errors}
      assert errors != %{}
    end

    test "includes position data when provided", %{socket: socket} do
      comment_attrs = %{
        "body" => "Positioned comment",
        "anchor_type" => "point",
        "position" => %{"x" => 100, "y" => 200}
      }

      ref = push(socket, "comment:create", comment_attrs)
      assert_reply ref, :ok, %{comment: comment}
      assert comment.position == %{"x" => 100, "y" => 200}
    end
  end

  describe "handle_in comment:update" do
    setup %{socket: socket, user: user} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Test Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      # Create a comment to update
      {:ok, comment} =
        Syncforge.Comments.create_comment(%{
          body: "Original body",
          room_id: room.id,
          user_id: user.id
        })

      {:ok, socket: socket, user: user, room: room, comment: comment}
    end

    test "updates comment body and broadcasts", %{socket: socket, comment: comment} do
      update_attrs = %{
        "id" => comment.id,
        "body" => "Updated body"
      }

      ref = push(socket, "comment:update", update_attrs)

      assert_reply ref, :ok, %{comment: updated}
      assert updated.body == "Updated body"
      assert updated.id == comment.id

      # Should broadcast the update
      assert_broadcast "comment:updated", %{comment: broadcast_comment}
      assert broadcast_comment.body == "Updated body"
    end

    test "updates anchor position", %{socket: socket, comment: comment} do
      update_attrs = %{
        "id" => comment.id,
        "anchor_id" => "new-element",
        "anchor_type" => "element",
        "position" => %{"x" => 50, "y" => 75}
      }

      ref = push(socket, "comment:update", update_attrs)

      assert_reply ref, :ok, %{comment: updated}
      assert updated.anchor_id == "new-element"
      assert updated.position == %{"x" => 50, "y" => 75}
    end

    test "returns error for non-existent comment", %{socket: socket} do
      fake_id = Ecto.UUID.generate()

      ref = push(socket, "comment:update", %{"id" => fake_id, "body" => "test"})

      assert_reply ref, :error, %{reason: :not_found}
    end
  end

  describe "handle_in comment:delete" do
    setup %{socket: socket, user: user} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Test Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      {:ok, comment} =
        Syncforge.Comments.create_comment(%{
          body: "Comment to delete",
          room_id: room.id,
          user_id: user.id
        })

      {:ok, socket: socket, user: user, room: room, comment: comment}
    end

    test "deletes comment and broadcasts removal", %{socket: socket, comment: comment} do
      ref = push(socket, "comment:delete", %{"id" => comment.id})

      assert_reply ref, :ok, %{}

      # Should broadcast the deletion
      assert_broadcast "comment:deleted", %{comment_id: deleted_id}
      assert deleted_id == comment.id

      # Comment should no longer exist
      assert Syncforge.Comments.get_comment(comment.id) == nil
    end

    test "returns error for non-existent comment", %{socket: socket} do
      fake_id = Ecto.UUID.generate()

      ref = push(socket, "comment:delete", %{"id" => fake_id})

      assert_reply ref, :error, %{reason: :not_found}
    end
  end

  describe "handle_in comment:resolve" do
    setup %{socket: socket, user: user} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Test Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      {:ok, comment} =
        Syncforge.Comments.create_comment(%{
          body: "Comment to resolve",
          room_id: room.id,
          user_id: user.id
        })

      {:ok, socket: socket, user: user, room: room, comment: comment}
    end

    test "resolves comment and broadcasts", %{socket: socket, comment: comment} do
      ref = push(socket, "comment:resolve", %{"id" => comment.id, "resolved" => true})

      assert_reply ref, :ok, %{comment: resolved}
      assert resolved.resolved_at != nil

      assert_broadcast "comment:resolved", %{comment: broadcast_comment}
      assert broadcast_comment.id == comment.id
      assert broadcast_comment.resolved_at != nil
    end

    test "unresolves comment when resolved is false", %{socket: socket, comment: comment} do
      # First resolve the comment
      {:ok, resolved} = Syncforge.Comments.resolve_comment(comment)
      assert resolved.resolved_at != nil

      # Then unresolve it
      ref = push(socket, "comment:resolve", %{"id" => comment.id, "resolved" => false})

      assert_reply ref, :ok, %{comment: unresolved}
      assert unresolved.resolved_at == nil

      assert_broadcast "comment:resolved", %{comment: broadcast_comment}
      assert broadcast_comment.resolved_at == nil
    end

    test "returns error for non-existent comment", %{socket: socket} do
      fake_id = Ecto.UUID.generate()

      ref = push(socket, "comment:resolve", %{"id" => fake_id, "resolved" => true})

      assert_reply ref, :error, %{reason: :not_found}
    end
  end

  # Helper to generate test tokens
  defp generate_test_token(user) do
    Phoenix.Token.sign(SyncforgeWeb.Endpoint, "user socket", user)
  end
end

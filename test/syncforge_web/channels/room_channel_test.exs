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
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Join Test Room", is_public: true})

      assert {:ok, _reply, _socket} =
               subscribe_and_join(socket, RoomChannel, "room:#{room.id}")
    end

    test "assigns room_id to socket", %{socket: socket} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Assign Test Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      assert socket.assigns.room_id == room.id
    end

    test "tracks presence on join", %{socket: socket, user: user} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Presence Test Room", is_public: true})

      {:ok, _reply, _socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      # Give presence time to sync
      Process.sleep(50)

      presence = SyncforgeWeb.Presence.list("room:#{room.id}")
      assert Map.has_key?(presence, user.id)
    end

    test "receives presence_state after join", %{socket: socket} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "State Test Room", is_public: true})

      {:ok, reply, _socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      assert Map.has_key?(reply, :presence)
    end

    test "rejects join for non-existent room", %{socket: socket} do
      fake_room_id = Ecto.UUID.generate()

      assert {:error, %{reason: :room_not_found}} =
               subscribe_and_join(socket, RoomChannel, "room:#{fake_room_id}")
    end

    test "rejects join for private room", %{socket: socket} do
      {:ok, private_room} =
        Syncforge.Rooms.create_room(%{name: "Private Room", is_public: false})

      assert {:error, %{reason: :unauthorized}} =
               subscribe_and_join(socket, RoomChannel, "room:#{private_room.id}")
    end
  end

  describe "handle_in cursor:update" do
    setup %{socket: socket} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Cursor Test Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      {:ok, socket: socket, room: room}
    end

    test "broadcasts cursor position to other clients", %{socket: socket} do
      push(socket, "cursor:update", %{"x" => 100, "y" => 200})

      # Should broadcast to others (not self due to broadcast_from)
      # In test, we verify the message was handled without error
      assert_broadcast "cursor:update", %{x: 100, y: 200, user_id: _}
    end

    test "includes user_id in cursor broadcast", %{socket: socket, user: user} do
      push(socket, "cursor:update", %{"x" => 50, "y" => 75})

      assert_broadcast "cursor:update", payload
      assert payload.user_id == user.id
      assert payload.x == 50
      assert payload.y == 75
    end

    test "includes user name for cursor label", %{socket: socket, user: user} do
      push(socket, "cursor:update", %{"x" => 100, "y" => 200})

      assert_broadcast "cursor:update", payload
      assert payload.name == user.name
    end

    test "includes cursor color when user has one", %{socket: _socket, room: room} do
      # Create user with a cursor color
      user_with_color = %{
        id: Ecto.UUID.generate(),
        name: "Colored User",
        avatar_url: "https://example.com/avatar.png",
        cursor_color: "#FF5733"
      }

      {:ok, socket_with_color} =
        connect(UserSocket, %{"token" => generate_test_token(user_with_color)}, connect_info: %{})

      {:ok, _reply, socket_with_color} =
        subscribe_and_join(socket_with_color, RoomChannel, "room:#{room.id}")

      push(socket_with_color, "cursor:update", %{"x" => 100, "y" => 200})

      assert_broadcast "cursor:update", payload
      assert payload.color == "#FF5733"
    end

    test "uses default color when user has no cursor_color", %{socket: socket} do
      push(socket, "cursor:update", %{"x" => 100, "y" => 200})

      assert_broadcast "cursor:update", payload
      # Should have a default color
      assert is_binary(payload.color)
      assert String.starts_with?(payload.color, "#")
    end

    test "includes optional element_id when provided", %{socket: socket} do
      push(socket, "cursor:update", %{"x" => 100, "y" => 200, "element_id" => "editor-panel"})

      assert_broadcast "cursor:update", payload
      assert payload.element_id == "editor-panel"
    end
  end

  describe "handle_in presence:update" do
    test "updates user presence metadata", %{socket: socket} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Presence Update Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      push(socket, "presence:update", %{"status" => "typing"})

      # Give presence time to update
      Process.sleep(50)

      # Presence update should be processed without error
      refute_receive {:error, _}
    end
  end

  describe "terminate/2" do
    test "cleans up presence on disconnect", %{socket: socket, user: user} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Terminate Test Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      # Give presence time to track
      Process.sleep(50)

      # Verify user is tracked
      presence = SyncforgeWeb.Presence.list("room:#{room.id}")
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
      presence = SyncforgeWeb.Presence.list("room:#{room.id}")
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

    test "rejects update by non-owner", %{room: room, comment: comment} do
      # Connect as a different user
      other_user = %{
        id: Ecto.UUID.generate(),
        name: "Other User",
        avatar_url: "https://example.com/other.png"
      }

      {:ok, other_socket} =
        connect(UserSocket, %{"token" => generate_test_token(other_user)}, connect_info: %{})

      {:ok, _reply, other_socket} =
        subscribe_and_join(other_socket, RoomChannel, "room:#{room.id}")

      ref = push(other_socket, "comment:update", %{"id" => comment.id, "body" => "Hijacked!"})

      assert_reply ref, :error, %{reason: :unauthorized}
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

    test "rejects delete by non-owner", %{room: room, comment: comment} do
      # Connect as a different user
      other_user = %{
        id: Ecto.UUID.generate(),
        name: "Other User",
        avatar_url: "https://example.com/other.png"
      }

      {:ok, other_socket} =
        connect(UserSocket, %{"token" => generate_test_token(other_user)}, connect_info: %{})

      {:ok, _reply, other_socket} =
        subscribe_and_join(other_socket, RoomChannel, "room:#{room.id}")

      ref = push(other_socket, "comment:delete", %{"id" => comment.id})

      assert_reply ref, :error, %{reason: :unauthorized}
    end
  end

  describe "room state on join" do
    test "receives existing comments when joining room with comments", %{socket: _socket} do
      # Create a new user and room with existing comments
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "State Test Room", is_public: true})

      existing_user_id = Ecto.UUID.generate()

      # Create some existing comments in the room
      {:ok, comment1} =
        Syncforge.Comments.create_comment(%{
          body: "First existing comment",
          room_id: room.id,
          user_id: existing_user_id
        })

      {:ok, comment2} =
        Syncforge.Comments.create_comment(%{
          body: "Second existing comment",
          room_id: room.id,
          user_id: existing_user_id,
          anchor_id: "element-456"
        })

      # Now a new user joins
      new_user = %{
        id: Ecto.UUID.generate(),
        name: "New Joiner",
        avatar_url: "https://example.com/new.png"
      }

      {:ok, new_socket} =
        connect(UserSocket, %{"token" => generate_test_token(new_user)}, connect_info: %{})

      {:ok, _reply, _socket} =
        subscribe_and_join(new_socket, RoomChannel, "room:#{room.id}")

      # Should receive room_state with existing comments
      assert_push "room_state", %{comments: comments, room: room_data}
      assert length(comments) == 2
      assert Enum.any?(comments, fn c -> c.id == comment1.id end)
      assert Enum.any?(comments, fn c -> c.id == comment2.id end)
      assert room_data.id == room.id
    end

    test "receives empty comments list when joining room without comments", %{socket: _socket} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Empty Room", is_public: true})

      new_user = %{
        id: Ecto.UUID.generate(),
        name: "Solo User",
        avatar_url: "https://example.com/solo.png"
      }

      {:ok, new_socket} =
        connect(UserSocket, %{"token" => generate_test_token(new_user)}, connect_info: %{})

      {:ok, _reply, _socket} =
        subscribe_and_join(new_socket, RoomChannel, "room:#{room.id}")

      # Should receive room_state with empty comments
      assert_push "room_state", %{comments: comments, room: room_data}
      assert comments == []
      assert room_data.id == room.id
    end

    test "room state includes room metadata", %{socket: _socket} do
      {:ok, room} =
        Syncforge.Rooms.create_room(%{
          name: "Metadata Room",
          is_public: true,
          max_participants: 10,
          metadata: %{"description" => "Test room"}
        })

      new_user = %{
        id: Ecto.UUID.generate(),
        name: "Metadata User",
        avatar_url: "https://example.com/meta.png"
      }

      {:ok, new_socket} =
        connect(UserSocket, %{"token" => generate_test_token(new_user)}, connect_info: %{})

      {:ok, _reply, _socket} =
        subscribe_and_join(new_socket, RoomChannel, "room:#{room.id}")

      assert_push "room_state", %{room: room_data}
      assert room_data.name == "Metadata Room"
      assert room_data.is_public == true
      assert room_data.max_participants == 10
    end
  end

  describe "handle_in selection:update" do
    setup %{socket: socket} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Selection Test Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      {:ok, socket: socket, room: room}
    end

    test "broadcasts selection to other clients", %{socket: socket} do
      selection = %{
        "start" => %{"offset" => 0, "path" => [0, 0]},
        "end" => %{"offset" => 10, "path" => [0, 0]}
      }

      push(socket, "selection:update", %{"selection" => selection})

      assert_broadcast "selection:update", %{selection: broadcast_selection}
      assert broadcast_selection == selection
    end

    test "includes user_id in selection broadcast", %{socket: socket, user: user} do
      selection = %{"text" => "selected text"}

      push(socket, "selection:update", %{"selection" => selection})

      assert_broadcast "selection:update", payload
      assert payload.user_id == user.id
    end

    test "includes element_id when provided", %{socket: socket} do
      push(socket, "selection:update", %{
        "selection" => %{"text" => "test"},
        "element_id" => "editor-main"
      })

      assert_broadcast "selection:update", payload
      assert payload.element_id == "editor-main"
    end

    test "clears selection when selection is nil", %{socket: socket} do
      push(socket, "selection:update", %{"selection" => nil})

      assert_broadcast "selection:update", payload
      assert payload.selection == nil
    end

    test "includes timestamp in broadcast", %{socket: socket} do
      push(socket, "selection:update", %{"selection" => %{"text" => "test"}})

      assert_broadcast "selection:update", payload
      assert is_integer(payload.timestamp)
    end

    test "includes user color for selection highlighting", %{socket: _socket, room: room} do
      user_with_color = %{
        id: Ecto.UUID.generate(),
        name: "Selection User",
        avatar_url: "https://example.com/avatar.png",
        cursor_color: "#FF5733"
      }

      {:ok, socket_with_color} =
        connect(UserSocket, %{"token" => generate_test_token(user_with_color)}, connect_info: %{})

      {:ok, _reply, socket_with_color} =
        subscribe_and_join(socket_with_color, RoomChannel, "room:#{room.id}")

      push(socket_with_color, "selection:update", %{"selection" => %{"text" => "test"}})

      assert_broadcast "selection:update", payload
      assert payload.color == "#FF5733"
      assert payload.name == "Selection User"
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

    test "rejects resolve by non-owner", %{room: room, comment: comment} do
      # Connect as a different user
      other_user = %{
        id: Ecto.UUID.generate(),
        name: "Other User",
        avatar_url: "https://example.com/other.png"
      }

      {:ok, other_socket} =
        connect(UserSocket, %{"token" => generate_test_token(other_user)}, connect_info: %{})

      {:ok, _reply, other_socket} =
        subscribe_and_join(other_socket, RoomChannel, "room:#{room.id}")

      ref = push(other_socket, "comment:resolve", %{"id" => comment.id, "resolved" => true})

      assert_reply ref, :error, %{reason: :unauthorized}
    end
  end

  describe "handle_in reaction:add" do
    setup %{socket: socket, user: user} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Reaction Test Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      {:ok, comment} =
        Syncforge.Comments.create_comment(%{
          body: "Comment for reactions",
          room_id: room.id,
          user_id: user.id
        })

      {:ok, socket: socket, user: user, room: room, comment: comment}
    end

    test "adds reaction and broadcasts to room", %{socket: socket, comment: comment, user: user} do
      ref = push(socket, "reaction:add", %{"comment_id" => comment.id, "emoji" => "👍"})

      assert_reply ref, :ok, %{reaction: reaction}
      assert reaction.emoji == "👍"
      assert reaction.comment_id == comment.id
      assert reaction.user_id == user.id

      assert_broadcast "reaction:added", %{reaction: broadcast_reaction}
      assert broadcast_reaction.emoji == "👍"
      assert broadcast_reaction.comment_id == comment.id
    end

    test "returns error for duplicate reaction", %{socket: socket, comment: comment} do
      # Add first reaction
      ref = push(socket, "reaction:add", %{"comment_id" => comment.id, "emoji" => "👍"})
      assert_reply ref, :ok, _reply

      # Clear the broadcast
      assert_broadcast "reaction:added", _broadcast

      # Try to add same reaction again
      ref = push(socket, "reaction:add", %{"comment_id" => comment.id, "emoji" => "👍"})
      assert_reply ref, :error, %{errors: errors}
      assert errors != %{}
    end

    test "allows adding different emojis to same comment", %{socket: socket, comment: comment} do
      ref = push(socket, "reaction:add", %{"comment_id" => comment.id, "emoji" => "👍"})
      assert_reply ref, :ok, %{reaction: r1}
      assert_broadcast "reaction:added", _b1

      ref = push(socket, "reaction:add", %{"comment_id" => comment.id, "emoji" => "❤️"})
      assert_reply ref, :ok, %{reaction: r2}

      assert r1.emoji == "👍"
      assert r2.emoji == "❤️"
    end

    test "returns error for non-existent comment", %{socket: socket} do
      fake_comment_id = Ecto.UUID.generate()

      ref = push(socket, "reaction:add", %{"comment_id" => fake_comment_id, "emoji" => "👍"})

      assert_reply ref, :error, %{errors: _errors}
    end

    test "returns error when emoji is missing", %{socket: socket, comment: comment} do
      ref = push(socket, "reaction:add", %{"comment_id" => comment.id})

      assert_reply ref, :error, %{errors: errors}
      assert errors != %{}
    end
  end

  describe "handle_in reaction:remove" do
    setup %{socket: socket, user: user} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Reaction Remove Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      {:ok, comment} =
        Syncforge.Comments.create_comment(%{
          body: "Comment for reaction removal",
          room_id: room.id,
          user_id: user.id
        })

      # Pre-add a reaction to remove
      {:ok, reaction} =
        Syncforge.Reactions.add_reaction(%{
          emoji: "👍",
          comment_id: comment.id,
          user_id: user.id
        })

      {:ok, socket: socket, user: user, room: room, comment: comment, reaction: reaction}
    end

    test "removes reaction and broadcasts removal", %{
      socket: socket,
      comment: comment,
      reaction: reaction
    } do
      ref =
        push(socket, "reaction:remove", %{
          "comment_id" => comment.id,
          "emoji" => reaction.emoji
        })

      assert_reply ref, :ok, %{}

      assert_broadcast "reaction:removed", %{
        reaction_id: broadcast_reaction_id,
        comment_id: broadcast_comment_id,
        emoji: broadcast_emoji
      }

      assert broadcast_reaction_id == reaction.id
      assert broadcast_comment_id == comment.id
      assert broadcast_emoji == "👍"

      # Verify reaction is actually deleted
      assert Syncforge.Reactions.get_reaction(reaction.id) == nil
    end

    test "returns error when reaction doesn't exist", %{socket: socket, comment: comment} do
      ref =
        push(socket, "reaction:remove", %{
          "comment_id" => comment.id,
          "emoji" => "❤️"
        })

      assert_reply ref, :error, %{reason: :not_found}
    end

    test "returns error for non-existent comment", %{socket: socket} do
      fake_comment_id = Ecto.UUID.generate()

      ref = push(socket, "reaction:remove", %{"comment_id" => fake_comment_id, "emoji" => "👍"})

      assert_reply ref, :error, %{reason: :not_found}
    end
  end

  describe "handle_in reaction:toggle" do
    setup %{socket: socket, user: user} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Reaction Toggle Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      {:ok, comment} =
        Syncforge.Comments.create_comment(%{
          body: "Comment for reaction toggling",
          room_id: room.id,
          user_id: user.id
        })

      {:ok, socket: socket, user: user, room: room, comment: comment}
    end

    test "adds reaction when it doesn't exist", %{socket: socket, comment: comment, user: user} do
      ref = push(socket, "reaction:toggle", %{"comment_id" => comment.id, "emoji" => "👍"})

      assert_reply ref, :ok, %{action: :added, reaction: reaction}
      assert reaction.emoji == "👍"
      assert reaction.user_id == user.id

      assert_broadcast "reaction:added", %{reaction: _broadcast}
    end

    test "removes reaction when it exists", %{socket: socket, comment: comment, user: user} do
      # First add a reaction
      {:ok, _existing} =
        Syncforge.Reactions.add_reaction(%{
          emoji: "👍",
          comment_id: comment.id,
          user_id: user.id
        })

      ref = push(socket, "reaction:toggle", %{"comment_id" => comment.id, "emoji" => "👍"})

      assert_reply ref, :ok, %{action: :removed}

      assert_broadcast "reaction:removed", %{reaction_id: _id, comment_id: _cid, emoji: "👍"}
    end

    test "toggling twice returns to original state", %{socket: socket, comment: comment} do
      # Toggle on
      ref = push(socket, "reaction:toggle", %{"comment_id" => comment.id, "emoji" => "👍"})
      assert_reply ref, :ok, %{action: :added, reaction: _added}
      assert_broadcast "reaction:added", _b1

      # Toggle off
      ref = push(socket, "reaction:toggle", %{"comment_id" => comment.id, "emoji" => "👍"})
      assert_reply ref, :ok, %{action: :removed}
      assert_broadcast "reaction:removed", _b2

      # Verify no reactions exist
      assert Syncforge.Reactions.list_reactions(comment.id) == []
    end
  end

  describe "reactions in room state" do
    test "receives existing reactions when joining room", %{socket: _socket} do
      {:ok, room} =
        Syncforge.Rooms.create_room(%{name: "Reactions State Room", is_public: true})

      existing_user_id = Ecto.UUID.generate()

      {:ok, comment} =
        Syncforge.Comments.create_comment(%{
          body: "Comment with reactions",
          room_id: room.id,
          user_id: existing_user_id
        })

      # Add some reactions
      {:ok, _r1} =
        Syncforge.Reactions.add_reaction(%{
          emoji: "👍",
          comment_id: comment.id,
          user_id: existing_user_id
        })

      {:ok, _r2} =
        Syncforge.Reactions.add_reaction(%{
          emoji: "❤️",
          comment_id: comment.id,
          user_id: Ecto.UUID.generate()
        })

      # New user joins
      new_user = %{
        id: Ecto.UUID.generate(),
        name: "Reaction Viewer",
        avatar_url: "https://example.com/viewer.png"
      }

      {:ok, new_socket} =
        connect(UserSocket, %{"token" => generate_test_token(new_user)}, connect_info: %{})

      {:ok, _reply, _socket} =
        subscribe_and_join(new_socket, RoomChannel, "room:#{room.id}")

      # Should receive room_state with comments that have embedded reactions
      assert_push "room_state", %{comments: comments, room: _room_data}
      assert length(comments) == 1

      comment_data = hd(comments)
      assert comment_data.id == comment.id

      # Reactions are embedded in each comment
      assert comment_data.reactions["👍"] == 1
      assert comment_data.reactions["❤️"] == 1
    end

    test "comments without reactions have empty reactions map", %{socket: _socket} do
      {:ok, room} =
        Syncforge.Rooms.create_room(%{name: "No Reactions Room", is_public: true})

      existing_user_id = Ecto.UUID.generate()

      {:ok, comment} =
        Syncforge.Comments.create_comment(%{
          body: "Comment without reactions",
          room_id: room.id,
          user_id: existing_user_id
        })

      new_user = %{
        id: Ecto.UUID.generate(),
        name: "New User",
        avatar_url: "https://example.com/new.png"
      }

      {:ok, new_socket} =
        connect(UserSocket, %{"token" => generate_test_token(new_user)}, connect_info: %{})

      {:ok, _reply, _socket} =
        subscribe_and_join(new_socket, RoomChannel, "room:#{room.id}")

      assert_push "room_state", %{comments: comments}
      assert length(comments) == 1

      comment_data = hd(comments)
      assert comment_data.id == comment.id
      assert comment_data.reactions == %{}
    end
  end

  describe "activity feed on join" do
    test "receives recent activities when joining room", %{socket: _socket} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Activity Room", is_public: true})

      actor_id = Ecto.UUID.generate()

      # Create some activities
      {:ok, _a1} =
        Syncforge.Activity.create_activity(%{
          type: "user_joined",
          room_id: room.id,
          actor_id: actor_id,
          payload: %{"name" => "Alice"}
        })

      {:ok, _a2} =
        Syncforge.Activity.create_activity(%{
          type: "comment_created",
          room_id: room.id,
          actor_id: actor_id,
          subject_id: Ecto.UUID.generate(),
          subject_type: "comment",
          payload: %{"body_preview" => "Test comment..."}
        })

      # New user joins
      new_user = %{
        id: Ecto.UUID.generate(),
        name: "Activity Viewer",
        avatar_url: "https://example.com/viewer.png"
      }

      {:ok, new_socket} =
        connect(UserSocket, %{"token" => generate_test_token(new_user)}, connect_info: %{})

      {:ok, _reply, _socket} =
        subscribe_and_join(new_socket, RoomChannel, "room:#{room.id}")

      # Should receive room_state with activities
      assert_push "room_state", %{activities: activities}
      assert length(activities) == 2
    end

    test "room state includes empty activities list for new room", %{socket: _socket} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Empty Activity Room", is_public: true})

      new_user = %{
        id: Ecto.UUID.generate(),
        name: "Solo User",
        avatar_url: "https://example.com/solo.png"
      }

      {:ok, new_socket} =
        connect(UserSocket, %{"token" => generate_test_token(new_user)}, connect_info: %{})

      {:ok, _reply, _socket} =
        subscribe_and_join(new_socket, RoomChannel, "room:#{room.id}")

      # Should receive room_state with empty activities
      assert_push "room_state", %{activities: activities}
      assert activities == []
    end

    test "activities are limited to most recent 50", %{socket: _socket} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Many Activities Room", is_public: true})

      actor_id = Ecto.UUID.generate()

      # Create 60 activities
      for i <- 1..60 do
        {:ok, _} =
          Syncforge.Activity.create_activity(%{
            type: "comment_created",
            room_id: room.id,
            actor_id: actor_id,
            payload: %{"index" => i}
          })

        Process.sleep(1)
      end

      new_user = %{
        id: Ecto.UUID.generate(),
        name: "Activity Viewer",
        avatar_url: "https://example.com/viewer.png"
      }

      {:ok, new_socket} =
        connect(UserSocket, %{"token" => generate_test_token(new_user)}, connect_info: %{})

      {:ok, _reply, _socket} =
        subscribe_and_join(new_socket, RoomChannel, "room:#{room.id}")

      # Should receive only the 50 most recent activities
      assert_push "room_state", %{activities: activities}
      assert length(activities) == 50
    end
  end

  describe "handle_in activity:list" do
    setup %{socket: socket, user: _user} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Activity List Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      actor_id = Ecto.UUID.generate()

      # Create 15 activities
      for i <- 1..15 do
        {:ok, _} =
          Syncforge.Activity.create_activity(%{
            type: "comment_created",
            room_id: room.id,
            actor_id: actor_id,
            payload: %{"index" => i}
          })

        Process.sleep(5)
      end

      {:ok, socket: socket, room: room}
    end

    test "returns paginated activities", %{socket: socket} do
      ref = push(socket, "activity:list", %{"limit" => 5})

      assert_reply ref, :ok, %{activities: activities}
      assert length(activities) == 5
    end

    test "supports offset for pagination", %{socket: socket} do
      ref1 = push(socket, "activity:list", %{"limit" => 5, "offset" => 0})
      assert_reply ref1, :ok, %{activities: first_page}

      ref2 = push(socket, "activity:list", %{"limit" => 5, "offset" => 5})
      assert_reply ref2, :ok, %{activities: second_page}

      first_ids = Enum.map(first_page, & &1.id)
      second_ids = Enum.map(second_page, & &1.id)

      # Pages should be different
      assert Enum.all?(second_ids, fn id -> id not in first_ids end)
    end

    test "returns all activities when no limit specified", %{socket: socket} do
      ref = push(socket, "activity:list", %{})

      assert_reply ref, :ok, %{activities: activities}
      assert length(activities) == 15
    end
  end

  describe "activity creation on comment events" do
    setup %{socket: socket, user: user} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Comment Activity Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      {:ok, socket: socket, user: user, room: room}
    end

    test "creates activity when comment is created", %{socket: socket, room: room} do
      comment_attrs = %{
        "body" => "This is a test comment",
        "anchor_id" => "element-123"
      }

      ref = push(socket, "comment:create", comment_attrs)
      assert_reply ref, :ok, %{comment: _comment}

      # Clear the comment:created broadcast
      assert_broadcast "comment:created", _broadcast

      # Verify activity was created
      activities = Syncforge.Activity.list_room_activities(room.id)
      assert length(activities) == 1

      activity = hd(activities)
      assert activity.type == "comment_created"
      assert activity.room_id == room.id
    end

    test "creates activity when comment is resolved", %{socket: socket, user: user, room: room} do
      # Create a comment first
      {:ok, comment} =
        Syncforge.Comments.create_comment(%{
          body: "Comment to resolve",
          room_id: room.id,
          user_id: user.id
        })

      ref = push(socket, "comment:resolve", %{"id" => comment.id, "resolved" => true})
      assert_reply ref, :ok, _reply

      # Clear the broadcast
      assert_broadcast "comment:resolved", _broadcast

      # Verify activity was created
      activities = Syncforge.Activity.list_room_activities(room.id)
      assert Enum.any?(activities, fn a -> a.type == "comment_resolved" end)
    end

    test "creates activity when comment is deleted", %{socket: socket, user: user, room: room} do
      # Create a comment first
      {:ok, comment} =
        Syncforge.Comments.create_comment(%{
          body: "Comment to delete",
          room_id: room.id,
          user_id: user.id
        })

      ref = push(socket, "comment:delete", %{"id" => comment.id})
      assert_reply ref, :ok, _reply

      # Clear the broadcast
      assert_broadcast "comment:deleted", _broadcast

      # Verify activity was created
      activities = Syncforge.Activity.list_room_activities(room.id)
      assert Enum.any?(activities, fn a -> a.type == "comment_deleted" end)
    end
  end

  describe "activity creation on reaction events" do
    setup %{socket: socket, user: user} do
      {:ok, room} =
        Syncforge.Rooms.create_room(%{name: "Reaction Activity Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      {:ok, comment} =
        Syncforge.Comments.create_comment(%{
          body: "Comment for reactions",
          room_id: room.id,
          user_id: user.id
        })

      {:ok, socket: socket, user: user, room: room, comment: comment}
    end

    test "creates activity when reaction is added", %{
      socket: socket,
      room: room,
      comment: comment
    } do
      ref = push(socket, "reaction:add", %{"comment_id" => comment.id, "emoji" => "👍"})
      assert_reply ref, :ok, _reply

      # Clear the broadcast
      assert_broadcast "reaction:added", _broadcast

      # Verify activity was created
      activities = Syncforge.Activity.list_room_activities(room.id)
      assert Enum.any?(activities, fn a -> a.type == "reaction_added" end)

      activity = Enum.find(activities, fn a -> a.type == "reaction_added" end)
      assert activity.payload["emoji"] == "👍"
    end

    test "creates activity when reaction is removed", %{
      socket: socket,
      user: user,
      room: room,
      comment: comment
    } do
      # First add a reaction
      {:ok, _reaction} =
        Syncforge.Reactions.add_reaction(%{
          emoji: "👍",
          comment_id: comment.id,
          user_id: user.id
        })

      ref = push(socket, "reaction:remove", %{"comment_id" => comment.id, "emoji" => "👍"})
      assert_reply ref, :ok, _reply

      # Clear the broadcast
      assert_broadcast "reaction:removed", _broadcast

      # Verify activity was created
      activities = Syncforge.Activity.list_room_activities(room.id)
      assert Enum.any?(activities, fn a -> a.type == "reaction_removed" end)
    end
  end

  describe "activity broadcast" do
    setup %{socket: socket, user: _user} do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Broadcast Room", is_public: true})

      {:ok, _reply, socket} =
        subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      {:ok, socket: socket, room: room}
    end

    test "broadcasts activity:created when comment is created", %{socket: socket} do
      comment_attrs = %{"body" => "Broadcast test comment"}

      _ref = push(socket, "comment:create", comment_attrs)

      # Should receive both comment:created and activity:created
      assert_broadcast "comment:created", _comment_broadcast
      assert_broadcast "activity:created", %{activity: activity}
      assert activity.type == "comment_created"
    end
  end

  # Helper to generate test tokens
  defp generate_test_token(user) do
    Phoenix.Token.sign(SyncforgeWeb.Endpoint, "user socket", user)
  end
end

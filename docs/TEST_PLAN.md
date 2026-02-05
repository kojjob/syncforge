# SyncForge Test Plan

## Overview

This document defines the testing strategy for SyncForge, a Real-Time Collaboration Infrastructure platform. Testing focuses on real-time communication, presence synchronization, CRDT document consistency, and multi-client scenarios.

---

## Testing Strategy

### Test Pyramid

```
                    ┌─────────────┐
                    │    E2E      │  5% - Critical user flows
                    │   Tests     │  (Playwright + Phoenix Channels)
                    ├─────────────┤
                    │ Integration │  20% - Channel/Presence/CRDT
                    │   Tests     │  (ExUnit + WebSocket clients)
                    ├─────────────┤
                    │    Unit     │  75% - Business logic
                    │   Tests     │  (ExUnit + Mox)
                    └─────────────┘
```

### Testing Tools

| Layer | Tools |
|-------|-------|
| Unit Tests | ExUnit, Mox, StreamData |
| Integration Tests | Phoenix.ChannelTest, Wallaby |
| E2E Tests | Playwright, multi-browser WebSocket clients |
| Load Tests | Artillery, custom WebSocket load generator |
| CRDT Tests | Yjs test utilities, convergence validators |

---

## Test Categories

### 1. Phoenix Channel Tests

Testing real-time WebSocket communication through Phoenix Channels.

#### Room Channel Tests

```elixir
# test/syncforge_web/channels/room_channel_test.exs
defmodule SyncForgeWeb.RoomChannelTest do
  use SyncForgeWeb.ChannelCase

  alias SyncForge.Collaboration
  alias SyncForgeWeb.RoomChannel
  alias SyncForgeWeb.UserSocket

  import SyncForge.Factory

  setup do
    organization = insert(:organization)
    user = insert(:user, organization: organization)
    room = insert(:room, organization: organization)

    {:ok, socket} = connect(UserSocket, %{"token" => generate_token(user)})

    %{socket: socket, user: user, room: room, organization: organization}
  end

  describe "join/3" do
    test "joins room successfully with valid access", %{socket: socket, room: room, user: user} do
      {:ok, reply, socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      assert reply == %{participants: []}
      assert socket.assigns.room_id == room.id
      assert socket.assigns.user_id == user.id
    end

    test "returns error when room does not exist", %{socket: socket} do
      assert {:error, %{reason: "room_not_found"}} =
               subscribe_and_join(socket, RoomChannel, "room:nonexistent")
    end

    test "returns error when user lacks access", %{socket: socket} do
      other_org = insert(:organization)
      private_room = insert(:room, organization: other_org)

      assert {:error, %{reason: "access_denied"}} =
               subscribe_and_join(socket, RoomChannel, "room:#{private_room.id}")
    end

    test "enforces max participants limit", %{socket: socket, room: room} do
      # Fill room to capacity
      Enum.each(1..room.max_participants, fn _ ->
        other_user = insert(:user, organization: room.organization)
        {:ok, other_socket} = connect(UserSocket, %{"token" => generate_token(other_user)})
        subscribe_and_join(other_socket, RoomChannel, "room:#{room.id}")
      end)

      assert {:error, %{reason: "room_full"}} =
               subscribe_and_join(socket, RoomChannel, "room:#{room.id}")
    end

    test "broadcasts presence_state on join", %{socket: socket, room: room} do
      {:ok, _reply, _socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      assert_push "presence_state", %{}
    end
  end

  describe "handle_in cursor:update" do
    setup %{socket: socket, room: room} do
      {:ok, _reply, socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")
      %{socket: socket}
    end

    test "broadcasts cursor position to other participants", %{socket: socket} do
      cursor_data = %{
        "x" => 150,
        "y" => 200,
        "element_id" => "doc-editor",
        "viewport" => %{"scroll_x" => 0, "scroll_y" => 100}
      }

      push(socket, "cursor:update", cursor_data)

      assert_broadcast "cursor:moved", %{
        user_id: _,
        x: 150,
        y: 200,
        element_id: "doc-editor"
      }
    end

    test "throttles rapid cursor updates", %{socket: socket} do
      # Send 100 updates in quick succession
      Enum.each(1..100, fn i ->
        push(socket, "cursor:update", %{"x" => i, "y" => i})
      end)

      # Should receive throttled broadcasts (max ~33/sec at 30ms throttle)
      Process.sleep(100)
      broadcasts = get_all_broadcasts()
      assert length(broadcasts) < 50
    end
  end

  describe "handle_in doc:update" do
    setup %{socket: socket, room: room} do
      document = insert(:document, room: room)
      {:ok, _reply, socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")
      %{socket: socket, document: document}
    end

    test "applies Yjs update and broadcasts to peers", %{socket: socket, document: document} do
      # Yjs binary update (base64 encoded for transport)
      yjs_update = Base.encode64(<<1, 2, 3, 4, 5>>)

      push(socket, "doc:update", %{
        "document_id" => document.id,
        "update" => yjs_update,
        "origin" => "user-edit"
      })

      assert_broadcast "doc:update", %{
        document_id: ^document.id,
        update: ^yjs_update
      }
    end

    test "persists document snapshot periodically", %{socket: socket, document: document} do
      # Send multiple updates
      Enum.each(1..10, fn _ ->
        push(socket, "doc:update", %{
          "document_id" => document.id,
          "update" => Base.encode64(:crypto.strong_rand_bytes(100)),
          "origin" => "user-edit"
        })
      end)

      # Wait for snapshot persistence (configured interval)
      Process.sleep(1000)

      assert Collaboration.get_latest_snapshot(document.id) != nil
    end
  end

  describe "handle_in comment:add" do
    setup %{socket: socket, room: room} do
      document = insert(:document, room: room)
      {:ok, _reply, socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")
      %{socket: socket, document: document}
    end

    test "creates comment and broadcasts to room", %{socket: socket, document: document} do
      comment_data = %{
        "document_id" => document.id,
        "content" => "Great point here!",
        "anchor" => %{
          "type" => "text_selection",
          "start" => 100,
          "end" => 150
        }
      }

      ref = push(socket, "comment:add", comment_data)

      assert_reply ref, :ok, %{comment_id: comment_id}
      assert_broadcast "comment:added", %{
        id: ^comment_id,
        content: "Great point here!",
        author: _
      }
    end

    test "parses @mentions and creates notifications", %{socket: socket, document: document, user: user} do
      mentioned_user = insert(:user, organization: user.organization)

      push(socket, "comment:add", %{
        "document_id" => document.id,
        "content" => "Hey @#{mentioned_user.username}, check this out!"
      })

      # Verify notification was created
      Process.sleep(100)
      notifications = SyncForge.Notifications.list_for_user(mentioned_user.id)
      assert length(notifications) == 1
      assert hd(notifications).type == :mention
    end
  end

  describe "terminate/2" do
    test "broadcasts presence_diff on leave", %{socket: socket, room: room} do
      {:ok, _reply, socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      Process.unlink(socket.channel_pid)
      close(socket)

      assert_broadcast "presence_diff", %{leaves: leaves}
      assert map_size(leaves) == 1
    end

    test "removes participant from room", %{socket: socket, room: room, user: user} do
      {:ok, _reply, socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      close(socket)
      Process.sleep(100)

      participants = Collaboration.list_room_participants(room.id)
      refute Enum.any?(participants, &(&1.user_id == user.id))
    end
  end
end
```

### 2. Phoenix Presence Tests

Testing real-time presence tracking and synchronization.

```elixir
# test/syncforge_web/presence/room_presence_test.exs
defmodule SyncForgeWeb.RoomPresenceTest do
  use SyncForgeWeb.ChannelCase

  alias SyncForgeWeb.RoomPresence
  alias SyncForgeWeb.RoomChannel
  alias SyncForgeWeb.UserSocket

  import SyncForge.Factory

  setup do
    organization = insert(:organization)
    room = insert(:room, organization: organization)

    users =
      Enum.map(1..3, fn _ ->
        insert(:user, organization: organization)
      end)

    %{room: room, users: users}
  end

  describe "presence tracking" do
    test "tracks user joining room", %{room: room, users: [user | _]} do
      {:ok, socket} = connect(UserSocket, %{"token" => generate_token(user)})
      {:ok, _reply, _socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      presence_list = RoomPresence.list("room:#{room.id}")

      assert Map.has_key?(presence_list, to_string(user.id))
      assert hd(presence_list[to_string(user.id)][:metas]).user_id == user.id
    end

    test "tracks multiple users in same room", %{room: room, users: users} do
      sockets =
        Enum.map(users, fn user ->
          {:ok, socket} = connect(UserSocket, %{"token" => generate_token(user)})
          {:ok, _reply, socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")
          socket
        end)

      presence_list = RoomPresence.list("room:#{room.id}")

      assert map_size(presence_list) == 3
    end

    test "includes user metadata in presence", %{room: room, users: [user | _]} do
      {:ok, socket} = connect(UserSocket, %{"token" => generate_token(user)})
      {:ok, _reply, _socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      presence_list = RoomPresence.list("room:#{room.id}")
      user_presence = hd(presence_list[to_string(user.id)][:metas])

      assert user_presence.name == user.name
      assert user_presence.avatar_url == user.avatar_url
      assert user_presence.color != nil  # Auto-assigned cursor color
    end

    test "removes user on disconnect", %{room: room, users: [user | _]} do
      {:ok, socket} = connect(UserSocket, %{"token" => generate_token(user)})
      {:ok, _reply, socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      close(socket)
      Process.sleep(100)

      presence_list = RoomPresence.list("room:#{room.id}")
      refute Map.has_key?(presence_list, to_string(user.id))
    end

    test "handles same user joining from multiple devices", %{room: room, users: [user | _]} do
      # Join from two different "devices"
      {:ok, socket1} = connect(UserSocket, %{"token" => generate_token(user), "device" => "desktop"})
      {:ok, socket2} = connect(UserSocket, %{"token" => generate_token(user), "device" => "mobile"})

      {:ok, _, _} = subscribe_and_join(socket1, RoomChannel, "room:#{room.id}")
      {:ok, _, _} = subscribe_and_join(socket2, RoomChannel, "room:#{room.id}")

      presence_list = RoomPresence.list("room:#{room.id}")
      user_metas = presence_list[to_string(user.id)][:metas]

      # Should have two presence entries for same user
      assert length(user_metas) == 2
    end
  end

  describe "presence_diff broadcasts" do
    test "broadcasts join to existing participants", %{room: room, users: [user1, user2 | _]} do
      # User 1 joins first
      {:ok, socket1} = connect(UserSocket, %{"token" => generate_token(user1)})
      {:ok, _reply, _socket1} = subscribe_and_join(socket1, RoomChannel, "room:#{room.id}")

      # User 2 joins
      {:ok, socket2} = connect(UserSocket, %{"token" => generate_token(user2)})
      {:ok, _reply, _socket2} = subscribe_and_join(socket2, RoomChannel, "room:#{room.id}")

      # User 1 should receive presence_diff about User 2
      assert_push "presence_diff", %{joins: joins}
      assert Map.has_key?(joins, to_string(user2.id))
    end

    test "broadcasts leave to remaining participants", %{room: room, users: [user1, user2 | _]} do
      {:ok, socket1} = connect(UserSocket, %{"token" => generate_token(user1)})
      {:ok, socket2} = connect(UserSocket, %{"token" => generate_token(user2)})

      {:ok, _reply, _} = subscribe_and_join(socket1, RoomChannel, "room:#{room.id}")
      {:ok, _reply, socket2} = subscribe_and_join(socket2, RoomChannel, "room:#{room.id}")

      close(socket2)

      assert_push "presence_diff", %{leaves: leaves}
      assert Map.has_key?(leaves, to_string(user2.id))
    end
  end

  describe "presence sync performance" do
    test "syncs presence state under 50ms", %{room: room, users: [user | _]} do
      {:ok, socket} = connect(UserSocket, %{"token" => generate_token(user)})

      start_time = System.monotonic_time(:millisecond)
      {:ok, _reply, _socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")
      assert_push "presence_state", _state
      end_time = System.monotonic_time(:millisecond)

      assert end_time - start_time < 50
    end
  end
end
```

### 3. CRDT Document Synchronization Tests

Testing Yjs document convergence and conflict resolution.

```elixir
# test/syncforge/collaboration/document_sync_test.exs
defmodule SyncForge.Collaboration.DocumentSyncTest do
  use SyncForge.DataCase, async: false

  alias SyncForge.Collaboration
  alias SyncForge.Collaboration.{Document, Snapshot}
  alias SyncForge.CRDT.YjsDocument

  import SyncForge.Factory

  describe "document creation" do
    test "creates document with initial Yjs state" do
      room = insert(:room)

      {:ok, document} = Collaboration.create_document(room.id, %{
        name: "Untitled Document",
        type: :text
      })

      assert document.name == "Untitled Document"
      assert document.yjs_state != nil
      assert is_binary(document.yjs_state)
    end
  end

  describe "applying updates" do
    setup do
      room = insert(:room)
      {:ok, document} = Collaboration.create_document(room.id, %{name: "Test Doc"})
      %{document: document}
    end

    test "applies Yjs update to document", %{document: document} do
      # Simulate a Yjs update (text insertion)
      update = YjsDocument.create_text_insert_update("Hello, World!")

      {:ok, updated_doc} = Collaboration.apply_document_update(document.id, update)

      # Decode and verify content
      content = YjsDocument.get_text_content(updated_doc.yjs_state)
      assert content == "Hello, World!"
    end

    test "merges concurrent updates correctly", %{document: document} do
      # Simulate two concurrent edits
      update1 = YjsDocument.create_text_insert_update("Hello", 0)
      update2 = YjsDocument.create_text_insert_update("World", 0)

      # Apply in different order - CRDT should converge
      {:ok, doc_a} = Collaboration.apply_document_update(document.id, update1)
      {:ok, doc_a} = Collaboration.apply_document_update(doc_a.id, update2)

      {:ok, doc_b} = Collaboration.apply_document_update(document.id, update2)
      {:ok, doc_b} = Collaboration.apply_document_update(doc_b.id, update1)

      # Both should have same content (order may vary based on client IDs)
      content_a = YjsDocument.get_text_content(doc_a.yjs_state)
      content_b = YjsDocument.get_text_content(doc_b.yjs_state)

      assert content_a == content_b
    end

    test "tracks update history for undo support", %{document: document} do
      update = YjsDocument.create_text_insert_update("Test")

      {:ok, _updated_doc} = Collaboration.apply_document_update(document.id, update, %{
        user_id: Ecto.UUID.generate(),
        origin: "user-edit"
      })

      history = Collaboration.get_document_history(document.id, limit: 10)
      assert length(history) == 1
      assert hd(history).origin == "user-edit"
    end
  end

  describe "snapshot management" do
    setup do
      room = insert(:room)
      {:ok, document} = Collaboration.create_document(room.id, %{name: "Test Doc"})
      %{document: document}
    end

    test "creates snapshot after threshold updates", %{document: document} do
      # Apply enough updates to trigger snapshot
      Enum.each(1..50, fn i ->
        update = YjsDocument.create_text_insert_update("Line #{i}\n")
        Collaboration.apply_document_update(document.id, update)
      end)

      snapshots = Collaboration.list_snapshots(document.id)
      assert length(snapshots) >= 1
    end

    test "restores document from snapshot", %{document: document} do
      # Create some content
      update = YjsDocument.create_text_insert_update("Original content")
      {:ok, doc} = Collaboration.apply_document_update(document.id, update)

      # Create snapshot
      {:ok, snapshot} = Collaboration.create_snapshot(doc.id)

      # Modify document
      update2 = YjsDocument.create_text_insert_update(" with modifications")
      {:ok, _modified_doc} = Collaboration.apply_document_update(doc.id, update2)

      # Restore from snapshot
      {:ok, restored_doc} = Collaboration.restore_from_snapshot(doc.id, snapshot.id)

      content = YjsDocument.get_text_content(restored_doc.yjs_state)
      assert content == "Original content"
    end

    test "compresses old snapshots", %{document: document} do
      # Create multiple snapshots
      Enum.each(1..10, fn i ->
        update = YjsDocument.create_text_insert_update("Batch #{i}\n")
        {:ok, doc} = Collaboration.apply_document_update(document.id, update)
        Collaboration.create_snapshot(doc.id)
      end)

      # Run compression
      {:ok, compressed_count} = Collaboration.compress_snapshots(document.id, keep_last: 3)

      assert compressed_count == 7
      remaining = Collaboration.list_snapshots(document.id)
      assert length(remaining) == 3
    end
  end

  describe "awareness protocol" do
    test "tracks client awareness state" do
      room = insert(:room)
      {:ok, document} = Collaboration.create_document(room.id, %{name: "Test"})

      client_id = 12345
      awareness_state = %{
        "cursor" => %{"anchor" => 10, "head" => 15},
        "selection" => %{"start" => 10, "end" => 15},
        "user" => %{"name" => "Alice", "color" => "#FF0000"}
      }

      {:ok, _} = Collaboration.update_awareness(document.id, client_id, awareness_state)

      all_awareness = Collaboration.get_awareness(document.id)
      assert all_awareness[client_id] == awareness_state
    end

    test "removes awareness on client disconnect" do
      room = insert(:room)
      {:ok, document} = Collaboration.create_document(room.id, %{name: "Test"})

      client_id = 12345
      Collaboration.update_awareness(document.id, client_id, %{"cursor" => %{}})

      Collaboration.remove_awareness(document.id, client_id)

      all_awareness = Collaboration.get_awareness(document.id)
      refute Map.has_key?(all_awareness, client_id)
    end
  end
end
```

### 4. Multi-Client Synchronization Tests

Testing real-time sync across multiple connected clients.

```elixir
# test/syncforge/integration/multi_client_sync_test.exs
defmodule SyncForge.Integration.MultiClientSyncTest do
  use SyncForgeWeb.ChannelCase, async: false

  alias SyncForgeWeb.{RoomChannel, UserSocket}
  alias SyncForge.CRDT.YjsDocument

  import SyncForge.Factory

  @moduletag :integration

  describe "multi-client document editing" do
    setup do
      organization = insert(:organization)
      room = insert(:room, organization: organization)
      document = insert(:document, room: room)

      users = Enum.map(1..3, fn i ->
        insert(:user, organization: organization, name: "User #{i}")
      end)

      sockets = Enum.map(users, fn user ->
        {:ok, socket} = connect(UserSocket, %{"token" => generate_token(user)})
        {:ok, _reply, socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")
        socket
      end)

      %{room: room, document: document, sockets: sockets, users: users}
    end

    test "all clients receive document updates", %{document: document, sockets: [s1, s2, s3]} do
      update = Base.encode64(YjsDocument.create_text_insert_update("Hello"))

      push(s1, "doc:update", %{
        "document_id" => document.id,
        "update" => update
      })

      # Client 2 and 3 should receive the update
      assert_push_to(s2, "doc:update", %{document_id: document.id})
      assert_push_to(s3, "doc:update", %{document_id: document.id})
    end

    test "concurrent edits converge to same state", %{document: document, sockets: sockets} do
      # Each client makes an edit simultaneously
      Enum.each(Enum.with_index(sockets), fn {socket, idx} ->
        update = Base.encode64(YjsDocument.create_text_insert_update("Edit#{idx}"))
        push(socket, "doc:update", %{
          "document_id" => document.id,
          "update" => update
        })
      end)

      Process.sleep(200)

      # All clients should converge to same document state
      doc = SyncForge.Collaboration.get_document!(document.id)
      content = YjsDocument.get_text_content(doc.yjs_state)

      # All edits should be present (order determined by CRDT)
      assert String.contains?(content, "Edit0")
      assert String.contains?(content, "Edit1")
      assert String.contains?(content, "Edit2")
    end

    test "late-joining client receives full document state", %{room: room, document: document, sockets: [s1 | _]} do
      # First client makes edits
      update = Base.encode64(YjsDocument.create_text_insert_update("Existing content"))
      push(s1, "doc:update", %{"document_id" => document.id, "update" => update})
      Process.sleep(100)

      # New client joins
      new_user = insert(:user, organization: room.organization)
      {:ok, socket} = connect(UserSocket, %{"token" => generate_token(new_user)})
      {:ok, _reply, socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      # Request document sync
      ref = push(socket, "doc:sync", %{"document_id" => document.id})

      assert_reply ref, :ok, %{state: state}
      content = YjsDocument.get_text_content(Base.decode64!(state))
      assert content == "Existing content"
    end
  end

  describe "presence synchronization across clients" do
    setup do
      organization = insert(:organization)
      room = insert(:room, organization: organization)

      users = Enum.map(1..5, fn i ->
        insert(:user, organization: organization, name: "User #{i}")
      end)

      %{room: room, users: users}
    end

    test "all clients receive presence updates within 50ms", %{room: room, users: users} do
      [first_user | rest] = users

      # First user joins
      {:ok, socket1} = connect(UserSocket, %{"token" => generate_token(first_user)})
      {:ok, _, _} = subscribe_and_join(socket1, RoomChannel, "room:#{room.id}")

      # Other users join and measure presence sync time
      sync_times = Enum.map(rest, fn user ->
        {:ok, socket} = connect(UserSocket, %{"token" => generate_token(user)})

        start_time = System.monotonic_time(:millisecond)
        {:ok, _, _} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")
        assert_push "presence_state", _
        end_time = System.monotonic_time(:millisecond)

        end_time - start_time
      end)

      # All syncs should complete under 50ms
      assert Enum.all?(sync_times, &(&1 < 50))
    end

    test "presence updates propagate to all clients", %{room: room, users: [u1, u2 | _]} do
      {:ok, s1} = connect(UserSocket, %{"token" => generate_token(u1)})
      {:ok, _, _} = subscribe_and_join(s1, RoomChannel, "room:#{room.id}")

      {:ok, s2} = connect(UserSocket, %{"token" => generate_token(u2)})
      {:ok, _, _} = subscribe_and_join(s2, RoomChannel, "room:#{room.id}")

      # User 1 updates their status
      push(s1, "presence:update", %{"status" => "typing"})

      # User 2 should receive the update
      assert_push "presence_diff", %{joins: joins}
      user_meta = joins[to_string(u1.id)][:metas] |> hd()
      assert user_meta.status == "typing"
    end
  end

  describe "cursor synchronization" do
    setup do
      organization = insert(:organization)
      room = insert(:room, organization: organization)
      document = insert(:document, room: room)

      users = Enum.map(1..3, fn i ->
        insert(:user, organization: organization, name: "User #{i}")
      end)

      sockets = Enum.map(users, fn user ->
        {:ok, socket} = connect(UserSocket, %{"token" => generate_token(user)})
        {:ok, _reply, socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")
        socket
      end)

      %{document: document, sockets: sockets, users: users}
    end

    test "cursor positions broadcast to all peers", %{sockets: [s1, s2, s3]} do
      push(s1, "cursor:update", %{"x" => 100, "y" => 200})

      assert_push_to(s2, "cursor:moved", %{x: 100, y: 200})
      assert_push_to(s3, "cursor:moved", %{x: 100, y: 200})
    end

    test "cursor broadcast completes under 30ms", %{sockets: [s1 | _]} do
      start_time = System.monotonic_time(:millisecond)

      push(s1, "cursor:update", %{"x" => 100, "y" => 200})
      assert_broadcast "cursor:moved", _, timeout: 30

      end_time = System.monotonic_time(:millisecond)
      assert end_time - start_time < 30
    end
  end
end
```

### 5. Comment & Thread Tests

```elixir
# test/syncforge/collaboration/comments_test.exs
defmodule SyncForge.Collaboration.CommentsTest do
  use SyncForge.DataCase, async: true

  alias SyncForge.Collaboration
  alias SyncForge.Notifications

  import SyncForge.Factory

  describe "create_comment/2" do
    setup do
      room = insert(:room)
      document = insert(:document, room: room)
      user = insert(:user, organization: room.organization)

      %{document: document, user: user, room: room}
    end

    test "creates a new comment", %{document: document, user: user} do
      {:ok, comment} = Collaboration.create_comment(%{
        document_id: document.id,
        user_id: user.id,
        content: "This is a test comment",
        anchor: %{type: "text_selection", start: 10, end: 20}
      })

      assert comment.content == "This is a test comment"
      assert comment.anchor.start == 10
      assert comment.resolved == false
    end

    test "creates thread for reply", %{document: document, user: user} do
      {:ok, parent} = Collaboration.create_comment(%{
        document_id: document.id,
        user_id: user.id,
        content: "Parent comment"
      })

      {:ok, reply} = Collaboration.create_comment(%{
        document_id: document.id,
        user_id: user.id,
        parent_id: parent.id,
        content: "Reply to parent"
      })

      assert reply.parent_id == parent.id

      thread = Collaboration.get_thread(parent.id)
      assert length(thread.replies) == 1
    end

    test "parses @mentions and creates notifications", %{document: document, user: user, room: room} do
      mentioned = insert(:user, organization: room.organization, username: "alice")

      {:ok, _comment} = Collaboration.create_comment(%{
        document_id: document.id,
        user_id: user.id,
        content: "Hey @alice, what do you think?"
      })

      notifications = Notifications.list_for_user(mentioned.id)
      assert length(notifications) == 1
      assert hd(notifications).type == :mention
    end
  end

  describe "resolve_comment/2" do
    test "marks comment and thread as resolved" do
      comment = insert(:comment)
      _reply1 = insert(:comment, parent_id: comment.id)
      _reply2 = insert(:comment, parent_id: comment.id)

      {:ok, resolved} = Collaboration.resolve_comment(comment.id, comment.user_id)

      assert resolved.resolved == true
      assert resolved.resolved_at != nil

      thread = Collaboration.get_thread(comment.id)
      assert Enum.all?(thread.replies, & &1.resolved)
    end
  end

  describe "add_reaction/3" do
    test "adds emoji reaction to comment" do
      comment = insert(:comment)
      user = insert(:user)

      {:ok, reaction} = Collaboration.add_reaction(comment.id, user.id, "👍")

      assert reaction.emoji == "👍"
      assert reaction.user_id == user.id

      comment = Collaboration.get_comment!(comment.id)
      assert length(comment.reactions) == 1
    end

    test "prevents duplicate reactions" do
      comment = insert(:comment)
      user = insert(:user)

      {:ok, _} = Collaboration.add_reaction(comment.id, user.id, "👍")
      {:error, :already_reacted} = Collaboration.add_reaction(comment.id, user.id, "👍")
    end
  end
end
```

### 6. Notification Tests

```elixir
# test/syncforge/notifications_test.exs
defmodule SyncForge.NotificationsTest do
  use SyncForge.DataCase, async: true

  alias SyncForge.Notifications

  import SyncForge.Factory

  describe "create_notification/1" do
    test "creates notification for mention" do
      user = insert(:user)
      comment = insert(:comment)

      {:ok, notification} = Notifications.create_notification(%{
        user_id: user.id,
        type: :mention,
        actor_id: comment.user_id,
        resource_type: "comment",
        resource_id: comment.id,
        message: "mentioned you in a comment"
      })

      assert notification.type == :mention
      assert notification.read == false
    end

    test "broadcasts notification via PubSub" do
      user = insert(:user)

      Phoenix.PubSub.subscribe(SyncForge.PubSub, "user:#{user.id}:notifications")

      {:ok, notification} = Notifications.create_notification(%{
        user_id: user.id,
        type: :comment,
        message: "New comment on your document"
      })

      assert_receive {:notification, ^notification}
    end
  end

  describe "mark_as_read/2" do
    test "marks single notification as read" do
      notification = insert(:notification, read: false)

      {:ok, updated} = Notifications.mark_as_read(notification.id, notification.user_id)

      assert updated.read == true
      assert updated.read_at != nil
    end
  end

  describe "mark_all_as_read/1" do
    test "marks all user notifications as read" do
      user = insert(:user)
      insert_list(5, :notification, user_id: user.id, read: false)

      {:ok, count} = Notifications.mark_all_as_read(user.id)

      assert count == 5

      unread = Notifications.list_unread(user.id)
      assert length(unread) == 0
    end
  end
end
```

### 7. WebSocket Connection Tests

```elixir
# test/syncforge_web/sockets/user_socket_test.exs
defmodule SyncForgeWeb.UserSocketTest do
  use SyncForgeWeb.ChannelCase, async: true

  alias SyncForgeWeb.UserSocket

  import SyncForge.Factory

  describe "connect/3" do
    test "connects with valid JWT token" do
      user = insert(:user)
      token = generate_token(user)

      assert {:ok, socket} = connect(UserSocket, %{"token" => token})
      assert socket.assigns.user_id == user.id
    end

    test "rejects expired token" do
      user = insert(:user)
      token = generate_token(user, expires_in: -1)

      assert :error = connect(UserSocket, %{"token" => token})
    end

    test "rejects invalid token" do
      assert :error = connect(UserSocket, %{"token" => "invalid.token.here"})
    end

    test "rejects missing token" do
      assert :error = connect(UserSocket, %{})
    end
  end

  describe "id/1" do
    test "returns unique socket identifier" do
      user = insert(:user)
      token = generate_token(user)

      {:ok, socket} = connect(UserSocket, %{"token" => token})

      assert UserSocket.id(socket) == "user_socket:#{user.id}"
    end
  end
end
```

### 8. Reconnection & Recovery Tests

```elixir
# test/syncforge/integration/reconnection_test.exs
defmodule SyncForge.Integration.ReconnectionTest do
  use SyncForgeWeb.ChannelCase, async: false

  alias SyncForgeWeb.{RoomChannel, UserSocket}
  alias SyncForge.CRDT.YjsDocument

  import SyncForge.Factory

  @moduletag :integration

  describe "client reconnection" do
    setup do
      organization = insert(:organization)
      room = insert(:room, organization: organization)
      document = insert(:document, room: room)
      user = insert(:user, organization: organization)

      %{room: room, document: document, user: user}
    end

    test "resumes from last known state after disconnect", %{room: room, document: document, user: user} do
      # Connect and make edits
      {:ok, socket} = connect(UserSocket, %{"token" => generate_token(user)})
      {:ok, _, socket} = subscribe_and_join(socket, RoomChannel, "room:#{room.id}")

      update = Base.encode64(YjsDocument.create_text_insert_update("Before disconnect"))
      push(socket, "doc:update", %{"document_id" => document.id, "update" => update})
      Process.sleep(100)

      # Disconnect
      close(socket)
      Process.sleep(100)

      # Reconnect
      {:ok, new_socket} = connect(UserSocket, %{"token" => generate_token(user)})
      {:ok, _, new_socket} = subscribe_and_join(new_socket, RoomChannel, "room:#{room.id}")

      # Request sync with state vector
      ref = push(new_socket, "doc:sync", %{"document_id" => document.id})

      assert_reply ref, :ok, %{state: state}
      content = YjsDocument.get_text_content(Base.decode64!(state))
      assert content == "Before disconnect"
    end

    test "receives missed updates after reconnection", %{room: room, document: document, user: user} do
      other_user = insert(:user, organization: room.organization)

      # User 1 connects
      {:ok, socket1} = connect(UserSocket, %{"token" => generate_token(user)})
      {:ok, _, socket1} = subscribe_and_join(socket1, RoomChannel, "room:#{room.id}")

      # User 1 disconnects
      close(socket1)
      Process.sleep(100)

      # User 2 makes edits while User 1 is offline
      {:ok, socket2} = connect(UserSocket, %{"token" => generate_token(other_user)})
      {:ok, _, socket2} = subscribe_and_join(socket2, RoomChannel, "room:#{room.id}")

      update = Base.encode64(YjsDocument.create_text_insert_update("Made while offline"))
      push(socket2, "doc:update", %{"document_id" => document.id, "update" => update})
      Process.sleep(100)

      # User 1 reconnects and syncs
      {:ok, socket1} = connect(UserSocket, %{"token" => generate_token(user)})
      {:ok, _, socket1} = subscribe_and_join(socket1, RoomChannel, "room:#{room.id}")

      ref = push(socket1, "doc:sync", %{"document_id" => document.id})
      assert_reply ref, :ok, %{state: state}

      content = YjsDocument.get_text_content(Base.decode64!(state))
      assert content == "Made while offline"
    end
  end
end
```

---

## Load Testing

### WebSocket Load Test Configuration

```yaml
# artillery/load-test.yml
config:
  target: "wss://app.syncforge.dev"
  phases:
    - duration: 60
      arrivalRate: 10
      name: "Warm up"
    - duration: 120
      arrivalRate: 50
      name: "Ramp up"
    - duration: 300
      arrivalRate: 100
      name: "Sustained load"
  engines:
    socketio-v3: {}

scenarios:
  - name: "Join room and collaborate"
    engine: socketio-v3
    flow:
      - emit:
          channel: "room:{{ $randomString(8) }}"
          data:
            action: "phx_join"
      - think: 2
      - loop:
          - emit:
              channel: "room:{{ roomId }}"
              data:
                event: "cursor:update"
                payload:
                  x: "{{ $randomNumber(0, 1920) }}"
                  y: "{{ $randomNumber(0, 1080) }}"
          - think: 0.1
        count: 100
      - loop:
          - emit:
              channel: "room:{{ roomId }}"
              data:
                event: "doc:update"
                payload:
                  update: "{{ $randomString(100) }}"
          - think: 1
        count: 20
```

### Performance Targets

| Metric | Target | Critical |
|--------|--------|----------|
| Presence sync latency | < 50ms | < 100ms |
| Cursor broadcast latency | < 30ms | < 50ms |
| Document sync latency | < 100ms | < 200ms |
| WebSocket connection time | < 200ms | < 500ms |
| Concurrent users per room | 50 | 100 |
| Concurrent rooms per node | 1000 | 2000 |
| Message throughput | 10k/sec | 5k/sec |

---

## Test Data Factories

```elixir
# test/support/factory.ex
defmodule SyncForge.Factory do
  use ExMachina.Ecto, repo: SyncForge.Repo

  def organization_factory do
    %SyncForge.Accounts.Organization{
      name: sequence(:name, &"Organization #{&1}"),
      slug: sequence(:slug, &"org-#{&1}"),
      plan: :pro
    }
  end

  def user_factory do
    %SyncForge.Accounts.User{
      email: sequence(:email, &"user#{&1}@example.com"),
      name: sequence(:name, &"User #{&1}"),
      username: sequence(:username, &"user#{&1}"),
      password_hash: Bcrypt.hash_pwd_salt("password123"),
      organization: build(:organization)
    }
  end

  def room_factory do
    %SyncForge.Collaboration.Room{
      name: sequence(:name, &"Room #{&1}"),
      type: :collaboration,
      max_participants: 50,
      organization: build(:organization)
    }
  end

  def document_factory do
    %SyncForge.Collaboration.Document{
      name: sequence(:name, &"Document #{&1}"),
      type: :text,
      yjs_state: SyncForge.CRDT.YjsDocument.new_state(),
      room: build(:room)
    }
  end

  def comment_factory do
    %SyncForge.Collaboration.Comment{
      content: "Test comment",
      resolved: false,
      document: build(:document),
      user: build(:user)
    }
  end

  def notification_factory do
    %SyncForge.Notifications.Notification{
      type: :mention,
      message: "You were mentioned",
      read: false,
      user: build(:user)
    }
  end

  # Helper to generate JWT tokens for testing
  def generate_token(user, opts \\ []) do
    expires_in = Keyword.get(opts, :expires_in, 3600)
    SyncForge.Auth.Token.generate(user, expires_in: expires_in)
  end
end
```

---

## CI/CD Test Configuration

```yaml
# .github/workflows/test.yml
name: Test Suite

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  MIX_ENV: test
  DATABASE_URL: postgres://postgres:postgres@localhost/syncforge_test

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          otp-version: '26.0'
          elixir-version: '1.16'

      - name: Restore dependencies cache
        uses: actions/cache@v3
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}

      - name: Install dependencies
        run: mix deps.get

      - name: Compile
        run: mix compile --warnings-as-errors

      - name: Check formatting
        run: mix format --check-formatted

      - name: Run Credo
        run: mix credo --strict

      - name: Setup database
        run: mix ecto.setup

      - name: Run unit tests
        run: mix test --exclude integration

      - name: Run integration tests
        run: mix test --only integration

      - name: Generate coverage report
        run: mix coveralls.github
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  e2e:
    runs-on: ubuntu-latest
    needs: test

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install Playwright
        run: npx playwright install --with-deps

      - name: Start application
        run: |
          mix deps.get
          mix ecto.setup
          mix phx.server &
          sleep 10

      - name: Run E2E tests
        run: npx playwright test

      - name: Upload test artifacts
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: playwright-report
          path: playwright-report/
```

---

## Coverage Requirements

| Category | Minimum Coverage |
|----------|------------------|
| Unit Tests | 90% |
| Integration Tests | 80% |
| Critical Paths | 100% |
| Security Code | 100% |

### Critical Path Coverage

The following paths require 100% test coverage:

1. **Authentication & Authorization**
   - Token validation
   - Room access control
   - API key verification

2. **Real-Time Communication**
   - Channel join/leave
   - Message broadcasting
   - Presence tracking

3. **Document Synchronization**
   - CRDT update application
   - Conflict resolution
   - Snapshot creation/restoration

4. **Data Integrity**
   - Comment creation with mentions
   - Notification delivery
   - Participant tracking

---

## Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix coveralls.html

# Run only unit tests
mix test --exclude integration

# Run only integration tests
mix test --only integration

# Run specific test file
mix test test/syncforge_web/channels/room_channel_test.exs

# Run with verbose output
mix test --trace

# Run load tests
cd artillery && artillery run load-test.yml
```

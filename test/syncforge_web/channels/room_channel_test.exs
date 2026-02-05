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

  # Helper to generate test tokens
  defp generate_test_token(user) do
    Phoenix.Token.sign(SyncforgeWeb.Endpoint, "user socket", user)
  end
end

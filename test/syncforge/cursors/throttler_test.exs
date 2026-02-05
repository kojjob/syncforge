defmodule Syncforge.Cursors.ThrottlerTest do
  use ExUnit.Case, async: true

  alias Syncforge.Cursors.Throttler

  @room_id "room-123"
  @user_id "user-456"

  # Helper to start anonymous throttler for isolated tests
  defp start_throttler(opts \\ []) do
    opts = Keyword.put_new(opts, :name, nil)
    Throttler.start_link(opts)
  end

  describe "should_broadcast?/3" do
    test "allows first cursor update for a user" do
      {:ok, throttler} = start_throttler(interval_ms: 16)

      assert Throttler.should_broadcast?(throttler, @room_id, @user_id) == true
    end

    test "denies update if within throttle interval" do
      {:ok, throttler} = start_throttler(interval_ms: 50)

      # First update allowed
      assert Throttler.should_broadcast?(throttler, @room_id, @user_id) == true

      # Immediate second update denied
      assert Throttler.should_broadcast?(throttler, @room_id, @user_id) == false
    end

    test "allows update after throttle interval has passed" do
      {:ok, throttler} = start_throttler(interval_ms: 10)

      # First update
      assert Throttler.should_broadcast?(throttler, @room_id, @user_id) == true

      # Wait for interval to pass
      Process.sleep(15)

      # Should be allowed now
      assert Throttler.should_broadcast?(throttler, @room_id, @user_id) == true
    end

    test "tracks different users independently" do
      {:ok, throttler} = start_throttler(interval_ms: 50)

      user_1 = "user-1"
      user_2 = "user-2"

      # First update for user 1
      assert Throttler.should_broadcast?(throttler, @room_id, user_1) == true

      # First update for user 2 (should still be allowed)
      assert Throttler.should_broadcast?(throttler, @room_id, user_2) == true

      # Second update for user 1 (denied)
      assert Throttler.should_broadcast?(throttler, @room_id, user_1) == false

      # Second update for user 2 (denied)
      assert Throttler.should_broadcast?(throttler, @room_id, user_2) == false
    end

    test "tracks different rooms independently" do
      {:ok, throttler} = start_throttler(interval_ms: 50)

      room_1 = "room-1"
      room_2 = "room-2"

      # First update in room 1
      assert Throttler.should_broadcast?(throttler, room_1, @user_id) == true

      # First update in room 2 (should still be allowed)
      assert Throttler.should_broadcast?(throttler, room_2, @user_id) == true

      # Second update in room 1 (denied)
      assert Throttler.should_broadcast?(throttler, room_1, @user_id) == false
    end
  end

  describe "record_update/3" do
    test "records timestamp for user" do
      {:ok, throttler} = start_throttler(interval_ms: 50)

      # Initially, no record exists - should_broadcast? returns true
      assert Throttler.should_broadcast?(throttler, @room_id, @user_id) == true

      # Now recorded, should be denied
      assert Throttler.should_broadcast?(throttler, @room_id, @user_id) == false
    end
  end

  describe "cleanup/3" do
    test "removes user from tracking when they leave a room" do
      {:ok, throttler} = start_throttler(interval_ms: 1000)

      # Record update
      assert Throttler.should_broadcast?(throttler, @room_id, @user_id) == true

      # Verify they're being throttled
      assert Throttler.should_broadcast?(throttler, @room_id, @user_id) == false

      # Cleanup user from room
      :ok = Throttler.cleanup(throttler, @room_id, @user_id)

      # Should be allowed again (no record)
      assert Throttler.should_broadcast?(throttler, @room_id, @user_id) == true
    end
  end

  describe "cleanup_room/2" do
    test "removes all users from tracking when room closes" do
      {:ok, throttler} = start_throttler(interval_ms: 1000)

      user_1 = "user-1"
      user_2 = "user-2"

      # Record updates for both users
      assert Throttler.should_broadcast?(throttler, @room_id, user_1) == true
      assert Throttler.should_broadcast?(throttler, @room_id, user_2) == true

      # Both should be throttled
      assert Throttler.should_broadcast?(throttler, @room_id, user_1) == false
      assert Throttler.should_broadcast?(throttler, @room_id, user_2) == false

      # Cleanup entire room
      :ok = Throttler.cleanup_room(throttler, @room_id)

      # Both should be allowed again
      assert Throttler.should_broadcast?(throttler, @room_id, user_1) == true
      assert Throttler.should_broadcast?(throttler, @room_id, user_2) == true
    end
  end

  describe "configuration" do
    test "uses default interval of 16ms (~60fps)" do
      {:ok, throttler} = start_throttler()

      assert Throttler.get_interval(throttler) == 16
    end

    test "accepts custom interval" do
      {:ok, throttler} = start_throttler(interval_ms: 33)

      assert Throttler.get_interval(throttler) == 33
    end
  end
end

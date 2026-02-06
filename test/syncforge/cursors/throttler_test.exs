defmodule Syncforge.Cursors.ThrottlerTest do
  use ExUnit.Case, async: true

  alias Syncforge.Cursors.Throttler

  @room_id "room-123"
  @user_id "user-456"

  # Helper to start an isolated throttler with a unique ETS table per test
  defp start_throttler(opts \\ []) do
    table_name = :"test_throttler_#{System.unique_integer([:positive])}"
    opts = Keyword.put_new(opts, :name, table_name)
    {:ok, pid} = Throttler.start_link(opts)
    {pid, table_name}
  end

  describe "should_broadcast?/3" do
    test "allows first cursor update for a user" do
      {_pid, table} = start_throttler(interval_ms: 16)

      assert Throttler.should_broadcast?(table, @room_id, @user_id) == true
    end

    test "denies update if within throttle interval" do
      {_pid, table} = start_throttler(interval_ms: 50)

      # First update allowed
      assert Throttler.should_broadcast?(table, @room_id, @user_id) == true

      # Immediate second update denied
      assert Throttler.should_broadcast?(table, @room_id, @user_id) == false
    end

    test "allows update after throttle interval has passed" do
      {_pid, table} = start_throttler(interval_ms: 10)

      # First update
      assert Throttler.should_broadcast?(table, @room_id, @user_id) == true

      # Wait for interval to pass
      Process.sleep(15)

      # Should be allowed now
      assert Throttler.should_broadcast?(table, @room_id, @user_id) == true
    end

    test "tracks different users independently" do
      {_pid, table} = start_throttler(interval_ms: 50)

      user_1 = "user-1"
      user_2 = "user-2"

      # First update for user 1
      assert Throttler.should_broadcast?(table, @room_id, user_1) == true

      # First update for user 2 (should still be allowed)
      assert Throttler.should_broadcast?(table, @room_id, user_2) == true

      # Second update for user 1 (denied)
      assert Throttler.should_broadcast?(table, @room_id, user_1) == false

      # Second update for user 2 (denied)
      assert Throttler.should_broadcast?(table, @room_id, user_2) == false
    end

    test "tracks different rooms independently" do
      {_pid, table} = start_throttler(interval_ms: 50)

      room_1 = "room-1"
      room_2 = "room-2"

      # First update in room 1
      assert Throttler.should_broadcast?(table, room_1, @user_id) == true

      # First update in room 2 (should still be allowed)
      assert Throttler.should_broadcast?(table, room_2, @user_id) == true

      # Second update in room 1 (denied)
      assert Throttler.should_broadcast?(table, room_1, @user_id) == false
    end
  end

  describe "record_update/3" do
    test "records timestamp for user" do
      {_pid, table} = start_throttler(interval_ms: 50)

      # Initially, no record exists - should_broadcast? returns true
      assert Throttler.should_broadcast?(table, @room_id, @user_id) == true

      # Now recorded, should be denied
      assert Throttler.should_broadcast?(table, @room_id, @user_id) == false
    end
  end

  describe "cleanup/3" do
    test "removes user from tracking when they leave a room" do
      {_pid, table} = start_throttler(interval_ms: 1000)

      # Record update
      assert Throttler.should_broadcast?(table, @room_id, @user_id) == true

      # Verify they're being throttled
      assert Throttler.should_broadcast?(table, @room_id, @user_id) == false

      # Cleanup user from room
      :ok = Throttler.cleanup(table, @room_id, @user_id)

      # Should be allowed again (no record)
      assert Throttler.should_broadcast?(table, @room_id, @user_id) == true
    end
  end

  describe "cleanup_room/2" do
    test "removes all users from tracking when room closes" do
      {_pid, table} = start_throttler(interval_ms: 1000)

      user_1 = "user-1"
      user_2 = "user-2"

      # Record updates for both users
      assert Throttler.should_broadcast?(table, @room_id, user_1) == true
      assert Throttler.should_broadcast?(table, @room_id, user_2) == true

      # Both should be throttled
      assert Throttler.should_broadcast?(table, @room_id, user_1) == false
      assert Throttler.should_broadcast?(table, @room_id, user_2) == false

      # Cleanup entire room
      :ok = Throttler.cleanup_room(table, @room_id)

      # Both should be allowed again
      assert Throttler.should_broadcast?(table, @room_id, user_1) == true
      assert Throttler.should_broadcast?(table, @room_id, user_2) == true
    end
  end

  describe "configuration" do
    test "uses default interval of 16ms (~60fps)" do
      {_pid, table} = start_throttler()

      assert Throttler.get_interval(table) == 16
    end

    test "accepts custom interval" do
      {_pid, table} = start_throttler(interval_ms: 33)

      assert Throttler.get_interval(table) == 33
    end
  end

  describe "concurrent access" do
    test "handles concurrent should_broadcast? calls from multiple processes" do
      {_pid, table} = start_throttler(interval_ms: 50)

      # Spawn 50 processes all checking different user keys simultaneously
      tasks =
        for i <- 1..50 do
          Task.async(fn ->
            user = "concurrent-user-#{i}"
            Throttler.should_broadcast?(table, @room_id, user)
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All first calls should return true (different users)
      assert Enum.all?(results, & &1)
    end

    test "handles concurrent calls for the same user correctly" do
      {_pid, table} = start_throttler(interval_ms: 1000)

      # Spawn 10 processes all checking the same user key simultaneously
      tasks =
        for _i <- 1..10 do
          Task.async(fn ->
            Throttler.should_broadcast?(table, @room_id, @user_id)
          end)
        end

      results = Task.await_many(tasks, 5000)

      # At least one should be true (first writer wins), rest should be false
      # Due to race conditions, we might get more than one true, which is acceptable
      assert Enum.any?(results, & &1)
    end
  end

  describe "periodic cleanup" do
    test "stale entries are cleaned up by sweep" do
      {pid, table} =
        start_throttler(
          interval_ms: 10,
          cleanup_interval_ms: 50,
          stale_threshold_ms: 20
        )

      # Record an entry
      assert Throttler.should_broadcast?(table, @room_id, @user_id) == true

      # Wait for the entry to become stale (>20ms) AND for the cleanup sweep (~50ms)
      Process.sleep(120)

      # After cleanup sweep, stale entries should be removed
      entries = :ets.tab2list(table)
      # Filter out the config entry
      data_entries = Enum.reject(entries, fn {k, _} -> k == :__config__ end)
      assert data_entries == []

      # Should be able to broadcast again
      assert Throttler.should_broadcast?(table, @room_id, @user_id) == true

      # Stop the process to clean up
      GenServer.stop(pid)
    end
  end
end

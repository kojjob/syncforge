defmodule Syncforge.Cursors.Throttler do
  @moduledoc """
  Throttles cursor updates to prevent flooding the WebSocket channel.

  Limits cursor broadcasts to a configurable interval (default 16ms for ~60fps).
  Each user in each room is tracked independently, allowing smooth cursor
  movement without overwhelming network bandwidth.

  ## Usage

      # Start a throttler (typically done in application supervisor)
      {:ok, throttler} = Throttler.start_link(interval_ms: 16)

      # Check if an update should be broadcast
      if Throttler.should_broadcast?(throttler, room_id, user_id) do
        broadcast_cursor_update(...)
      end

      # Cleanup when user leaves
      Throttler.cleanup(throttler, room_id, user_id)

  ## Performance

  Uses an Agent for simplicity. For production with thousands of concurrent
  users, consider using ETS for better read performance.
  """

  use Agent

  # ~60fps
  @default_interval_ms 16
  @default_name __MODULE__

  @doc """
  Starts a new throttler process.

  ## Options

    * `:interval_ms` - Minimum time between cursor broadcasts per user.
      Defaults to 16ms (~60fps). Use 33ms for ~30fps.

    * `:name` - The name to register the process under. Defaults to
      `Syncforge.Cursors.Throttler`. Pass `nil` for anonymous process.

  """
  def start_link(opts \\ []) do
    interval_ms = Keyword.get(opts, :interval_ms, @default_interval_ms)
    name = Keyword.get(opts, :name, @default_name)

    agent_opts = if name, do: [name: name], else: []

    Agent.start_link(
      fn ->
        %{
          interval_ms: interval_ms,
          # %{"room_id:user_id" => last_update_timestamp}
          timestamps: %{}
        }
      end,
      agent_opts
    )
  end

  @doc """
  Checks if a cursor update should be broadcast using the default throttler.
  """
  def should_broadcast?(room_id, user_id) do
    should_broadcast?(@default_name, room_id, user_id)
  end

  @doc """
  Removes tracking for a specific user using the default throttler.
  """
  def cleanup(room_id, user_id) do
    cleanup(@default_name, room_id, user_id)
  end

  @doc """
  Removes tracking for all users in a room using the default throttler.
  """
  def cleanup_room(room_id) do
    cleanup_room(@default_name, room_id)
  end

  @doc """
  Checks if a cursor update should be broadcast and records the timestamp if so.

  Returns `true` if enough time has passed since the last update for this user
  in this room, `false` otherwise.

  This function atomically checks and records, ensuring thread-safety.
  """
  def should_broadcast?(throttler, room_id, user_id) do
    key = build_key(room_id, user_id)
    now = System.monotonic_time(:millisecond)

    Agent.get_and_update(throttler, fn state ->
      case Map.get(state.timestamps, key) do
        nil ->
          # First update for this user, always allow
          new_timestamps = Map.put(state.timestamps, key, now)
          {true, %{state | timestamps: new_timestamps}}

        last_update when now - last_update >= state.interval_ms ->
          # Enough time has passed, allow broadcast and record timestamp
          new_timestamps = Map.put(state.timestamps, key, now)
          {true, %{state | timestamps: new_timestamps}}

        _last_update ->
          # Too soon, deny broadcast
          {false, state}
      end
    end)
  end

  @doc """
  Removes tracking for a specific user in a room.

  Call this when a user leaves a room to free up memory.
  """
  def cleanup(throttler, room_id, user_id) do
    key = build_key(room_id, user_id)

    Agent.update(throttler, fn state ->
      %{state | timestamps: Map.delete(state.timestamps, key)}
    end)
  end

  @doc """
  Removes tracking for all users in a room.

  Call this when a room is closed or all users have left.
  """
  def cleanup_room(throttler, room_id) do
    prefix = "#{room_id}:"

    Agent.update(throttler, fn state ->
      new_timestamps =
        state.timestamps
        |> Enum.reject(fn {key, _} -> String.starts_with?(key, prefix) end)
        |> Map.new()

      %{state | timestamps: new_timestamps}
    end)
  end

  @doc """
  Returns the configured throttle interval in milliseconds.
  """
  def get_interval(throttler) do
    Agent.get(throttler, fn state -> state.interval_ms end)
  end

  # Private helpers

  defp build_key(room_id, user_id), do: "#{room_id}:#{user_id}"
end

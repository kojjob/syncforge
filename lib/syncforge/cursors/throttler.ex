defmodule Syncforge.Cursors.Throttler do
  @moduledoc """
  Throttles cursor updates to prevent flooding the WebSocket channel.

  Limits cursor broadcasts to a configurable interval (default 16ms for ~60fps).
  Each user in each room is tracked independently, allowing smooth cursor
  movement without overwhelming network bandwidth.

  Uses ETS for concurrent reads/writes without message passing. The GenServer
  only handles periodic cleanup of stale entries — all hot-path operations
  (should_broadcast?, cleanup) go directly through ETS from the calling process.

  ## Usage

      # Start a throttler (typically done in application supervisor)
      {:ok, throttler} = Throttler.start_link(interval_ms: 16)

      # Check if an update should be broadcast (uses default table)
      if Throttler.should_broadcast?(room_id, user_id) do
        broadcast_cursor_update(...)
      end

      # Cleanup when user leaves
      Throttler.cleanup(room_id, user_id)
  """

  use GenServer

  # ~60fps
  @default_interval_ms 16
  @default_name __MODULE__
  @default_cleanup_interval_ms 60_000
  # Entries older than 5 minutes are considered stale
  @default_stale_threshold_ms 300_000

  @doc """
  Starts a new throttler process backed by an ETS table.

  ## Options

    * `:interval_ms` - Minimum time between cursor broadcasts per user.
      Defaults to 16ms (~60fps). Use 33ms for ~30fps.

    * `:name` - The name to register the ETS table and process under.
      Defaults to `Syncforge.Cursors.Throttler`.

    * `:cleanup_interval_ms` - How often to sweep stale entries.
      Defaults to 60_000ms (60 seconds).

    * `:stale_threshold_ms` - Entries older than this are removed during sweep.
      Defaults to 300_000ms (5 minutes).

  """
  def start_link(opts \\ []) do
    interval_ms = Keyword.get(opts, :interval_ms, @default_interval_ms)
    name = Keyword.get(opts, :name, @default_name)
    cleanup_interval_ms = Keyword.get(opts, :cleanup_interval_ms, @default_cleanup_interval_ms)
    stale_threshold_ms = Keyword.get(opts, :stale_threshold_ms, @default_stale_threshold_ms)

    GenServer.start_link(
      __MODULE__,
      %{
        table_name: name,
        interval_ms: interval_ms,
        cleanup_interval_ms: cleanup_interval_ms,
        stale_threshold_ms: stale_threshold_ms
      },
      name: name
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

  Reads and writes directly to ETS from the calling process — no message passing.
  """
  def should_broadcast?(table, room_id, user_id) do
    key = build_key(room_id, user_id)
    now = System.monotonic_time(:millisecond)
    interval_ms = get_interval(table)

    case :ets.lookup(table, key) do
      [] ->
        :ets.insert(table, {key, now})
        true

      [{^key, last_update}] when now - last_update >= interval_ms ->
        :ets.insert(table, {key, now})
        true

      _ ->
        false
    end
  end

  @doc """
  Removes tracking for a specific user in a room.

  Call this when a user leaves a room to free up memory.
  """
  def cleanup(table, room_id, user_id) do
    key = build_key(room_id, user_id)
    :ets.delete(table, key)
    :ok
  end

  @doc """
  Removes tracking for all users in a room.

  Call this when a room is closed or all users have left.
  """
  def cleanup_room(table, room_id) do
    prefix = "#{room_id}:"

    :ets.foldl(
      fn {key, _value}, acc ->
        if is_binary(key) and String.starts_with?(key, prefix) do
          :ets.delete(table, key)
        end

        acc
      end,
      :ok,
      table
    )

    :ok
  end

  @doc """
  Returns the configured throttle interval in milliseconds.
  """
  def get_interval(table) do
    case :ets.lookup(table, :__config__) do
      [{:__config__, interval_ms}] -> interval_ms
      [] -> @default_interval_ms
    end
  end

  # GenServer callbacks — only for startup and periodic cleanup

  @impl true
  def init(%{
        table_name: table_name,
        interval_ms: interval_ms,
        cleanup_interval_ms: cleanup_interval_ms,
        stale_threshold_ms: stale_threshold_ms
      }) do
    table =
      :ets.new(table_name, [
        :set,
        :public,
        :named_table,
        write_concurrency: true,
        read_concurrency: true
      ])

    # Store config in the ETS table itself
    :ets.insert(table, {:__config__, interval_ms})

    # Schedule first cleanup sweep
    Process.send_after(self(), :cleanup_sweep, cleanup_interval_ms)

    {:ok,
     %{
       table: table,
       cleanup_interval_ms: cleanup_interval_ms,
       stale_threshold_ms: stale_threshold_ms
     }}
  end

  @impl true
  def handle_info(:cleanup_sweep, state) do
    sweep_stale_entries(state.table, state.stale_threshold_ms)
    Process.send_after(self(), :cleanup_sweep, state.cleanup_interval_ms)
    {:noreply, state}
  end

  defp sweep_stale_entries(table, stale_threshold_ms) do
    now = System.monotonic_time(:millisecond)

    :ets.foldl(
      fn
        {:__config__, _}, acc ->
          acc

        {key, last_update}, acc ->
          if now - last_update > stale_threshold_ms do
            :ets.delete(table, key)
          end

          acc
      end,
      :ok,
      table
    )
  end

  defp build_key(room_id, user_id), do: "#{room_id}:#{user_id}"
end

# Debug Prompt - SyncForge

Use this prompt when diagnosing issues, fixing bugs, or troubleshooting problems.

---

## Context

I'm working on SyncForge, a **Real-Time Collaboration Infrastructure** platform.

**Tech Stack**:

- Elixir
- Phoenix 1.7+ (with Channels and Presence)
- PostgreSQL (via Ecto)
- Oban for background jobs
- Yjs for CRDT document sync

---

## Bug Report

### What I expected:

[Describe the expected behavior]

### What actually happened:

[Describe the actual behavior]

### Steps to reproduce:

1. [Step 1]
2. [Step 2]
3. [Step 3]

### Error messages:

```
[Paste any error messages, stack traces, or console output]
```

### Relevant code:

```elixir
# Paste the relevant code snippet
```

### Environment:

- [ ] Development
- [ ] Staging
- [ ] Production

### Severity:

- [ ] Critical (app broken, data loss)
- [ ] High (major feature broken)
- [ ] Medium (feature degraded)
- [ ] Low (cosmetic/minor)

### Category:

- [ ] WebSocket/Channel issue
- [ ] Presence tracking issue
- [ ] CRDT/Document sync issue
- [ ] Database/Ecto issue
- [ ] Authentication/Authorization
- [ ] Performance/Latency
- [ ] Memory/Resource leak

---

## Debugging Approach

### 1. Reproduce the Issue

First, confirm the bug is reproducible:

```bash
# Reset to clean state
mix ecto.reset
mix phx.server

# In another terminal, watch logs
tail -f log/dev.log

# Follow reproduction steps
```

### 2. Isolate the Problem

Narrow down where the issue occurs:

- [ ] Client-side (JavaScript SDK)
- [ ] WebSocket connection
- [ ] Phoenix Channel
- [ ] Presence tracking
- [ ] CRDT sync layer
- [ ] Database query
- [ ] Background job (Oban)
- [ ] Environment config

### 3. Gather Evidence

Collect relevant information:

```elixir
# Add debug logging
require Logger

Logger.debug("Function input: #{inspect(input)}")
Logger.debug("Socket assigns: #{inspect(socket.assigns)}")
Logger.debug("Presence state: #{inspect(presence)}")
```

### 4. Form Hypothesis

Based on evidence, what might be wrong?

- Data issue (nil, wrong type, missing field)
- Race condition (concurrent channel joins)
- Presence desync (stale state, missed diffs)
- CRDT conflict (divergent document states)
- Connection issue (timeout, reconnection failure)
- Memory leak (process accumulation)

### 5. Test Hypothesis

Write a failing test that exposes the bug:

```elixir
test "should handle [specific condition]" do
  # Setup that triggers the bug
  socket = socket(SyncForgeWeb.UserSocket, "user:1", %{current_user: user})

  # This should pass but currently fails
  {:ok, _reply, socket} = subscribe_and_join(socket, RoomChannel, "room:123")

  assert socket.assigns.room != nil
end
```

### 6. Apply Fix

Fix the code to make the test pass.

### 7. Verify No Regression

Run full test suite:

```bash
mix test
mix test --cover
```

---

## Common Issues & Solutions

### WebSocket/Channel Errors

**"unable to join: unauthorized"**

```elixir
# Problem: User not authorized to join room

# Debug: Check join/3 authorization logic
def join("room:" <> room_id, _params, socket) do
  user = socket.assigns.current_user
  Logger.debug("Join attempt: user=#{user.id}, room=#{room_id}")

  case Rooms.authorize_join(room_id, user) do
    {:ok, room} ->
      Logger.debug("Join authorized")
      {:ok, assign(socket, :room, room)}

    {:error, reason} ->
      Logger.warn("Join denied: #{reason}")
      {:error, %{reason: reason}}
  end
end

# Solution: Verify participant record exists
insert(:participant, user: user, room: room, status: :active)
```

**"channel crashed"**

```elixir
# Problem: Unhandled exception in channel callback

# Solution: Add rescue clause
def handle_in("doc:update", payload, socket) do
  try do
    # ... handle update
    {:noreply, socket}
  rescue
    e ->
      Logger.error("doc:update failed: #{inspect(e)}")
      {:reply, {:error, %{reason: "update_failed"}}, socket}
  end
end
```

**"transport timeout"**

```elixir
# Problem: WebSocket connection timing out

# config/config.exs - Increase timeout
config :syncforge, SyncForgeWeb.Endpoint,
  http: [
    transport_options: [
      socket_opts: [:inet6],
      timeout: 60_000  # 60 seconds
    ]
  ]

# Also check client-side heartbeat interval
```

### Presence Errors

**"presence_diff not received"**

```elixir
# Problem: Clients not receiving presence updates

# Debug: Check PubSub subscription
def handle_info(:after_join, socket) do
  topic = "room:#{socket.assigns.room.id}"

  # Ensure tracking happens after subscribe
  {:ok, _} = Tracker.track(socket, socket.assigns.current_user.id, %{
    name: socket.assigns.current_user.name,
    joined_at: System.system_time(:second)
  })

  # Push current state to joining user
  push(socket, "presence_state", Tracker.list(topic))

  {:noreply, socket}
end

# Verify client subscribes to presence events:
# channel.on("presence_state", ...)
# channel.on("presence_diff", ...)
```

**"presence shows duplicate users"**

```elixir
# Problem: Same user appears multiple times

# Cause: Multi-device support or reconnection
# Presence tracks by {user_id, phx_ref}

# Solution: Client-side deduplication
def list_users(topic) do
  Tracker.list(topic)
  |> Enum.map(fn {user_id, %{metas: metas}} ->
    # Take most recent meta for each user
    %{user_id: user_id, meta: List.first(metas)}
  end)
end
```

**"presence state not syncing across nodes"**

```elixir
# Problem: Presence differs between Phoenix nodes

# Debug: Check PubSub adapter
# config/runtime.exs
config :syncforge, SyncForgeWeb.Endpoint,
  pubsub_server: SyncForge.PubSub

config :syncforge, SyncForge.PubSub,
  name: SyncForge.PubSub,
  adapter: Phoenix.PubSub.PG2  # Use PG2 for clustering

# Verify nodes are connected
Node.list()  # Should show other nodes
```

### CRDT/Document Sync Errors

**"document states diverged"**

```elixir
# Problem: Different clients have different document content

# Debug: Compare state vectors
doc1_state = Documents.get_state_vector(doc1)
doc2_state = Documents.get_state_vector(doc2)
Logger.debug("State vectors: #{inspect(doc1_state)} vs #{inspect(doc2_state)}")

# Solution: Force sync by sending full state
def handle_in("doc:sync_request", _payload, socket) do
  document = socket.assigns.document
  full_state = Documents.encode_state(document)

  {:reply, {:ok, %{state: full_state}}, socket}
end
```

**"yjs update failed to apply"**

```elixir
# Problem: Malformed or incompatible Yjs update

def apply_yjs_update(document, update_binary) do
  case YjsNif.apply_update(document.state, update_binary) do
    {:ok, new_state} ->
      {:ok, %{document | state: new_state}}

    {:error, :invalid_update} ->
      Logger.warn("Invalid Yjs update: #{inspect(update_binary)}")
      # Request full sync from client
      {:error, :request_full_sync}
  end
end
```

**"document too large to sync"**

```elixir
# Problem: Document exceeds maximum size

# Solution: Implement snapshot compaction
def compact_document(document) do
  if byte_size(document.state) > 1_000_000 do  # 1MB threshold
    compacted = YjsNif.encode_state_as_update(document.state)

    Documents.update(document, %{
      state: compacted,
      version: document.version + 1
    })
  else
    {:ok, document}
  end
end
```

### Ecto/Database Errors

**"Ecto.StaleEntryError"**

```elixir
# Problem: Optimistic locking conflict

# Solution: Handle conflict with retry
def update_with_retry(record, attrs, attempts \\ 3) do
  case Repo.update(Changeset.change(record, attrs)) do
    {:ok, updated} ->
      {:ok, updated}

    {:error, %Ecto.StaleEntryError{}} when attempts > 0 ->
      # Reload and retry
      fresh = Repo.get!(record.__struct__, record.id)
      update_with_retry(fresh, attrs, attempts - 1)

    {:error, error} ->
      {:error, error}
  end
end
```

**"connection pool timeout"**

```elixir
# Problem: Too many concurrent database connections

# Debug: Check pool stats
Ecto.Adapters.SQL.Sandbox.checkout(Repo)

# Solution: Increase pool size
# config/prod.exs
config :syncforge, SyncForge.Repo,
  pool_size: 20,  # Increase from default 10
  queue_target: 5000,
  queue_interval: 1000
```

**"(Postgrex.Error) FATAL password authentication failed"**

```bash
# Check DATABASE_URL is set correctly
echo $DATABASE_URL

# Verify PostgreSQL is accepting connections
psql $DATABASE_URL -c "SELECT 1"
```

### Oban/Background Job Errors

**"job stuck in executing state"**

```elixir
# Debug: Check Oban dashboard or query directly
Oban.Job
|> where([j], j.state == "executing")
|> where([j], j.attempted_at < ^DateTime.add(DateTime.utc_now(), -300, :second))
|> Repo.all()

# Solution: Rescue crashed jobs
Oban.rescue_all_jobs(queue: :default)
```

**"job failed repeatedly"**

```elixir
# Problem: Job keeps failing and retrying

# Check job args and error
job = Repo.get(Oban.Job, job_id)
IO.inspect(job.args)
IO.inspect(job.errors)

# Solution: Add better error handling
defmodule SyncForge.Workers.DocumentSyncWorker do
  use Oban.Worker,
    queue: :document_sync,
    max_attempts: 3

  @impl true
  def perform(%Oban.Job{args: %{"document_id" => doc_id}}) do
    case Documents.sync(doc_id) do
      {:ok, _} -> :ok
      {:error, :not_found} -> {:cancel, "Document not found"}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

### Authentication Errors

**"invalid token"**

```elixir
# Debug: Decode and inspect token
token = "..."
case Phoenix.Token.verify(Endpoint, "user socket", token, max_age: 86400) do
  {:ok, user_id} ->
    Logger.debug("Valid token for user: #{user_id}")

  {:error, :expired} ->
    Logger.warn("Token expired")

  {:error, :invalid} ->
    Logger.warn("Invalid token signature")
end
```

**"session not found"**

```elixir
# Problem: User session expired or invalid

# Debug: Check session in database
session = Repo.get_by(Session, token: token)
Logger.debug("Session: #{inspect(session)}")

# Solution: Handle expired sessions gracefully
def authenticate_socket(token) do
  case Sessions.verify_token(token) do
    {:ok, user} -> {:ok, user}
    {:error, :expired} -> {:error, :session_expired}
    {:error, _} -> {:error, :unauthorized}
  end
end
```

---

## Debugging Tools

### IEx Debugging

```elixir
# In IEx console
iex -S mix phx.server

# Inspect module info
h SyncForge.Rooms.Room

# Trace function calls
:dbg.tracer()
:dbg.p(:all, :c)
:dbg.tpl(SyncForge.Rooms, :join_room, :x)

# Inspect process state
:sys.get_state(pid)
Process.info(pid)
```

### Remote Debugging (Production)

```elixir
# Connect to running node
iex --name debug@127.0.0.1 --cookie secret --remsh myapp@127.0.0.1

# Inspect processes
Process.list() |> length()
Process.registered()

# Check memory usage
:erlang.memory()
```

### Observer

```elixir
# Start Observer GUI
:observer.start()

# Or use observer_cli for terminal
Observer.CLI.start()
```

### Logger Metadata

```elixir
# Add metadata for tracing
Logger.metadata(user_id: user.id, room_id: room.id, request_id: request_id)

Logger.info("Processing request")
# Output: [info] user_id=123 room_id=456 request_id=abc Processing request
```

### Phoenix Dashboard

```elixir
# config/dev.exs - Enable LiveDashboard
import Phoenix.LiveDashboard.Router

scope "/" do
  pipe_through :browser
  live_dashboard "/dashboard", metrics: SyncForgeWeb.Telemetry
end
```

### Database Debugging

```bash
# Connect to database
psql $DATABASE_URL

# Check slow queries
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

# Check table sizes
SELECT relname, pg_size_pretty(pg_total_relation_size(relid))
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
```

### WebSocket Debugging

```javascript
// Client-side: Log all WebSocket messages
const originalOnMessage = socket.onMessage;
socket.onMessage = function(event) {
  console.log('[WS IN]', event.data);
  originalOnMessage.call(this, event);
};

const originalSend = socket.conn.send.bind(socket.conn);
socket.conn.send = function(data) {
  console.log('[WS OUT]', data);
  originalSend(data);
};
```

---

## Performance Debugging

### Identify Bottlenecks

```elixir
# Measure function execution time
def timed(name, fun) do
  {time, result} = :timer.tc(fun)
  Logger.debug("#{name} took #{time / 1000}ms")
  result
end

# Usage
timed("presence_list", fn -> Tracker.list(topic) end)
```

### Profile Memory

```elixir
# Check process memory
Process.list()
|> Enum.map(fn pid ->
  {pid, :erlang.process_info(pid, :memory)}
end)
|> Enum.sort_by(fn {_, {:memory, mem}} -> mem end, :desc)
|> Enum.take(10)
```

### Profile Database

```elixir
# Log slow queries
# config/dev.exs
config :syncforge, SyncForge.Repo,
  log: :debug,
  stacktrace: true

# Or use Ecto.LogEntry
```

---

## Output Format

When providing a fix:

1. **Root cause** - What caused the bug
2. **Failing test** - Test that exposes the bug
3. **Fix** - Code changes needed
4. **Verification** - How to confirm it's fixed
5. **Prevention** - How to prevent similar bugs

---

## Bug Fix Checklist

- [ ] Root cause identified
- [ ] Failing test written
- [ ] Fix implemented
- [ ] All tests pass (`mix test`)
- [ ] No compile warnings (`mix compile --warnings-as-errors`)
- [ ] Credo passes (`mix credo --strict`)
- [ ] No regressions introduced
- [ ] Real-time functionality tested with multiple clients
- [ ] Reconnection scenarios tested
- [ ] Documentation updated if needed
- [ ] PR description explains the fix

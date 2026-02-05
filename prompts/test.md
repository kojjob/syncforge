# Test Prompt - SyncForge

Use this prompt when generating tests for existing code or creating test suites.

---

## Context

I'm working on SyncForge, a **Real-Time Collaboration Infrastructure** platform.

**Testing Stack**:

- ExUnit (test framework)
- Phoenix.ChannelTest (WebSocket channel tests)
- Phoenix.ConnTest (controller/API tests)
- Phoenix.LiveViewTest (LiveView tests)
- Wallaby (E2E browser tests)
- Mox (behaviour mocking)
- ExMachina (test factories)
- ExCoveralls (coverage reporting)

**Coverage Requirements**:

- Line coverage: 80% minimum
- Branch coverage: 75% minimum
- Critical paths (real-time sync, presence, auth): 100%

---

## Test Request

### Code to Test:

[Paste the code or reference the file path]

### Test Type:

- [ ] Unit Test
- [ ] Channel Test (WebSocket)
- [ ] Integration Test
- [ ] E2E Test
- [ ] All of the above

### Focus Areas:

[What specifically should be tested?]

---

## Test Structure

### Channel Test Template (Real-Time Core)

```elixir
defmodule SyncForgeWeb.RoomChannelTest do
  use SyncForgeWeb.ChannelCase, async: true

  alias SyncForgeWeb.RoomChannel
  alias SyncForge.Presence.Tracker

  import SyncForge.Factory

  describe "join/3" do
    test "joins room and receives initial state" do
      # Arrange
      user = insert(:user)
      room = insert(:room)
      insert(:participant, user: user, room: room)

      # Act
      {:ok, reply, socket} =
        socket(SyncForgeWeb.UserSocket, "user:#{user.id}", %{current_user: user})
        |> subscribe_and_join(RoomChannel, "room:#{room.id}")

      # Assert
      assert reply.room_id == room.id
      assert reply.participants == []
      assert socket.assigns.room == room
    end

    test "rejects join when user not authorized" do
      user = insert(:user)
      room = insert(:room)
      # No participant record

      assert {:error, %{reason: "unauthorized"}} =
               socket(SyncForgeWeb.UserSocket, "user:#{user.id}", %{current_user: user})
               |> subscribe_and_join(RoomChannel, "room:#{room.id}")
    end

    test "tracks presence after joining" do
      user = insert(:user)
      room = insert(:room)
      insert(:participant, user: user, room: room)

      {:ok, _reply, socket} =
        socket(SyncForgeWeb.UserSocket, "user:#{user.id}", %{current_user: user})
        |> subscribe_and_join(RoomChannel, "room:#{room.id}")

      # Verify presence is tracked
      presence = Tracker.list("room:#{room.id}")
      assert Map.has_key?(presence, user.id)
    end
  end

  describe "handle_in cursor:update" do
    setup do
      user = insert(:user)
      room = insert(:room)
      insert(:participant, user: user, room: room)

      {:ok, _reply, socket} =
        socket(SyncForgeWeb.UserSocket, "user:#{user.id}", %{current_user: user})
        |> subscribe_and_join(RoomChannel, "room:#{room.id}")

      %{socket: socket, user: user, room: room}
    end

    test "broadcasts cursor position to others", %{socket: socket, user: user} do
      push(socket, "cursor:update", %{"x" => 100, "y" => 200})

      assert_broadcast "cursor:update", %{
        user_id: ^user_id,
        x: 100,
        y: 200
      } where user_id = user.id
    end

    test "does not echo back to sender", %{socket: socket} do
      push(socket, "cursor:update", %{"x" => 100, "y" => 200})

      refute_push "cursor:update", _
    end
  end

  describe "handle_in doc:update" do
    setup do
      user = insert(:user)
      room = insert(:room)
      document = insert(:document, room: room)
      insert(:participant, user: user, room: room)

      {:ok, _reply, socket} =
        socket(SyncForgeWeb.UserSocket, "user:#{user.id}", %{current_user: user})
        |> subscribe_and_join(RoomChannel, "room:#{room.id}")

      %{socket: socket, document: document, room: room}
    end

    test "applies Yjs update and broadcasts", %{socket: socket, document: document} do
      yjs_update = :binary.bin_to_list(<<1, 2, 3, 4>>)

      push(socket, "doc:update", %{"update" => yjs_update})

      assert_broadcast "doc:update", %{update: ^yjs_update}

      # Verify persisted
      updated_doc = SyncForge.Documents.get_document!(document.id)
      assert updated_doc.version == document.version + 1
    end

    test "handles concurrent updates correctly", %{socket: socket, room: room} do
      # Join second user
      user2 = insert(:user)
      insert(:participant, user: user2, room: room)

      {:ok, _reply, socket2} =
        socket(SyncForgeWeb.UserSocket, "user:#{user2.id}", %{current_user: user2})
        |> subscribe_and_join(RoomChannel, "room:#{room.id}")

      # Send concurrent updates
      update1 = :binary.bin_to_list(<<1, 1, 1>>)
      update2 = :binary.bin_to_list(<<2, 2, 2>>)

      push(socket, "doc:update", %{"update" => update1})
      push(socket2, "doc:update", %{"update" => update2})

      # Both should be broadcast
      assert_broadcast "doc:update", %{update: ^update1}
      assert_broadcast "doc:update", %{update: ^update2}
    end
  end

  describe "handle_in comment:add" do
    setup do
      user = insert(:user)
      room = insert(:room)
      insert(:participant, user: user, room: room)

      {:ok, _reply, socket} =
        socket(SyncForgeWeb.UserSocket, "user:#{user.id}", %{current_user: user})
        |> subscribe_and_join(RoomChannel, "room:#{room.id}")

      %{socket: socket, user: user, room: room}
    end

    test "creates comment and broadcasts", %{socket: socket, user: user, room: room} do
      ref = push(socket, "comment:add", %{
        "body" => "Great idea!",
        "anchor_id" => "element-123",
        "position" => %{"x" => 50, "y" => 100}
      })

      assert_reply ref, :ok, %{comment: comment}
      assert comment.body == "Great idea!"
      assert comment.user_id == user.id

      assert_broadcast "comment:added", %{
        comment: %{
          body: "Great idea!",
          anchor_id: "element-123"
        }
      }
    end

    test "creates threaded reply", %{socket: socket, room: room} do
      parent = insert(:comment, room: room)

      ref = push(socket, "comment:add", %{
        "body" => "I agree!",
        "parent_id" => parent.id
      })

      assert_reply ref, :ok, %{comment: reply}
      assert reply.parent_id == parent.id
    end
  end

  describe "terminate/2" do
    test "removes presence on disconnect" do
      user = insert(:user)
      room = insert(:room)
      insert(:participant, user: user, room: room)

      {:ok, _reply, socket} =
        socket(SyncForgeWeb.UserSocket, "user:#{user.id}", %{current_user: user})
        |> subscribe_and_join(RoomChannel, "room:#{room.id}")

      # Verify presence exists
      assert Map.has_key?(Tracker.list("room:#{room.id}"), user.id)

      # Leave channel
      leave(socket)

      # Wait for presence to sync
      Process.sleep(50)

      # Verify presence removed
      refute Map.has_key?(Tracker.list("room:#{room.id}"), user.id)
    end
  end
end
```

### Presence Test Template

```elixir
defmodule SyncForge.Presence.TrackerTest do
  use SyncForge.DataCase, async: true

  alias SyncForge.Presence.Tracker

  import SyncForge.Factory

  describe "track/3" do
    test "tracks user presence with metadata" do
      user = insert(:user)
      room = insert(:room)

      {:ok, _ref} = Tracker.track(
        self(),
        "room:#{room.id}",
        user.id,
        %{
          name: user.name,
          avatar_url: user.avatar_url,
          joined_at: DateTime.utc_now()
        }
      )

      presence = Tracker.list("room:#{room.id}")

      assert %{^user_id => %{metas: [meta | _]}} = presence where user_id = user.id
      assert meta.name == user.name
    end

    test "handles multi-device presence" do
      user = insert(:user)
      room = insert(:room)

      # Device 1
      {:ok, _ref1} = Tracker.track(
        spawn(fn -> Process.sleep(:infinity) end),
        "room:#{room.id}",
        user.id,
        %{device: "desktop"}
      )

      # Device 2
      {:ok, _ref2} = Tracker.track(
        spawn(fn -> Process.sleep(:infinity) end),
        "room:#{room.id}",
        user.id,
        %{device: "mobile"}
      )

      presence = Tracker.list("room:#{room.id}")
      user_presence = presence[user.id]

      assert length(user_presence.metas) == 2
      assert Enum.any?(user_presence.metas, &(&1.device == "desktop"))
      assert Enum.any?(user_presence.metas, &(&1.device == "mobile"))
    end
  end

  describe "presence_diff broadcasts" do
    test "broadcasts join diff when user joins" do
      user = insert(:user)
      room = insert(:room)
      topic = "room:#{room.id}"

      Phoenix.PubSub.subscribe(SyncForge.PubSub, topic)

      Tracker.track(self(), topic, user.id, %{name: user.name})

      assert_receive %Phoenix.Socket.Broadcast{
        event: "presence_diff",
        payload: %{joins: joins, leaves: %{}}
      }

      assert Map.has_key?(joins, user.id)
    end

    test "broadcasts leave diff when user disconnects" do
      user = insert(:user)
      room = insert(:room)
      topic = "room:#{room.id}"

      pid = spawn(fn -> Process.sleep(:infinity) end)
      Tracker.track(pid, topic, user.id, %{name: user.name})

      Phoenix.PubSub.subscribe(SyncForge.PubSub, topic)

      # Kill the tracked process
      Process.exit(pid, :kill)

      assert_receive %Phoenix.Socket.Broadcast{
        event: "presence_diff",
        payload: %{joins: %{}, leaves: leaves}
      }, 1000

      assert Map.has_key?(leaves, user.id)
    end
  end

  describe "performance" do
    @tag :performance
    test "presence sync completes under 50ms" do
      room = insert(:room)
      topic = "room:#{room.id}"

      # Track 50 users
      users = for _ <- 1..50, do: insert(:user)

      Enum.each(users, fn user ->
        Tracker.track(
          spawn(fn -> Process.sleep(:infinity) end),
          topic,
          user.id,
          %{name: user.name}
        )
      end)

      {time_us, presence} = :timer.tc(fn ->
        Tracker.list(topic)
      end)

      time_ms = time_us / 1000
      assert time_ms < 50, "Presence sync took #{time_ms}ms, expected < 50ms"
      assert map_size(presence) == 50
    end
  end
end
```

### Document Sync Test Template

```elixir
defmodule SyncForge.Documents.DocumentSyncTest do
  use SyncForge.DataCase, async: true

  alias SyncForge.Documents
  alias SyncForge.Documents.Document

  import SyncForge.Factory

  describe "apply_update/2" do
    test "applies Yjs update to document state" do
      document = insert(:document, state: <<>>, version: 0)

      yjs_update = create_yjs_insert("Hello")

      {:ok, updated} = Documents.apply_update(document, yjs_update)

      assert updated.version == 1
      assert updated.state != <<>>
    end

    test "merges concurrent updates correctly" do
      document = insert(:document, state: <<>>, version: 0)

      update1 = create_yjs_insert("Hello")
      update2 = create_yjs_insert("World")

      {:ok, doc1} = Documents.apply_update(document, update1)
      {:ok, doc2} = Documents.apply_update(doc1, update2)

      # CRDT should contain both updates
      content = decode_yjs_content(doc2.state)
      assert content =~ "Hello"
      assert content =~ "World"
    end

    test "handles empty updates gracefully" do
      document = insert(:document)

      assert {:ok, _} = Documents.apply_update(document, <<>>)
    end
  end

  describe "get_sync_state/1" do
    test "returns state vector for sync" do
      document = insert(:document)

      state = Documents.get_sync_state(document)

      assert %{state: _, version: _} = state
    end
  end

  describe "create_snapshot/1" do
    test "creates snapshot at current version" do
      document = insert(:document, version: 5)

      {:ok, snapshot} = Documents.create_snapshot(document)

      assert snapshot.document_id == document.id
      assert snapshot.version == 5
      assert snapshot.state == document.state
    end

    test "allows restoring from snapshot" do
      document = insert(:document, version: 5)
      {:ok, snapshot} = Documents.create_snapshot(document)

      # Apply more updates
      {:ok, updated} = Documents.apply_update(document, create_yjs_insert("new content"))

      # Restore from snapshot
      {:ok, restored} = Documents.restore_snapshot(snapshot)

      assert restored.version == 5
      assert restored.state == snapshot.state
    end
  end

  # Helper functions
  defp create_yjs_insert(text) do
    # Create a minimal Yjs update binary
    # In real tests, use actual Yjs library
    <<1, 1, byte_size(text)>> <> text
  end

  defp decode_yjs_content(state) do
    # Decode Yjs state to text
    # In real tests, use actual Yjs library
    state
    |> :binary.bin_to_list()
    |> Enum.drop(3)
    |> to_string()
  end
end
```

### LiveView Test Template

```elixir
defmodule SyncForgeWeb.RoomLive.ShowTest do
  use SyncForgeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import SyncForge.Factory

  describe "room page" do
    setup :register_and_log_in_user

    test "renders room with presence indicators", %{conn: conn, user: user} do
      room = insert(:room)
      insert(:participant, user: user, room: room)

      {:ok, view, html} = live(conn, ~p"/rooms/#{room.id}")

      assert html =~ room.name
      assert has_element?(view, "#presence-container")
      assert has_element?(view, "#cursor-layer")
    end

    test "shows other users when they join", %{conn: conn, user: user} do
      room = insert(:room)
      insert(:participant, user: user, room: room)

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      # Simulate another user joining via PubSub
      other_user = insert(:user)
      Phoenix.PubSub.broadcast(
        SyncForge.PubSub,
        "room:#{room.id}",
        {:presence_diff, %{
          joins: %{other_user.id => %{name: other_user.name, avatar_url: other_user.avatar_url}},
          leaves: %{}
        }}
      )

      # Wait for LiveView to process
      assert render(view) =~ other_user.name
    end

    test "displays cursor positions", %{conn: conn, user: user} do
      room = insert(:room)
      insert(:participant, user: user, room: room)

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      # Simulate cursor update from another user
      other_user = insert(:user)
      Phoenix.PubSub.broadcast(
        SyncForge.PubSub,
        "room:#{room.id}",
        {:cursor_update, other_user.id, 150, 250}
      )

      html = render(view)
      assert html =~ "transform: translate(150px, 250px)"
    end

    test "shows comments panel", %{conn: conn, user: user} do
      room = insert(:room)
      insert(:participant, user: user, room: room)
      comment = insert(:comment, room: room, body: "Test comment")

      {:ok, _view, html} = live(conn, ~p"/rooms/#{room.id}")

      assert html =~ "Test comment"
      assert html =~ comment.user.name
    end

    test "can add new comment", %{conn: conn, user: user} do
      room = insert(:room)
      insert(:participant, user: user, room: room)

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      view
      |> element("#new-comment-form")
      |> render_submit(%{comment: %{body: "New comment!", anchor_id: "element-1"}})

      assert render(view) =~ "New comment!"
    end
  end

  describe "reconnection" do
    setup :register_and_log_in_user

    test "recovers state after disconnect", %{conn: conn, user: user} do
      room = insert(:room)
      insert(:participant, user: user, room: room)

      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.id}")

      # Simulate disconnect and reconnect
      send(view.pid, {:reconnect})

      # Should recover presence and document state
      html = render(view)
      assert html =~ room.name
    end
  end
end
```

### Controller/API Test Template

```elixir
defmodule SyncForgeWeb.Api.V1.RoomControllerTest do
  use SyncForgeWeb.ConnCase, async: true

  import SyncForge.Factory

  describe "POST /api/v1/rooms" do
    setup :setup_authenticated_conn

    test "creates a room with valid data", %{conn: conn, organization: organization} do
      params = %{
        "room" => %{
          "name" => "Design Review",
          "type" => "collaborative"
        }
      }

      conn = post(conn, ~p"/api/v1/rooms", params)

      assert %{
               "data" => %{
                 "id" => _id,
                 "name" => "Design Review",
                 "type" => "collaborative"
               }
             } = json_response(conn, 201)
    end

    test "returns validation error for invalid data", %{conn: conn} do
      params = %{"room" => %{"name" => ""}}

      conn = post(conn, ~p"/api/v1/rooms", params)

      assert %{
               "error" => %{
                 "code" => "VALIDATION_ERROR",
                 "details" => _details
               }
             } = json_response(conn, 422)
    end
  end

  describe "GET /api/v1/rooms/:id/participants" do
    setup :setup_authenticated_conn

    test "returns current participants", %{conn: conn, organization: organization} do
      room = insert(:room, organization: organization)
      user1 = insert(:user)
      user2 = insert(:user)
      insert(:participant, user: user1, room: room, status: :active)
      insert(:participant, user: user2, room: room, status: :active)

      conn = get(conn, ~p"/api/v1/rooms/#{room.id}/participants")

      assert %{"data" => participants} = json_response(conn, 200)
      assert length(participants) == 2
    end
  end

  describe "POST /api/v1/rooms/:id/join" do
    setup :setup_authenticated_conn

    test "joins room and returns connection token", %{conn: conn, user: user, organization: organization} do
      room = insert(:room, organization: organization)

      conn = post(conn, ~p"/api/v1/rooms/#{room.id}/join")

      assert %{
               "data" => %{
                 "token" => token,
                 "room_id" => room_id,
                 "websocket_url" => _url
               }
             } = json_response(conn, 200)

      assert room_id == room.id
      assert is_binary(token)
    end

    test "returns 404 for room in different organization", %{conn: conn} do
      other_org = insert(:organization)
      room = insert(:room, organization: other_org)

      conn = post(conn, ~p"/api/v1/rooms/#{room.id}/join")

      assert json_response(conn, 404)
    end
  end

  describe "unauthenticated requests" do
    test "returns 401 without token", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/rooms", %{"room" => %{"name" => "Test"}})

      assert json_response(conn, 401)
    end
  end

  defp setup_authenticated_conn(%{conn: conn}) do
    user = insert(:user)
    organization = insert(:organization)
    insert(:membership, user: user, organization: organization, role: :admin)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{generate_token(user)}")
      |> put_req_header("x-organization-id", organization.id)

    %{conn: conn, user: user, organization: organization}
  end
end
```

### E2E Test Template (Wallaby)

```elixir
defmodule SyncForge.Features.CollaborationFlowTest do
  use SyncForge.FeatureCase, async: false

  import Wallaby.Query

  alias SyncForge.Factory

  @moduletag :e2e

  describe "real-time collaboration flow" do
    setup do
      user1 = Factory.insert(:user, email: "user1@example.com")
      user2 = Factory.insert(:user, email: "user2@example.com")
      organization = Factory.insert(:organization)
      room = Factory.insert(:room, organization: organization)

      Factory.insert(:membership, user: user1, organization: organization, role: :admin)
      Factory.insert(:membership, user: user2, organization: organization, role: :member)
      Factory.insert(:participant, user: user1, room: room)
      Factory.insert(:participant, user: user2, room: room)

      {:ok, user1: user1, user2: user2, room: room}
    end

    test "users see each other's presence", %{session: session1, user1: user1, user2: user2, room: room} do
      # Start second session
      {:ok, session2} = Wallaby.start_session()

      # User 1 logs in and joins room
      session1
      |> visit("/login")
      |> fill_in(text_field("email"), with: user1.email)
      |> fill_in(text_field("password"), with: "password123")
      |> click(button("Sign in"))
      |> visit("/rooms/#{room.id}")
      |> assert_has(css(".room-container"))

      # User 2 logs in and joins room
      session2
      |> visit("/login")
      |> fill_in(text_field("email"), with: user2.email)
      |> fill_in(text_field("password"), with: "password123")
      |> click(button("Sign in"))
      |> visit("/rooms/#{room.id}")
      |> assert_has(css(".room-container"))

      # User 1 should see User 2 in presence list
      session1
      |> assert_has(css(".presence-avatar[data-user-id='#{user2.id}']"))

      # User 2 should see User 1 in presence list
      session2
      |> assert_has(css(".presence-avatar[data-user-id='#{user1.id}']"))

      Wallaby.end_session(session2)
    end

    test "users see each other's cursors", %{session: session1, user1: user1, user2: user2, room: room} do
      {:ok, session2} = Wallaby.start_session()

      # Both users join room
      login_and_join_room(session1, user1, room)
      login_and_join_room(session2, user2, room)

      # User 1 moves cursor
      session1
      |> find(css(".editor-canvas"))
      |> hover()

      # User 2 should see User 1's cursor
      session2
      |> assert_has(css(".remote-cursor[data-user-id='#{user1.id}']"))

      Wallaby.end_session(session2)
    end

    test "comments sync in real-time", %{session: session1, user1: user1, user2: user2, room: room} do
      {:ok, session2} = Wallaby.start_session()

      login_and_join_room(session1, user1, room)
      login_and_join_room(session2, user2, room)

      # User 1 adds a comment
      session1
      |> click(css(".add-comment-btn"))
      |> fill_in(text_field("comment-body"), with: "Check this out!")
      |> click(button("Post Comment"))

      # User 2 should see the comment
      session2
      |> assert_has(css(".comment-thread", text: "Check this out!"))

      Wallaby.end_session(session2)
    end

    defp login_and_join_room(session, user, room) do
      session
      |> visit("/login")
      |> fill_in(text_field("email"), with: user.email)
      |> fill_in(text_field("password"), with: "password123")
      |> click(button("Sign in"))
      |> visit("/rooms/#{room.id}")
      |> assert_has(css(".room-container"))
    end
  end
end
```

---

## Test Categories

### Happy Path Tests

- Successful room joins
- Normal presence tracking
- Valid cursor broadcasts
- Comment creation and replies
- Document sync operations

### Edge Cases

- Empty room (no other participants)
- Maximum participants reached
- Unicode in comments and usernames
- Very large documents
- Rapid cursor movements
- Offline/reconnection scenarios

### Error Cases

- Unauthorized room access
- Invalid WebSocket payloads
- Malformed Yjs updates
- Network disconnection
- Server restart during session

### Concurrency Tests

- Multiple users joining simultaneously
- Concurrent document edits
- Presence race conditions
- Comment threading under load

### Performance Tests

- Presence sync latency < 50ms
- Cursor broadcast latency < 30ms
- Document sync latency < 100ms
- 100 concurrent connections per room

---

## Mocking Patterns

### Mock WebSocket Connections

```elixir
# test/support/channel_case.ex
defmodule SyncForgeWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import SyncForge.Factory

      @endpoint SyncForgeWeb.Endpoint
    end
  end

  setup tags do
    SyncForge.DataCase.setup_sandbox(tags)
    :ok
  end
end
```

### Mock External Services with Mox

```elixir
# test/support/mocks.ex
Mox.defmock(SyncForge.Voice.MockProvider,
  for: SyncForge.Voice.ProviderBehaviour
)

# config/test.exs
config :syncforge, :voice_provider, SyncForge.Voice.MockProvider

# In test file
import Mox

setup :verify_on_exit!

test "creates voice room" do
  expect(SyncForge.Voice.MockProvider, :create_room, fn room_id ->
    {:ok, %{room_url: "https://voice.example.com/#{room_id}"}}
  end)

  # Call code that uses voice provider
end
```

### Stub PubSub for Isolation

```elixir
test "broadcasts cursor update" do
  room_id = "room-123"

  # Subscribe to topic
  Phoenix.PubSub.subscribe(SyncForge.PubSub, "room:#{room_id}")

  # Trigger the broadcast
  SyncForge.Cursors.broadcast_update(room_id, %{
    user_id: "user-1",
    x: 100,
    y: 200
  })

  # Assert we received the broadcast
  assert_receive {:cursor_update, "user-1", 100, 200}
end
```

---

## Test Data Factories

```elixir
# test/support/factory.ex
defmodule SyncForge.Factory do
  use ExMachina.Ecto, repo: SyncForge.Repo

  def user_factory do
    %SyncForge.Accounts.User{
      email: sequence(:email, &"user#{&1}@example.com"),
      name: sequence(:name, &"User #{&1}"),
      avatar_url: "https://api.dicebear.com/7.x/avataaars/svg",
      hashed_password: Bcrypt.hash_pwd_salt("password123")
    }
  end

  def organization_factory do
    %SyncForge.Accounts.Organization{
      name: sequence(:name, &"Organization #{&1}"),
      slug: sequence(:slug, &"org-#{&1}"),
      plan_type: :starter
    }
  end

  def membership_factory do
    %SyncForge.Accounts.Membership{
      user: build(:user),
      organization: build(:organization),
      role: :member,
      status: :active
    }
  end

  def room_factory do
    %SyncForge.Rooms.Room{
      name: sequence(:name, &"Room #{&1}"),
      type: :collaborative,
      status: :active,
      organization: build(:organization)
    }
  end

  def participant_factory do
    %SyncForge.Rooms.Participant{
      user: build(:user),
      room: build(:room),
      role: :member,
      status: :active,
      joined_at: DateTime.utc_now()
    }
  end

  def document_factory do
    %SyncForge.Documents.Document{
      name: sequence(:name, &"Document #{&1}"),
      state: <<>>,
      version: 0,
      room: build(:room)
    }
  end

  def comment_factory do
    %SyncForge.Comments.Comment{
      body: "This is a test comment",
      anchor_id: sequence(:anchor_id, &"element-#{&1}"),
      anchor_type: "element",
      position: %{"x" => 100, "y" => 200},
      room: build(:room),
      user: build(:user)
    }
  end

  def notification_factory do
    %SyncForge.Notifications.Notification{
      type: :mention,
      title: "You were mentioned",
      body: "Someone mentioned you in a comment",
      user: build(:user),
      room: build(:room),
      read_at: nil
    }
  end
end
```

---

## Test Support Modules

### ChannelCase (WebSocket Tests)

```elixir
# test/support/channel_case.ex
defmodule SyncForgeWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import SyncForge.Factory

      alias SyncForgeWeb.UserSocket

      @endpoint SyncForgeWeb.Endpoint
    end
  end

  setup tags do
    SyncForge.DataCase.setup_sandbox(tags)
    :ok
  end
end
```

### Multi-Client Test Helper

```elixir
# test/support/multi_client_helper.ex
defmodule SyncForge.MultiClientHelper do
  import Phoenix.ChannelTest
  import SyncForge.Factory

  def join_room_as_users(room, users) do
    Enum.map(users, fn user ->
      insert(:participant, user: user, room: room)

      {:ok, _reply, socket} =
        socket(SyncForgeWeb.UserSocket, "user:#{user.id}", %{current_user: user})
        |> subscribe_and_join(SyncForgeWeb.RoomChannel, "room:#{room.id}")

      {user, socket}
    end)
  end

  def broadcast_cursor(socket, x, y) do
    Phoenix.ChannelTest.push(socket, "cursor:update", %{"x" => x, "y" => y})
  end

  def assert_all_receive_broadcast(sockets, event, payload_matcher) do
    Enum.each(sockets, fn {_user, socket} ->
      assert_broadcast ^event, payload_matcher
    end)
  end
end
```

---

## Output Format

When generating tests, provide:

1. **Complete test file** - All imports, setup, and test cases
2. **Mock setup** - Required mocks with Mox definitions
3. **Factory updates** - New or updated factory functions if needed
4. **Coverage notes** - What scenarios are covered
5. **Run command** - How to run the specific tests

---

## Run Commands

```bash
# All tests
mix test

# Specific file
mix test test/syncforge_web/channels/room_channel_test.exs

# Specific test by line number
mix test test/syncforge_web/channels/room_channel_test.exs:42

# Only channel tests
mix test test/syncforge_web/channels/

# With coverage
mix coveralls.html

# Watch mode (with mix_test_watch)
mix test.watch

# Only E2E tests
mix test --only e2e

# Only performance tests
mix test --only performance

# Exclude slow tests
mix test --exclude e2e --exclude performance

# Only failed tests from last run
mix test --failed
```

---

## Quality Checklist

Before submitting tests:

- [ ] All tests have descriptive names
- [ ] Arrange-Act-Assert pattern used
- [ ] No test interdependencies
- [ ] Proper cleanup with sandbox
- [ ] Edge cases covered (empty, max, unicode)
- [ ] Error cases covered
- [ ] Concurrency scenarios tested
- [ ] No hardcoded sleep/wait (use `assert_receive`)
- [ ] Tests run in isolation (`async: true` where possible)
- [ ] Mocks are properly verified (`verify_on_exit!`)
- [ ] Factories used instead of fixtures
- [ ] Performance assertions where applicable
- [ ] WebSocket reconnection scenarios tested

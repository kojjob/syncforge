defmodule Syncforge.AnalyticsTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Analytics
  alias Syncforge.Analytics.ConnectionEvent

  import Syncforge.AccountsFixtures

  defp create_org_and_room do
    user = user_fixture()
    {:ok, org, _} = Syncforge.Organizations.create_organization(user, %{name: "Analytics Org"})
    {:ok, room} = Syncforge.Rooms.create_room(%{name: "Test Room", organization_id: org.id})
    {user, org, room}
  end

  describe "record_event/1" do
    test "records a join event" do
      {user, org, room} = create_org_and_room()

      assert {:ok, %ConnectionEvent{event_type: "join"}} =
               Analytics.record_event(%{
                 event_type: "join",
                 organization_id: org.id,
                 room_id: room.id,
                 user_id: user.id
               })
    end

    test "records a leave event" do
      {user, org, room} = create_org_and_room()

      assert {:ok, %ConnectionEvent{event_type: "leave"}} =
               Analytics.record_event(%{
                 event_type: "leave",
                 organization_id: org.id,
                 room_id: room.id,
                 user_id: user.id
               })
    end

    test "rejects invalid event type" do
      assert {:error, changeset} = Analytics.record_event(%{event_type: "invalid"})
      assert %{event_type: ["is invalid"]} = errors_on(changeset)
    end

    test "requires event_type" do
      assert {:error, changeset} = Analytics.record_event(%{})
      assert %{event_type: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "total_connections/2" do
    test "counts join events in period" do
      {user, org, room} = create_org_and_room()
      since = Analytics.period_start("24h")

      Analytics.record_event(%{
        event_type: "join",
        organization_id: org.id,
        room_id: room.id,
        user_id: user.id
      })

      Analytics.record_event(%{
        event_type: "join",
        organization_id: org.id,
        room_id: room.id,
        user_id: user.id
      })

      # Leave events should not be counted
      Analytics.record_event(%{
        event_type: "leave",
        organization_id: org.id,
        room_id: room.id,
        user_id: user.id
      })

      assert Analytics.total_connections(org.id, since) == 2
    end
  end

  describe "unique_users/2" do
    test "counts distinct users" do
      {user, org, room} = create_org_and_room()
      user2 = user_fixture()
      since = Analytics.period_start("24h")

      # Same user joins twice
      Analytics.record_event(%{
        event_type: "join",
        organization_id: org.id,
        room_id: room.id,
        user_id: user.id
      })

      Analytics.record_event(%{
        event_type: "join",
        organization_id: org.id,
        room_id: room.id,
        user_id: user.id
      })

      # Different user joins once
      Analytics.record_event(%{
        event_type: "join",
        organization_id: org.id,
        room_id: room.id,
        user_id: user2.id
      })

      assert Analytics.unique_users(org.id, since) == 2
    end
  end

  describe "active_rooms/2" do
    test "counts distinct rooms" do
      {user, org, room} = create_org_and_room()
      {:ok, room2} = Syncforge.Rooms.create_room(%{name: "Room 2", organization_id: org.id})
      since = Analytics.period_start("24h")

      # Same room joined twice
      Analytics.record_event(%{
        event_type: "join",
        organization_id: org.id,
        room_id: room.id,
        user_id: user.id
      })

      Analytics.record_event(%{
        event_type: "join",
        organization_id: org.id,
        room_id: room.id,
        user_id: user.id
      })

      # Different room joined once
      Analytics.record_event(%{
        event_type: "join",
        organization_id: org.id,
        room_id: room2.id,
        user_id: user.id
      })

      assert Analytics.active_rooms(org.id, since) == 2
    end
  end

  describe "room_usage_breakdown/3" do
    test "returns rooms sorted by join count" do
      {user, org, room} = create_org_and_room()
      {:ok, room2} = Syncforge.Rooms.create_room(%{name: "Popular", organization_id: org.id})
      since = Analytics.period_start("24h")

      # Room 2 gets 3 joins
      for _ <- 1..3 do
        Analytics.record_event(%{
          event_type: "join",
          organization_id: org.id,
          room_id: room2.id,
          user_id: user.id
        })
      end

      # Room 1 gets 1 join
      Analytics.record_event(%{
        event_type: "join",
        organization_id: org.id,
        room_id: room.id,
        user_id: user.id
      })

      room2_id = room2.id
      room1_id = room.id
      breakdown = Analytics.room_usage_breakdown(org.id, since)

      assert [{^room2_id, 3}, {^room1_id, 1}] = breakdown
    end
  end

  describe "list_recent_events/2" do
    test "returns events newest first" do
      {user, org, room} = create_org_and_room()

      {:ok, e1} =
        Analytics.record_event(%{
          event_type: "join",
          organization_id: org.id,
          room_id: room.id,
          user_id: user.id
        })

      {:ok, e2} =
        Analytics.record_event(%{
          event_type: "leave",
          organization_id: org.id,
          room_id: room.id,
          user_id: user.id
        })

      events = Analytics.list_recent_events(org.id)
      assert [%{id: id2}, %{id: id1}] = events
      assert id2 == e2.id
      assert id1 == e1.id
    end
  end

  describe "period_start/1" do
    test "returns datetime for 24h period" do
      result = Analytics.period_start("24h")
      assert DateTime.diff(DateTime.utc_now(), result, :hour) in 23..24
    end

    test "returns datetime for 7d period" do
      result = Analytics.period_start("7d")
      assert DateTime.diff(DateTime.utc_now(), result, :day) in 6..7
    end

    test "returns datetime for 30d period" do
      result = Analytics.period_start("30d")
      assert DateTime.diff(DateTime.utc_now(), result, :day) in 29..30
    end

    test "defaults to 24h for unknown period" do
      result = Analytics.period_start("unknown")
      assert DateTime.diff(DateTime.utc_now(), result, :hour) in 23..24
    end
  end
end

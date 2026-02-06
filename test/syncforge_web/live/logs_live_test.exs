defmodule SyncforgeWeb.LogsLiveTest do
  use SyncforgeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Syncforge.AccountsFixtures

  alias Syncforge.{Organizations, Analytics}

  describe "GET /dashboard/logs" do
    test "redirects unauthenticated user to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/dashboard/logs")
    end

    test "renders logs page for authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/logs")

      assert html =~ "Logs"
    end

    test "shows recent events", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "My Org"})
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Log Room", organization_id: org.id})

      Analytics.record_event(%{
        event_type: "join",
        organization_id: org.id,
        room_id: room.id,
        user_id: user.id
      })

      {:ok, _lv, html} = live(conn, ~p"/dashboard/logs")

      assert html =~ "join"
    end

    test "shows empty state when no events", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, _org, _} = Organizations.create_organization(user, %{name: "My Org"})

      {:ok, _lv, html} = live(conn, ~p"/dashboard/logs")

      assert html =~ "No events yet"
    end

    test "shows no-org message when user has no organizations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/logs")

      assert html =~ "Create an organization"
    end

    test "receives real-time events via PubSub", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "My Org"})
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Live Room", organization_id: org.id})

      {:ok, lv, html} = live(conn, ~p"/dashboard/logs")

      refute html =~ "Live Room"

      # Simulate a new event broadcast
      {:ok, event} =
        Analytics.record_event(%{
          event_type: "join",
          organization_id: org.id,
          room_id: room.id,
          user_id: user.id
        })

      event = Syncforge.Repo.preload(event, [:user, :room])

      Phoenix.PubSub.broadcast(
        Syncforge.PubSub,
        "org_logs:#{org.id}",
        {:new_event, event}
      )

      # The LiveView should receive and render the event
      html = render(lv)
      assert html =~ "join"
    end
  end
end

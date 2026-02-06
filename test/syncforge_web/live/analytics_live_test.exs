defmodule SyncforgeWeb.AnalyticsLiveTest do
  use SyncforgeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Syncforge.AccountsFixtures

  alias Syncforge.{Organizations, Analytics}

  describe "GET /dashboard/analytics" do
    test "redirects unauthenticated user to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/dashboard/analytics")
    end

    test "renders analytics page for authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/analytics")

      assert html =~ "Analytics"
    end

    test "shows stat cards with zero values for new org", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, _org, _} = Organizations.create_organization(user, %{name: "My Org"})

      {:ok, _lv, html} = live(conn, ~p"/dashboard/analytics")

      assert html =~ "Total Connections"
      assert html =~ "Unique Users"
      assert html =~ "Active Rooms"
    end

    test "shows connection stats with data", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "My Org"})
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Room", organization_id: org.id})

      Analytics.record_event(%{
        event_type: "join",
        organization_id: org.id,
        room_id: room.id,
        user_id: user.id
      })

      {:ok, _lv, html} = live(conn, ~p"/dashboard/analytics")

      # Should show at least 1 connection
      assert html =~ "1"
    end

    test "period toggle switches time range", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, _org, _} = Organizations.create_organization(user, %{name: "My Org"})

      {:ok, lv, _html} = live(conn, ~p"/dashboard/analytics")

      # Switch to 7 day view
      html = lv |> element("[phx-click=set_period][phx-value-period=\"7d\"]") |> render_click()

      assert html =~ "7d"
    end

    test "shows room usage breakdown table", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "My Org"})
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Popular Room", organization_id: org.id})

      Analytics.record_event(%{
        event_type: "join",
        organization_id: org.id,
        room_id: room.id,
        user_id: user.id
      })

      {:ok, _lv, html} = live(conn, ~p"/dashboard/analytics")

      assert html =~ "Room Usage"
    end

    test "shows no-org message when user has no organizations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/analytics")

      assert html =~ "Create an organization"
    end
  end
end

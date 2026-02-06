defmodule SyncforgeWeb.RoomsLiveTest do
  use SyncforgeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Syncforge.AccountsFixtures

  alias Syncforge.Organizations
  alias Syncforge.Rooms

  describe "GET /dashboard/rooms" do
    test "redirects unauthenticated user to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/dashboard/rooms")
    end

    test "renders rooms page for authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/rooms")

      assert html =~ "Rooms"
    end

    test "shows empty state when org has no rooms", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, _org, _} = Organizations.create_organization(user, %{name: "Empty Org"})

      {:ok, _lv, html} = live(conn, ~p"/dashboard/rooms")

      assert html =~ "No rooms yet"
    end

    test "lists rooms belonging to the current org", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "My Org"})

      {:ok, _room} =
        Rooms.create_room(%{name: "Design Review", type: :document, organization_id: org.id})

      {:ok, _room2} =
        Rooms.create_room(%{name: "Standup", type: :video, organization_id: org.id})

      {:ok, _lv, html} = live(conn, ~p"/dashboard/rooms")

      assert html =~ "Design Review"
      assert html =~ "Standup"
      assert html =~ "document"
      assert html =~ "video"
    end

    test "creates a new room for the current org", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, _org, _} = Organizations.create_organization(user, %{name: "My Org"})

      {:ok, lv, _html} = live(conn, ~p"/dashboard/rooms")

      html =
        lv
        |> form("#create-room-form", room: %{name: "New Room", type: "general"})
        |> render_submit()

      assert html =~ "Room created"
      assert html =~ "New Room"
    end

    test "deletes a room", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "My Org"})

      {:ok, room} =
        Rooms.create_room(%{name: "To Delete", organization_id: org.id})

      {:ok, lv, html} = live(conn, ~p"/dashboard/rooms")

      assert html =~ "To Delete"

      html =
        lv
        |> element("[phx-click=delete_room][phx-value-id=\"#{room.id}\"]")
        |> render_click()

      refute html =~ "To Delete"
      assert html =~ "Room deleted"
    end

    test "shows no-org message when user has no organizations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/rooms")

      assert html =~ "Create an organization"
    end

    test "does not show rooms from other organizations", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _my_org, _} = Organizations.create_organization(user, %{name: "My Org"})
      {:ok, other_org, _} = Organizations.create_organization(other_user, %{name: "Other Org"})

      {:ok, _other_room} =
        Rooms.create_room(%{name: "Secret Room", organization_id: other_org.id})

      {:ok, _lv, html} = live(conn, ~p"/dashboard/rooms")

      refute html =~ "Secret Room"
    end

    test "shows room type badges", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "My Org"})

      {:ok, _} =
        Rooms.create_room(%{name: "Whiteboard", type: :whiteboard, organization_id: org.id})

      {:ok, _} = Rooms.create_room(%{name: "Canvas", type: :canvas, organization_id: org.id})

      {:ok, _lv, html} = live(conn, ~p"/dashboard/rooms")

      assert html =~ "whiteboard"
      assert html =~ "canvas"
    end

    test "allows switching organizations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org1, _} = Organizations.create_organization(user, %{name: "Org Alpha"})
      {:ok, org2, _} = Organizations.create_organization(user, %{name: "Org Beta"})

      {:ok, _} = Rooms.create_room(%{name: "Alpha Room", organization_id: org1.id})
      {:ok, _} = Rooms.create_room(%{name: "Beta Room", organization_id: org2.id})

      {:ok, lv, html} = live(conn, ~p"/dashboard/rooms")

      # Default picks first org (Org Alpha)
      assert html =~ "Alpha Room"
      refute html =~ "Beta Room"

      # Switch to Org Beta
      html = lv |> element("#org-picker") |> render_change(%{org_id: org2.id})

      assert html =~ "Beta Room"
      refute html =~ "Alpha Room"
    end
  end
end

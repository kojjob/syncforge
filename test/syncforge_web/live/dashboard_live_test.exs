defmodule SyncforgeWeb.DashboardLiveTest do
  use SyncforgeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Syncforge.AccountsFixtures

  describe "GET /dashboard" do
    test "redirects unauthenticated user to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/dashboard")
    end

    test "renders dashboard for authenticated user", %{conn: conn} do
      user = user_fixture(%{name: "Alice"})
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Dashboard"
      assert html =~ "Welcome, Alice!"
    end

    test "shows flash error when redirected from protected page", %{conn: conn} do
      result = live(conn, ~p"/dashboard")

      assert {:error, {:redirect, %{to: "/login", flash: flash}}} = result
      assert flash["error"] =~ "You must log in"
    end

    test "redirects to login if session user no longer exists", %{conn: conn} do
      # Create user, log in, then delete user from DB
      user = user_fixture()
      conn = log_in_user(conn, user)

      Syncforge.Repo.delete!(user)

      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/dashboard")
    end

    test "shows getting-started checklist for user with no orgs", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Getting Started"
      assert html =~ "Create your first organization"
    end

    test "shows stat cards when user has an organization", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _org, _membership} =
        Syncforge.Organizations.create_organization(user, %{name: "My Org"})

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Rooms"
      assert html =~ "Members"
      assert html =~ "API Keys"
    end

    test "shows org picker for users with multiple orgs", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _org1, _} =
        Syncforge.Organizations.create_organization(user, %{name: "Org Alpha"})

      {:ok, _org2, _} =
        Syncforge.Organizations.create_organization(user, %{name: "Org Beta"})

      {:ok, _lv, html} = live(conn, ~p"/dashboard")

      assert html =~ "Org Alpha"
    end

    test "allows switching organizations via org picker", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _org1, _} =
        Syncforge.Organizations.create_organization(user, %{name: "First Org"})

      {:ok, org2, _} =
        Syncforge.Organizations.create_organization(user, %{name: "Second Org"})

      {:ok, lv, html} = live(conn, ~p"/dashboard")

      # Default should show first org
      assert html =~ "First Org"

      # Switch to second org
      html = lv |> element("#org-picker") |> render_change(%{org_id: org2.id})

      assert html =~ "Second Org"
    end

    test "create org button works from getting-started", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/dashboard")

      html =
        lv
        |> form("#create-org-form", org: %{name: "New Dashboard Org"})
        |> render_submit()

      assert html =~ "Organization created"
      assert html =~ "New Dashboard Org"
    end
  end
end

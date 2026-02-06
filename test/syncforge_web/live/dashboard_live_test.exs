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
  end
end

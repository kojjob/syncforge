defmodule SyncforgeWeb.UserLoginLiveTest do
  use SyncforgeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Syncforge.AccountsFixtures

  describe "GET /login" do
    test "renders the login page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/login")

      assert html =~ "Sign in to SyncForge"
      assert html =~ "Sign up"
    end

    test "has a link to the register page", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/login")

      {:ok, _register_lv, register_html} =
        lv
        |> element("a", "Sign up")
        |> render_click()
        |> follow_redirect(conn)

      assert register_html =~ "Create your account"
    end

    test "redirects authenticated user to dashboard", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/login")
    end
  end
end

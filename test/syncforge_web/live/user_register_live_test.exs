defmodule SyncforgeWeb.UserRegisterLiveTest do
  use SyncforgeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Syncforge.AccountsFixtures

  describe "GET /register" do
    test "renders the registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/register")

      assert html =~ "Create your account"
      assert html =~ "Sign in"
    end

    test "redirects authenticated user to dashboard", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: "/dashboard"}}} = live(conn, ~p"/register")
    end
  end

  describe "register form" do
    test "validates form on change", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      result =
        lv
        |> form("#user-form", user: %{email: "bad", password: "short", name: ""})
        |> render_change()

      assert result =~ "has invalid format" or result =~ "should be at least"
    end

    test "creates account and redirects to login on valid submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/register")

      result =
        lv
        |> form("#user-form",
          user: %{name: "Test User", email: "new@example.com", password: "valid_password123"}
        )
        |> render_submit()

      assert {:error, {:redirect, %{to: "/login"}}} = result
    end

    test "shows errors on duplicate email", %{conn: conn} do
      existing = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/register")

      result =
        lv
        |> form("#user-form",
          user: %{name: "Test", email: existing.email, password: "valid_password123"}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end
end

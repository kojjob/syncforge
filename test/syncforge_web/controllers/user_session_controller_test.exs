defmodule SyncforgeWeb.UserSessionControllerTest do
  use SyncforgeWeb.ConnCase, async: true

  import Syncforge.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{user: user, conn: conn}
  end

  describe "POST /session" do
    test "logs in the user with valid credentials", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/session", %{
          "email" => user.email,
          "password" => "valid_password123"
        })

      assert redirected_to(conn) == "/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back"
      assert get_session(conn, :user_id) == user.id
    end

    test "redirects to login with invalid password", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/session", %{
          "email" => user.email,
          "password" => "wrong_password"
        })

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid email or password"
    end

    test "redirects to login with non-existent email", %{conn: conn} do
      conn =
        post(conn, ~p"/session", %{
          "email" => "nonexistent@example.com",
          "password" => "any_password123"
        })

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid email or password"
    end

    test "redirects to login when email param is missing", %{conn: conn} do
      conn = post(conn, ~p"/session", %{"password" => "some_password"})

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid email or password"
    end

    test "redirects to login when password param is missing", %{conn: conn} do
      conn = post(conn, ~p"/session", %{"email" => "test@example.com"})

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid email or password"
    end

    test "redirects to login when both params are missing", %{conn: conn} do
      conn = post(conn, ~p"/session", %{})

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid email or password"
    end

    test "renews the session on login to prevent fixation", %{conn: conn, user: user} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{canary: "chirp"})
        |> post(~p"/session", %{
          "email" => user.email,
          "password" => "valid_password123"
        })

      # Old session value should be cleared after renew
      refute get_session(conn, :canary)
      assert get_session(conn, :user_id) == user.id
    end
  end

  describe "DELETE /session" do
    test "logs the user out", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> delete(~p"/session")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out"
      refute get_session(conn, :user_id)
    end
  end
end

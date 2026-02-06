defmodule SyncforgeWeb.AuthControllerTest do
  use SyncforgeWeb.ConnCase, async: true

  import Syncforge.AccountsFixtures

  alias Syncforge.Accounts

  @register_attrs %{
    "user" => %{
      "email" => "new@example.com",
      "password" => "password123",
      "name" => "New User"
    }
  }

  describe "POST /api/register" do
    test "with valid params returns 201 + user + token", %{conn: conn} do
      conn = post(conn, "/api/register", @register_attrs)
      response = json_response(conn, 201)

      assert response["token"]
      assert response["user"]["email"] == "new@example.com"
      assert response["user"]["name"] == "New User"
      assert response["user"]["id"]
    end

    test "with invalid email returns 422", %{conn: conn} do
      attrs = put_in(@register_attrs, ["user", "email"], "not-valid")
      conn = post(conn, "/api/register", attrs)
      response = json_response(conn, 422)

      assert response["errors"]["email"]
    end

    test "with short password returns 422", %{conn: conn} do
      attrs = put_in(@register_attrs, ["user", "password"], "short")
      conn = post(conn, "/api/register", attrs)
      response = json_response(conn, 422)

      assert response["errors"]["password"]
    end

    test "with duplicate email returns 422", %{conn: conn} do
      user_fixture(%{email: "dupe@example.com"})
      attrs = put_in(@register_attrs, ["user", "email"], "dupe@example.com")
      conn = post(conn, "/api/register", attrs)
      response = json_response(conn, 422)

      assert response["errors"]["email"]
    end

    test "with missing fields returns 422", %{conn: conn} do
      conn = post(conn, "/api/register", %{"user" => %{}})
      response = json_response(conn, 422)

      assert response["errors"]
    end
  end

  describe "POST /api/login" do
    test "with correct credentials returns 200 + user + token", %{conn: conn} do
      user_fixture(%{email: "login@example.com", password: "password123"})

      conn =
        post(conn, "/api/login", %{"email" => "login@example.com", "password" => "password123"})

      response = json_response(conn, 200)

      assert response["token"]
      assert response["user"]["email"] == "login@example.com"
    end

    test "with wrong password returns 401", %{conn: conn} do
      user_fixture(%{email: "login2@example.com", password: "password123"})

      conn = post(conn, "/api/login", %{"email" => "login2@example.com", "password" => "wrong"})
      response = json_response(conn, 401)

      assert response["error"] == "Invalid email or password"
    end

    test "with non-existent email returns 401", %{conn: conn} do
      conn = post(conn, "/api/login", %{"email" => "nope@example.com", "password" => "any"})
      assert json_response(conn, 401)["error"]
    end
  end

  describe "GET /api/me" do
    test "with valid token returns 200 + user", %{conn: conn} do
      user = user_fixture(%{email: "me@example.com"})

      token =
        Phoenix.Token.sign(SyncforgeWeb.Endpoint, "user socket", %{
          id: user.id,
          name: user.name,
          avatar_url: user.avatar_url
        })

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/me")

      response = json_response(conn, 200)
      assert response["user"]["email"] == "me@example.com"
    end

    test "without token returns 401", %{conn: conn} do
      conn = get(conn, "/api/me")
      assert json_response(conn, 401)["error"]
    end

    test "with invalid token returns 401", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid_token")
        |> get("/api/me")

      assert json_response(conn, 401)["error"]
    end

    test "token from register can be used for /api/me", %{conn: conn} do
      conn1 = post(conn, "/api/register", @register_attrs)
      %{"token" => token} = json_response(conn1, 201)

      conn2 =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/me")

      response = json_response(conn2, 200)
      assert response["user"]["email"] == "new@example.com"
    end
  end

  # ── Forgot Password ──

  describe "POST /api/forgot-password" do
    test "with existing email returns 200 + message", %{conn: conn} do
      user_fixture(%{email: "forgot@example.com"})

      conn = post(conn, "/api/forgot-password", %{"email" => "forgot@example.com"})
      response = json_response(conn, 200)

      assert response["message"] =~ "If an account exists"
    end

    test "with non-existent email returns 200 (no leak)", %{conn: conn} do
      conn = post(conn, "/api/forgot-password", %{"email" => "nope@example.com"})
      response = json_response(conn, 200)

      assert response["message"] =~ "If an account exists"
    end

    test "with missing email returns 422", %{conn: conn} do
      conn = post(conn, "/api/forgot-password", %{})
      assert json_response(conn, 422)
    end
  end

  # ── Reset Password ──

  describe "POST /api/reset-password" do
    test "with valid token and new password returns 200", %{conn: conn} do
      user = user_fixture(%{email: "reset@example.com"})
      token = set_password_reset_token(user)

      conn =
        post(conn, "/api/reset-password", %{"token" => token, "password" => "new_password123"})

      response = json_response(conn, 200)
      assert response["message"] =~ "Password reset"
    end

    test "with invalid token returns 401", %{conn: conn} do
      conn =
        post(conn, "/api/reset-password", %{
          "token" => "bogus_token",
          "password" => "new_password123"
        })

      assert json_response(conn, 401)["error"]
    end

    test "with expired token returns 401", %{conn: conn} do
      user = user_fixture(%{email: "expired@example.com"})
      token = set_password_reset_token(user, hours_ago: 2)

      conn =
        post(conn, "/api/reset-password", %{"token" => token, "password" => "new_password123"})

      assert json_response(conn, 401)["error"]
    end

    test "with short password returns 422", %{conn: conn} do
      user = user_fixture(%{email: "short@example.com"})
      token = set_password_reset_token(user)

      conn = post(conn, "/api/reset-password", %{"token" => token, "password" => "short"})
      response = json_response(conn, 422)

      assert response["errors"]["password"]
    end
  end

  # ── Confirm Email ──

  describe "POST /api/confirm-email" do
    test "with valid token returns 200 + user", %{conn: conn} do
      user = user_fixture(%{email: "confirm@example.com"})
      token = set_confirmation_token(user)

      conn = post(conn, "/api/confirm-email", %{"token" => token})
      response = json_response(conn, 200)

      assert response["user"]["email"] == "confirm@example.com"
    end

    test "with invalid token returns 401", %{conn: conn} do
      conn = post(conn, "/api/confirm-email", %{"token" => "bogus_token"})
      assert json_response(conn, 401)["error"]
    end

    test "with expired token returns 401", %{conn: conn} do
      user = user_fixture(%{email: "expired_confirm@example.com"})
      token = set_confirmation_token(user, days_ago: 8)

      conn = post(conn, "/api/confirm-email", %{"token" => token})
      assert json_response(conn, 401)["error"]
    end
  end

  # ── Resend Confirmation (Protected) ──

  describe "POST /api/resend-confirmation" do
    test "with valid auth sends email", %{conn: conn} do
      user = user_fixture(%{email: "resend@example.com"})

      conn =
        conn
        |> authenticate(user)
        |> post("/api/resend-confirmation")

      response = json_response(conn, 200)
      assert response["message"] =~ "Confirmation email sent"
    end

    test "for already-confirmed user returns 422", %{conn: conn} do
      user = user_fixture(%{email: "already@example.com"})

      {:ok, confirmed} =
        user
        |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now()})
        |> Syncforge.Repo.update()

      conn =
        conn
        |> authenticate(confirmed)
        |> post("/api/resend-confirmation")

      assert json_response(conn, 422)["error"]
    end

    test "without auth returns 401", %{conn: conn} do
      conn = post(conn, "/api/resend-confirmation")
      assert json_response(conn, 401)["error"]
    end
  end

  # ── Test Helpers ──

  defp authenticate(conn, user) do
    token =
      Phoenix.Token.sign(SyncforgeWeb.Endpoint, "user socket", %{
        id: user.id,
        name: user.name,
        avatar_url: user.avatar_url
      })

    put_req_header(conn, "authorization", "Bearer #{token}")
  end

  defp set_password_reset_token(user, opts \\ []) do
    token = Accounts.generate_token()
    hash = Accounts.hash_token(token)

    sent_at =
      case Keyword.get(opts, :hours_ago) do
        nil -> DateTime.utc_now()
        hours -> DateTime.add(DateTime.utc_now(), -hours * 3600, :second)
      end

    user
    |> Ecto.Changeset.change(%{
      reset_password_token_hash: hash,
      reset_password_sent_at: sent_at
    })
    |> Syncforge.Repo.update!()

    token
  end

  defp set_confirmation_token(user, opts \\ []) do
    token = Accounts.generate_token()
    hash = Accounts.hash_token(token)

    sent_at =
      case Keyword.get(opts, :days_ago) do
        nil -> DateTime.utc_now()
        days -> DateTime.add(DateTime.utc_now(), -days * 86400, :second)
      end

    user
    |> Ecto.Changeset.change(%{
      confirmation_token_hash: hash,
      confirmation_sent_at: sent_at
    })
    |> Syncforge.Repo.update!()

    token
  end
end

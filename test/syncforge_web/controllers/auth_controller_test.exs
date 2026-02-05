defmodule SyncforgeWeb.AuthControllerTest do
  use SyncforgeWeb.ConnCase, async: true

  import Syncforge.AccountsFixtures

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
end

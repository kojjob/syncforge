defmodule SyncforgeWeb.Controllers.ApiKeyRotationControllerTest do
  use SyncforgeWeb.ConnCase, async: true

  alias Syncforge.Organizations

  setup %{conn: conn} do
    user = Syncforge.AccountsFixtures.user_fixture()
    {:ok, org, _membership} = Organizations.create_organization(user, %{name: "RotateOrg"})
    {:ok, api_key, _raw_key} = Organizations.create_api_key(org, %{label: "Test Key"})

    token = Phoenix.Token.sign(SyncforgeWeb.Endpoint, "user socket", user)

    conn =
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")

    %{conn: conn, user: user, org: org, api_key: api_key}
  end

  describe "POST /api/organizations/:org_id/api-keys/:id/rotate" do
    test "rotates an active key and returns the new raw key", %{
      conn: conn,
      org: org,
      api_key: api_key
    } do
      conn =
        post(conn, "/api/organizations/#{org.id}/api-keys/#{api_key.id}/rotate")

      assert %{"api_key" => data} = json_response(conn, 200)
      assert data["id"] != api_key.id
      assert data["status"] == "active"
      assert data["raw_key"] != nil
      assert data["label"] == api_key.label
    end

    test "returns 422 when trying to rotate a revoked key", %{
      conn: conn,
      org: org,
      api_key: api_key
    } do
      {:ok, _} = Organizations.revoke_api_key(api_key)

      conn =
        post(conn, "/api/organizations/#{org.id}/api-keys/#{api_key.id}/rotate")

      assert json_response(conn, 422)["error"] =~ "not active"
    end

    test "returns 404 for non-existent key", %{conn: conn, org: org} do
      conn =
        post(conn, "/api/organizations/#{org.id}/api-keys/#{Ecto.UUID.generate()}/rotate")

      assert json_response(conn, 404)
    end

    test "returns 403 for viewer role", %{conn: _conn, org: org, api_key: api_key} do
      viewer = Syncforge.AccountsFixtures.user_fixture()
      {:ok, _} = Organizations.add_member(org, viewer.id, "viewer")

      token = Phoenix.Token.sign(SyncforgeWeb.Endpoint, "user socket", viewer)

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> put_req_header("content-type", "application/json")
        |> post("/api/organizations/#{org.id}/api-keys/#{api_key.id}/rotate")

      assert json_response(conn, 403)
    end
  end
end

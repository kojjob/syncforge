defmodule SyncforgeWeb.OrganizationControllerTest do
  use SyncforgeWeb.ConnCase, async: true

  import Syncforge.AccountsFixtures
  import Syncforge.OrganizationsFixtures

  alias Syncforge.Organizations

  # ─── Organization CRUD ───────────────────────────────────────

  describe "POST /api/organizations" do
    test "creates organization and returns 201", %{conn: conn} do
      user = user_fixture()
      conn = authenticate(conn, user)

      conn =
        post(conn, "/api/organizations", %{
          "organization" => %{"name" => "Acme Corp"}
        })

      response = json_response(conn, 201)
      assert response["organization"]["name"] == "Acme Corp"
      assert response["organization"]["slug"]
      assert response["organization"]["id"]
      assert response["organization"]["plan_type"] == "free"
    end

    test "returns 422 with invalid params", %{conn: conn} do
      user = user_fixture()
      conn = authenticate(conn, user)

      conn = post(conn, "/api/organizations", %{"organization" => %{"name" => ""}})
      response = json_response(conn, 422)
      assert response["errors"]["name"]
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = post(conn, "/api/organizations", %{"organization" => %{"name" => "Test"}})
      assert json_response(conn, 401)["error"]
    end
  end

  describe "GET /api/organizations" do
    test "lists organizations for current user", %{conn: conn} do
      user = user_fixture()
      {org1, _} = organization_fixture(user, %{name: "Org One"})
      {org2, _} = organization_fixture(user, %{name: "Org Two"})

      conn = authenticate(conn, user)
      conn = get(conn, "/api/organizations")
      response = json_response(conn, 200)

      ids = Enum.map(response["organizations"], & &1["id"])
      assert org1.id in ids
      assert org2.id in ids
    end

    test "returns empty list for user with no orgs", %{conn: conn} do
      user = user_fixture()
      conn = authenticate(conn, user)
      conn = get(conn, "/api/organizations")
      assert json_response(conn, 200)["organizations"] == []
    end
  end

  describe "GET /api/organizations/:id" do
    test "returns organization for a member", %{conn: conn} do
      user = user_fixture()
      {org, _} = organization_fixture(user)

      conn = authenticate(conn, user)
      conn = get(conn, "/api/organizations/#{org.id}")
      response = json_response(conn, 200)
      assert response["organization"]["id"] == org.id
    end

    test "returns 403 for non-member", %{conn: conn} do
      {org, _owner} = organization_fixture()
      outsider = user_fixture(%{email: "outsider@example.com"})

      conn = authenticate(conn, outsider)
      conn = get(conn, "/api/organizations/#{org.id}")
      assert json_response(conn, 403)["error"]
    end

    test "returns 404 for non-existent org", %{conn: conn} do
      user = user_fixture()
      conn = authenticate(conn, user)
      conn = get(conn, "/api/organizations/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)["error"]
    end
  end

  describe "PUT /api/organizations/:id" do
    test "owner can update organization", %{conn: conn} do
      user = user_fixture()
      {org, _} = organization_fixture(user)

      conn = authenticate(conn, user)

      conn =
        put(conn, "/api/organizations/#{org.id}", %{
          "organization" => %{"name" => "Updated Name"}
        })

      response = json_response(conn, 200)
      assert response["organization"]["name"] == "Updated Name"
    end

    test "admin can update organization", %{conn: conn} do
      {org, _owner} = organization_fixture()
      admin = user_fixture(%{email: "admin@example.com"})
      membership_fixture(org, admin, %{role: "admin"})

      conn = authenticate(conn, admin)

      conn =
        put(conn, "/api/organizations/#{org.id}", %{
          "organization" => %{"name" => "Admin Updated"}
        })

      assert json_response(conn, 200)["organization"]["name"] == "Admin Updated"
    end

    test "member cannot update organization", %{conn: conn} do
      {org, _owner} = organization_fixture()
      member = user_fixture(%{email: "member@example.com"})
      membership_fixture(org, member, %{role: "member"})

      conn = authenticate(conn, member)

      conn =
        put(conn, "/api/organizations/#{org.id}", %{
          "organization" => %{"name" => "Should Fail"}
        })

      assert json_response(conn, 403)["error"]
    end
  end

  describe "DELETE /api/organizations/:id" do
    test "owner can delete organization", %{conn: conn} do
      user = user_fixture()
      {org, _} = organization_fixture(user)

      conn = authenticate(conn, user)
      conn = delete(conn, "/api/organizations/#{org.id}")
      assert response(conn, 204)

      assert Organizations.get_organization(org.id) == nil
    end

    test "admin cannot delete organization", %{conn: conn} do
      {org, _owner} = organization_fixture()
      admin = user_fixture(%{email: "admin-del@example.com"})
      membership_fixture(org, admin, %{role: "admin"})

      conn = authenticate(conn, admin)
      conn = delete(conn, "/api/organizations/#{org.id}")
      assert json_response(conn, 403)["error"]
    end
  end

  # ─── Membership Management ──────────────────────────────────

  describe "POST /api/organizations/:organization_id/members" do
    test "owner can add a member", %{conn: conn} do
      user = user_fixture()
      {org, _} = organization_fixture(user)
      new_member = user_fixture(%{email: "newmember@example.com"})

      conn = authenticate(conn, user)

      conn =
        post(conn, "/api/organizations/#{org.id}/members", %{
          "user_id" => new_member.id,
          "role" => "member"
        })

      response = json_response(conn, 201)
      assert response["membership"]["user_id"] == new_member.id
      assert response["membership"]["role"] == "member"
    end

    test "non-admin cannot add members", %{conn: conn} do
      {org, _owner} = organization_fixture()
      member = user_fixture(%{email: "regular@example.com"})
      membership_fixture(org, member, %{role: "member"})
      new_user = user_fixture(%{email: "another@example.com"})

      conn = authenticate(conn, member)

      conn =
        post(conn, "/api/organizations/#{org.id}/members", %{
          "user_id" => new_user.id,
          "role" => "member"
        })

      assert json_response(conn, 403)["error"]
    end
  end

  describe "DELETE /api/organizations/:organization_id/members/:user_id" do
    test "owner can remove a member", %{conn: conn} do
      user = user_fixture()
      {org, _} = organization_fixture(user)
      member = user_fixture(%{email: "removable@example.com"})
      membership_fixture(org, member, %{role: "member"})

      conn = authenticate(conn, user)
      conn = delete(conn, "/api/organizations/#{org.id}/members/#{member.id}")
      assert response(conn, 204)
    end

    test "cannot remove last owner", %{conn: conn} do
      user = user_fixture()
      {org, _} = organization_fixture(user)

      conn = authenticate(conn, user)
      conn = delete(conn, "/api/organizations/#{org.id}/members/#{user.id}")
      assert json_response(conn, 422)["error"] =~ "last owner"
    end
  end

  describe "PUT /api/organizations/:organization_id/members/:user_id/role" do
    test "owner can update member role", %{conn: conn} do
      user = user_fixture()
      {org, _} = organization_fixture(user)
      member = user_fixture(%{email: "promote@example.com"})
      membership_fixture(org, member, %{role: "member"})

      conn = authenticate(conn, user)

      conn =
        put(conn, "/api/organizations/#{org.id}/members/#{member.id}/role", %{
          "role" => "admin"
        })

      response = json_response(conn, 200)
      assert response["membership"]["role"] == "admin"
    end

    test "member cannot update roles", %{conn: conn} do
      {org, _owner} = organization_fixture()
      member = user_fixture(%{email: "norole@example.com"})
      membership_fixture(org, member, %{role: "member"})
      other = user_fixture(%{email: "other@example.com"})
      membership_fixture(org, other, %{role: "viewer"})

      conn = authenticate(conn, member)

      conn =
        put(conn, "/api/organizations/#{org.id}/members/#{other.id}/role", %{
          "role" => "admin"
        })

      assert json_response(conn, 403)["error"]
    end
  end

  # ─── API Key Management ─────────────────────────────────────

  describe "POST /api/organizations/:organization_id/api-keys" do
    test "creates api key and returns raw key", %{conn: conn} do
      user = user_fixture()
      {org, _} = organization_fixture(user)

      conn = authenticate(conn, user)

      conn =
        post(conn, "/api/organizations/#{org.id}/api-keys", %{
          "label" => "Production Key"
        })

      response = json_response(conn, 201)
      assert response["api_key"]["label"] == "Production Key"
      assert response["api_key"]["raw_key"]
      assert String.starts_with?(response["api_key"]["raw_key"], "sf_pub_")
    end

    test "non-admin cannot create api keys", %{conn: conn} do
      {org, _owner} = organization_fixture()
      viewer = user_fixture(%{email: "viewer@example.com"})
      membership_fixture(org, viewer, %{role: "viewer"})

      conn = authenticate(conn, viewer)

      conn =
        post(conn, "/api/organizations/#{org.id}/api-keys", %{
          "label" => "Should Fail"
        })

      assert json_response(conn, 403)["error"]
    end
  end

  describe "GET /api/organizations/:organization_id/api-keys" do
    test "member can list api keys", %{conn: conn} do
      user = user_fixture()
      {org, _} = organization_fixture(user)
      {_key, _raw} = api_key_fixture(org, %{label: "Key 1"})
      {_key2, _raw2} = api_key_fixture(org, %{label: "Key 2"})

      conn = authenticate(conn, user)
      conn = get(conn, "/api/organizations/#{org.id}/api-keys")
      response = json_response(conn, 200)

      assert length(response["api_keys"]) == 2
    end

    test "non-member cannot list api keys", %{conn: conn} do
      {org, _owner} = organization_fixture()
      outsider = user_fixture(%{email: "outsider-keys@example.com"})

      conn = authenticate(conn, outsider)
      conn = get(conn, "/api/organizations/#{org.id}/api-keys")
      assert json_response(conn, 403)["error"]
    end
  end

  describe "DELETE /api/organizations/:organization_id/api-keys/:id" do
    test "owner can revoke api key", %{conn: conn} do
      user = user_fixture()
      {org, _} = organization_fixture(user)
      {key, _raw} = api_key_fixture(org)

      conn = authenticate(conn, user)
      conn = delete(conn, "/api/organizations/#{org.id}/api-keys/#{key.id}")
      response = json_response(conn, 200)

      assert response["api_key"]["status"] == "revoked"
    end

    test "returns 404 for key from different org", %{conn: conn} do
      user = user_fixture()
      {org, _} = organization_fixture(user)
      {other_org, _other_owner} = organization_fixture()
      {other_key, _raw} = api_key_fixture(other_org)

      conn = authenticate(conn, user)
      conn = delete(conn, "/api/organizations/#{org.id}/api-keys/#{other_key.id}")
      assert json_response(conn, 404)["error"]
    end
  end

  # ─── Helpers ────────────────────────────────────────────────

  defp authenticate(conn, user) do
    token =
      Phoenix.Token.sign(SyncforgeWeb.Endpoint, "user socket", %{
        id: user.id,
        name: user.name,
        avatar_url: user.avatar_url
      })

    put_req_header(conn, "authorization", "Bearer #{token}")
  end
end

defmodule SyncforgeWeb.BillingControllerTest do
  use SyncforgeWeb.ConnCase, async: true

  import Mox
  import Syncforge.AccountsFixtures
  import Syncforge.OrganizationsFixtures
  import Syncforge.BillingFixtures

  setup :verify_on_exit!

  describe "POST /api/organizations/:org_id/billing/checkout" do
    test "returns checkout URL for owner", %{conn: conn} do
      {org, owner} = organization_with_stripe()

      Syncforge.Billing.StripeClientMock
      |> expect(:create_checkout_session, fn _params ->
        {:ok, %{url: "https://checkout.stripe.com/test"}}
      end)

      conn =
        conn
        |> authenticate(owner)
        |> post("/api/organizations/#{org.id}/billing/checkout", %{
          "plan" => "pro",
          "return_url" => "https://app.example.com/billing"
        })

      response = json_response(conn, 200)
      assert response["url"] == "https://checkout.stripe.com/test"
    end

    test "returns 403 for non-owner/admin member", %{conn: conn} do
      {org, _owner} = organization_fixture()
      member = user_fixture()
      _membership = membership_fixture(org, member, %{role: "member"})

      conn =
        conn
        |> authenticate(member)
        |> post("/api/organizations/#{org.id}/billing/checkout", %{
          "plan" => "pro",
          "return_url" => "https://example.com"
        })

      assert json_response(conn, 403)["error"]
    end

    test "returns 401 without auth", %{conn: conn} do
      {org, _owner} = organization_fixture()

      conn = post(conn, "/api/organizations/#{org.id}/billing/checkout", %{"plan" => "pro"})
      assert json_response(conn, 401)["error"]
    end

    test "returns 422 for free plan", %{conn: conn} do
      {org, owner} = organization_fixture()

      conn =
        conn
        |> authenticate(owner)
        |> post("/api/organizations/#{org.id}/billing/checkout", %{
          "plan" => "free",
          "return_url" => "https://example.com"
        })

      assert json_response(conn, 422)["error"]
    end
  end

  describe "POST /api/organizations/:org_id/billing/portal" do
    test "returns portal URL for admin", %{conn: conn} do
      {org, owner} = organization_with_stripe()

      Syncforge.Billing.StripeClientMock
      |> expect(:create_portal_session, fn _params ->
        {:ok, %{url: "https://billing.stripe.com/portal"}}
      end)

      conn =
        conn
        |> authenticate(owner)
        |> post("/api/organizations/#{org.id}/billing/portal", %{
          "return_url" => "https://app.example.com/billing"
        })

      response = json_response(conn, 200)
      assert response["url"] == "https://billing.stripe.com/portal"
    end

    test "returns 422 when no Stripe customer exists", %{conn: conn} do
      {org, owner} = organization_fixture()

      conn =
        conn
        |> authenticate(owner)
        |> post("/api/organizations/#{org.id}/billing/portal", %{
          "return_url" => "https://example.com"
        })

      assert json_response(conn, 422)["error"]
    end
  end

  describe "GET /api/organizations/:org_id/billing/subscription" do
    test "returns subscription info", %{conn: conn} do
      {org, owner} = organization_with_stripe(%{plan_type: "pro"})

      conn =
        conn
        |> authenticate(owner)
        |> get("/api/organizations/#{org.id}/billing/subscription")

      response = json_response(conn, 200)
      assert response["subscription"]["plan_type"] == "pro"
      assert response["subscription"]["status"] == "active"
      assert response["subscription"]["stripe_subscription_id"]
    end

    test "returns free plan info for org without subscription", %{conn: conn} do
      {org, owner} = organization_fixture()

      conn =
        conn
        |> authenticate(owner)
        |> get("/api/organizations/#{org.id}/billing/subscription")

      response = json_response(conn, 200)
      assert response["subscription"]["plan_type"] == "free"
      assert response["subscription"]["status"] == "none"
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

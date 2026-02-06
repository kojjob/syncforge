defmodule Syncforge.BillingTest do
  use Syncforge.DataCase, async: true

  import Mox
  import Syncforge.OrganizationsFixtures
  import Syncforge.BillingFixtures

  alias Syncforge.Billing

  setup :verify_on_exit!

  describe "get_or_create_stripe_customer/1" do
    test "creates a Stripe customer when org has no stripe_customer_id" do
      {org, _owner} = organization_fixture()

      Syncforge.Billing.StripeClientMock
      |> expect(:create_customer, fn params ->
        assert params[:email] == nil
        assert params[:metadata][:organization_id] == org.id
        {:ok, %{id: "cus_new_123"}}
      end)

      assert {:ok, updated_org} = Billing.get_or_create_stripe_customer(org)
      assert updated_org.stripe_customer_id == "cus_new_123"
    end

    test "returns existing org when stripe_customer_id already set" do
      {org, _owner} = organization_with_stripe(%{stripe_customer_id: "cus_existing"})

      # No mock expectation — should NOT call Stripe
      assert {:ok, returned_org} = Billing.get_or_create_stripe_customer(org)
      assert returned_org.stripe_customer_id == "cus_existing"
    end

    test "returns error when Stripe API fails" do
      {org, _owner} = organization_fixture()

      Syncforge.Billing.StripeClientMock
      |> expect(:create_customer, fn _params ->
        {:error, %{message: "API error"}}
      end)

      assert {:error, _reason} = Billing.get_or_create_stripe_customer(org)
    end
  end

  describe "create_checkout_session/3" do
    test "creates a checkout session URL for a valid plan" do
      {org, _owner} = organization_with_stripe()

      Syncforge.Billing.StripeClientMock
      |> expect(:create_checkout_session, fn params ->
        assert params[:mode] == "subscription"
        assert params[:customer] == org.stripe_customer_id
        assert is_list(params[:line_items])
        {:ok, %{url: "https://checkout.stripe.com/test_session"}}
      end)

      assert {:ok, url} =
               Billing.create_checkout_session(org, "pro", "https://app.example.com/billing")

      assert url == "https://checkout.stripe.com/test_session"
    end

    test "creates Stripe customer first if org doesn't have one" do
      {org, _owner} = organization_fixture()

      Syncforge.Billing.StripeClientMock
      |> expect(:create_customer, fn _params ->
        {:ok, %{id: "cus_lazy_create"}}
      end)
      |> expect(:create_checkout_session, fn params ->
        assert params[:customer] == "cus_lazy_create"
        {:ok, %{url: "https://checkout.stripe.com/lazy"}}
      end)

      assert {:ok, url} =
               Billing.create_checkout_session(org, "starter", "https://app.example.com/billing")

      assert url == "https://checkout.stripe.com/lazy"
    end

    test "returns error for free plan (no Stripe price)" do
      {org, _owner} = organization_fixture()

      assert {:error, :no_price_for_plan} =
               Billing.create_checkout_session(org, "free", "https://example.com")
    end
  end

  describe "create_portal_session/2" do
    test "creates a portal session URL" do
      {org, _owner} = organization_with_stripe()

      Syncforge.Billing.StripeClientMock
      |> expect(:create_portal_session, fn params ->
        assert params[:customer] == org.stripe_customer_id
        assert params[:return_url] == "https://app.example.com/billing"
        {:ok, %{url: "https://billing.stripe.com/portal_test"}}
      end)

      assert {:ok, url} =
               Billing.create_portal_session(org, "https://app.example.com/billing")

      assert url == "https://billing.stripe.com/portal_test"
    end

    test "returns error when org has no Stripe customer" do
      {org, _owner} = organization_fixture()

      assert {:error, :no_stripe_customer} =
               Billing.create_portal_session(org, "https://example.com")
    end
  end

  describe "record_billing_event/3" do
    test "inserts a billing event record" do
      {org, _owner} = organization_fixture()

      assert {:ok, event} =
               Billing.record_billing_event("evt_test_123", "test.event", %{
                 organization_id: org.id,
                 payload: %{"test" => true}
               })

      assert event.stripe_event_id == "evt_test_123"
      assert event.event_type == "test.event"
      assert event.organization_id == org.id
    end

    test "returns existing event for duplicate stripe_event_id (idempotency)" do
      assert {:ok, _event} =
               Billing.record_billing_event("evt_dup_123", "test.event", %{
                 payload: %{"first" => true}
               })

      assert {:error, :already_processed} =
               Billing.record_billing_event("evt_dup_123", "test.event", %{
                 payload: %{"second" => true}
               })
    end
  end

  describe "sync_subscription_from_stripe/2" do
    test "updates organization from Stripe subscription data" do
      {org, _owner} = organization_with_stripe()
      price_id = Application.get_env(:syncforge, :stripe_prices)[:pro]

      stripe_sub = %{
        id: "sub_updated_123",
        status: "active",
        items: %{data: [%{price: %{id: price_id}}]},
        current_period_start: 1_706_745_600,
        current_period_end: 1_709_424_000
      }

      assert {:ok, updated_org} = Billing.sync_subscription_from_stripe(org, stripe_sub)
      assert updated_org.stripe_subscription_id == "sub_updated_123"
      assert updated_org.stripe_subscription_status == "active"
      assert updated_org.plan_type == "pro"
      assert updated_org.max_rooms == 100
      assert updated_org.max_monthly_connections == 10_000
    end

    test "downgrades to free when subscription is canceled" do
      {org, _owner} = organization_with_stripe(%{plan_type: "pro"})

      stripe_sub = %{
        id: org.stripe_subscription_id,
        status: "canceled",
        items: %{data: []},
        current_period_start: 1_706_745_600,
        current_period_end: 1_709_424_000
      }

      assert {:ok, updated_org} = Billing.sync_subscription_from_stripe(org, stripe_sub)
      assert updated_org.stripe_subscription_status == "canceled"
      assert updated_org.plan_type == "free"
      assert updated_org.max_rooms == 5
      assert updated_org.max_monthly_connections == 100
    end
  end

  describe "active_subscription?/1" do
    test "returns true for active subscription" do
      {org, _owner} = organization_with_stripe(%{stripe_subscription_status: "active"})
      assert Billing.active_subscription?(org)
    end

    test "returns true for trialing subscription" do
      {org, _owner} = organization_with_stripe(%{stripe_subscription_status: "trialing"})
      assert Billing.active_subscription?(org)
    end

    test "returns false for canceled subscription" do
      {org, _owner} = organization_with_stripe(%{stripe_subscription_status: "canceled"})
      refute Billing.active_subscription?(org)
    end

    test "returns false for no subscription" do
      {org, _owner} = organization_fixture()
      refute Billing.active_subscription?(org)
    end
  end
end

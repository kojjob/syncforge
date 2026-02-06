defmodule Syncforge.Billing.StripeClient.Live do
  @moduledoc """
  Real Stripe API implementation using stripity_stripe.
  """

  @behaviour Syncforge.Billing.StripeClient

  # stripity_stripe generates functions at compile time via macros;
  # the Elixir compiler cannot resolve them across dependency boundaries.
  @compile {:no_warn_undefined,
            [
              Stripe.Customer,
              Stripe.Checkout.Session,
              Stripe.BillingPortal.Session,
              Stripe.Subscription
            ]}

  @impl true
  def create_customer(params) do
    Stripe.Customer.create(params)
  end

  @impl true
  def create_checkout_session(params) do
    Stripe.Checkout.Session.create(params)
  end

  @impl true
  def create_portal_session(params) do
    Stripe.BillingPortal.Session.create(params)
  end

  @impl true
  def get_subscription(subscription_id) do
    Stripe.Subscription.retrieve(subscription_id)
  end

  @impl true
  def cancel_subscription(subscription_id, params \\ %{}) do
    Stripe.Subscription.update(subscription_id, Map.put(params, :cancel_at_period_end, true))
  end

  @impl true
  def update_subscription(subscription_id, params) do
    Stripe.Subscription.update(subscription_id, params)
  end
end

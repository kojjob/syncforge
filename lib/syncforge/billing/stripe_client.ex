defmodule Syncforge.Billing.StripeClient do
  @moduledoc """
  Behaviour for Stripe API interactions.

  This allows swapping the real Stripe client for a Mox mock in tests.
  Use `Application.get_env(:syncforge, :stripe_client)` to get the
  current implementation module.
  """

  @callback create_customer(params :: map()) ::
              {:ok, map()} | {:error, any()}

  @callback create_checkout_session(params :: map()) ::
              {:ok, map()} | {:error, any()}

  @callback create_portal_session(params :: map()) ::
              {:ok, map()} | {:error, any()}

  @callback get_subscription(subscription_id :: String.t()) ::
              {:ok, map()} | {:error, any()}

  @callback cancel_subscription(subscription_id :: String.t(), params :: map()) ::
              {:ok, map()} | {:error, any()}

  @callback update_subscription(subscription_id :: String.t(), params :: map()) ::
              {:ok, map()} | {:error, any()}

  @doc "Returns the configured StripeClient implementation module."
  def impl, do: Application.get_env(:syncforge, :stripe_client)
end

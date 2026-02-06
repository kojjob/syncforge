defmodule Syncforge.Billing.Plan do
  @moduledoc """
  Defines plan tiers, limits, and feature availability.

  Plan limits are defined as code constants (not DB) so they
  are version-controlled and consistent across all nodes.
  """

  @valid_subscription_statuses ~w(none active past_due canceled trialing unpaid incomplete)

  @plan_limits %{
    "free" => %{
      max_rooms: 5,
      max_mau: 100,
      features: [:presence, :cursors]
    },
    "starter" => %{
      max_rooms: 10,
      max_mau: 1_000,
      features: [:presence, :cursors]
    },
    "pro" => %{
      max_rooms: 100,
      max_mau: 10_000,
      features: [:presence, :cursors, :comments, :notifications]
    },
    "business" => %{
      max_rooms: :unlimited,
      max_mau: 50_000,
      features: [:presence, :cursors, :comments, :notifications, :voice, :analytics]
    },
    "enterprise" => %{
      max_rooms: :unlimited,
      max_mau: :unlimited,
      features: :all
    }
  }

  def valid_subscription_statuses, do: @valid_subscription_statuses

  @doc "Returns the limits map for a plan type, or nil if unknown."
  def limits(plan_type), do: Map.get(@plan_limits, plan_type)

  @doc "Returns the Stripe price ID for a plan type from config."
  def price_id(plan_type) do
    prices = Application.get_env(:syncforge, :stripe_prices, %{})

    case plan_type do
      "starter" -> Map.get(prices, :starter)
      "pro" -> Map.get(prices, :pro)
      "business" -> Map.get(prices, :business)
      _ -> nil
    end
  end

  @doc "Resolves a Stripe price ID back to a plan type string."
  def plan_for_price_id(price_id) do
    prices = Application.get_env(:syncforge, :stripe_prices, %{})

    Enum.find_value(prices, fn {plan_atom, configured_price_id} ->
      if configured_price_id == price_id, do: Atom.to_string(plan_atom)
    end)
  end

  @doc "Returns the feature list for a plan type."
  def features(plan_type) do
    case limits(plan_type) do
      %{features: features} -> features
      nil -> []
    end
  end

  @doc "Checks if a plan has a specific feature."
  def has_feature?(plan_type, feature) do
    case features(plan_type) do
      :all -> true
      features when is_list(features) -> feature in features
      _ -> false
    end
  end

  @doc "Returns the list of paid plan types (those with Stripe prices)."
  def paid_plans, do: ~w(starter pro business)
end

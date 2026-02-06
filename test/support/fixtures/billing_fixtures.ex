defmodule Syncforge.BillingFixtures do
  @moduledoc """
  Test helpers for billing-related data.
  """

  import Syncforge.OrganizationsFixtures

  @doc """
  Creates an organization with a specific plan.
  Returns `{org, owner}`.
  """
  def organization_with_plan(plan_type, attrs \\ %{}) do
    {org, owner} = organization_fixture(nil, attrs)

    {:ok, org} =
      org
      |> Syncforge.Accounts.Organization.billing_changeset(%{
        plan_type: plan_type,
        max_rooms: plan_max_rooms(plan_type),
        max_monthly_connections: plan_max_mau(plan_type),
        stripe_subscription_status: "active"
      })
      |> Syncforge.Repo.update()

    {org, owner}
  end

  @doc """
  Creates an organization with Stripe billing fields populated.
  Returns `{org, owner}`.
  """
  def organization_with_stripe(attrs \\ %{}) do
    {org, owner} =
      organization_fixture(
        nil,
        Map.drop(attrs, [
          :stripe_customer_id,
          :stripe_subscription_id,
          :stripe_subscription_status
        ])
      )

    billing_attrs =
      Map.merge(
        %{
          stripe_customer_id: "cus_test_#{System.unique_integer([:positive])}",
          stripe_subscription_id: "sub_test_#{System.unique_integer([:positive])}",
          stripe_subscription_status: "active",
          plan_type: "pro",
          max_rooms: 100,
          max_monthly_connections: 10_000,
          current_period_start: DateTime.utc_now() |> DateTime.truncate(:microsecond),
          current_period_end:
            DateTime.utc_now()
            |> DateTime.add(30, :day)
            |> DateTime.truncate(:microsecond)
        },
        Map.take(attrs, [
          :stripe_customer_id,
          :stripe_subscription_id,
          :stripe_subscription_status,
          :plan_type,
          :max_rooms,
          :max_monthly_connections
        ])
      )

    {:ok, org} =
      org
      |> Syncforge.Accounts.Organization.billing_changeset(billing_attrs)
      |> Syncforge.Repo.update()

    {org, owner}
  end

  defp plan_max_rooms("free"), do: 5
  defp plan_max_rooms("starter"), do: 10
  defp plan_max_rooms("pro"), do: 100
  defp plan_max_rooms("business"), do: 999_999
  defp plan_max_rooms("enterprise"), do: 999_999
  defp plan_max_rooms(_), do: 5

  defp plan_max_mau("free"), do: 100
  defp plan_max_mau("starter"), do: 1_000
  defp plan_max_mau("pro"), do: 10_000
  defp plan_max_mau("business"), do: 50_000
  defp plan_max_mau("enterprise"), do: 999_999
  defp plan_max_mau(_), do: 100
end

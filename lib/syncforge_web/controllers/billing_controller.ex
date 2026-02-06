defmodule SyncforgeWeb.BillingController do
  use SyncforgeWeb, :controller

  alias Syncforge.Billing
  alias Syncforge.Organizations

  @doc "POST /api/organizations/:org_id/billing/checkout"
  def create_checkout_session(conn, %{"org_id" => org_id} = params) do
    user = conn.assigns.current_user
    plan = params["plan"]
    return_url = params["return_url"]

    with org when not is_nil(org) <- Organizations.get_organization(org_id),
         true <- Organizations.user_has_role?(org_id, user.id, ["owner", "admin"]) do
      case Billing.create_checkout_session(org, plan, return_url) do
        {:ok, url} ->
          json(conn, %{url: url})

        {:error, :no_price_for_plan} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "No Stripe price for this plan"})

        {:error, _reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Could not create checkout session"})
      end
    else
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Organization not found"})

      false ->
        conn |> put_status(:forbidden) |> json(%{error: "Insufficient permissions"})
    end
  end

  @doc "POST /api/organizations/:org_id/billing/portal"
  def create_portal_session(conn, %{"org_id" => org_id} = params) do
    user = conn.assigns.current_user
    return_url = params["return_url"]

    with org when not is_nil(org) <- Organizations.get_organization(org_id),
         true <- Organizations.user_has_role?(org_id, user.id, ["owner", "admin"]) do
      case Billing.create_portal_session(org, return_url) do
        {:ok, url} ->
          json(conn, %{url: url})

        {:error, :no_stripe_customer} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Organization has no Stripe customer. Upgrade first."})

        {:error, _reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "Could not create portal session"})
      end
    else
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Organization not found"})

      false ->
        conn |> put_status(:forbidden) |> json(%{error: "Insufficient permissions"})
    end
  end

  @doc "GET /api/organizations/:org_id/billing/subscription"
  def show_subscription(conn, %{"org_id" => org_id}) do
    user = conn.assigns.current_user

    with org when not is_nil(org) <- Organizations.get_organization(org_id),
         true <-
           Organizations.user_has_role?(org_id, user.id, [
             "owner",
             "admin",
             "member",
             "viewer"
           ]) do
      subscription_data = %{
        plan_type: org.plan_type,
        status: org.stripe_subscription_status,
        stripe_subscription_id: org.stripe_subscription_id,
        stripe_customer_id: org.stripe_customer_id,
        current_period_start: org.current_period_start,
        current_period_end: org.current_period_end,
        max_rooms: org.max_rooms,
        max_monthly_connections: org.max_monthly_connections
      }

      json(conn, %{subscription: subscription_data})
    else
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Organization not found"})

      false ->
        conn |> put_status(:forbidden) |> json(%{error: "Insufficient permissions"})
    end
  end
end

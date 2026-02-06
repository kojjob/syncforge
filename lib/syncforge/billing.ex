defmodule Syncforge.Billing do
  @moduledoc """
  Context for managing Stripe billing, subscriptions, and plan enforcement.

  Uses a behaviour-based StripeClient for testability — the real implementation
  calls Stripe APIs, while tests use a Mox mock.
  """

  alias Syncforge.Repo
  alias Syncforge.Accounts.Organization
  alias Syncforge.Billing.{BillingEvent, Plan}

  defp stripe_client, do: Application.get_env(:syncforge, :stripe_client)

  # ── Stripe Customer ──────────────────────────────────────

  @doc """
  Gets or lazily creates a Stripe customer for the organization.
  Stores the `stripe_customer_id` on the org when created.
  """
  def get_or_create_stripe_customer(%Organization{stripe_customer_id: cid} = org)
      when is_binary(cid) and cid != "" do
    {:ok, org}
  end

  def get_or_create_stripe_customer(%Organization{} = org) do
    case stripe_client().create_customer(%{
           metadata: %{organization_id: org.id},
           email: org.billing_email
         }) do
      {:ok, %{id: customer_id}} ->
        org
        |> Organization.billing_changeset(%{stripe_customer_id: customer_id})
        |> Repo.update()

      {:error, _reason} = error ->
        error
    end
  end

  # ── Checkout & Portal ────────────────────────────────────

  @doc """
  Creates a Stripe Checkout session for upgrading to a paid plan.
  Returns `{:ok, checkout_url}` or `{:error, reason}`.
  """
  def create_checkout_session(%Organization{} = org, plan_type, return_url) do
    price_id = Plan.price_id(plan_type)

    if is_nil(price_id) do
      {:error, :no_price_for_plan}
    else
      with {:ok, org} <- get_or_create_stripe_customer(org) do
        case stripe_client().create_checkout_session(%{
               mode: "subscription",
               customer: org.stripe_customer_id,
               line_items: [%{price: price_id, quantity: 1}],
               success_url: return_url,
               cancel_url: return_url,
               metadata: %{organization_id: org.id}
             }) do
          {:ok, %{url: url}} -> {:ok, url}
          {:error, _} = error -> error
        end
      end
    end
  end

  @doc """
  Creates a Stripe Customer Portal session for subscription management.
  Returns `{:ok, portal_url}` or `{:error, reason}`.
  """
  def create_portal_session(%Organization{stripe_customer_id: nil}, _return_url) do
    {:error, :no_stripe_customer}
  end

  def create_portal_session(%Organization{stripe_customer_id: ""}, _return_url) do
    {:error, :no_stripe_customer}
  end

  def create_portal_session(%Organization{} = org, return_url) do
    case stripe_client().create_portal_session(%{
           customer: org.stripe_customer_id,
           return_url: return_url
         }) do
      {:ok, %{url: url}} -> {:ok, url}
      {:error, _} = error -> error
    end
  end

  # ── Billing Events (Idempotency) ────────────────────────

  @doc """
  Records a billing event. Returns `{:error, :already_processed}` if the
  event was already recorded (idempotency via unique stripe_event_id).
  """
  def record_billing_event(stripe_event_id, event_type, attrs \\ %{}) do
    %BillingEvent{}
    |> BillingEvent.changeset(
      Map.merge(attrs, %{
        stripe_event_id: stripe_event_id,
        event_type: event_type,
        payload: Map.get(attrs, :payload, %{}),
        processed_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
      })
    )
    |> Repo.insert()
    |> case do
      {:ok, event} -> {:ok, event}
      {:error, %{errors: [{:stripe_event_id, _} | _]}} -> {:error, :already_processed}
      {:error, changeset} -> {:error, changeset}
    end
  end

  # ── Subscription Sync ───────────────────────────────────

  @doc """
  Syncs organization billing state from a Stripe subscription object.
  Updates plan_type, limits, and period dates.
  """
  def sync_subscription_from_stripe(%Organization{} = org, stripe_sub) do
    plan_type = resolve_plan_from_subscription(stripe_sub)
    plan_limits = Plan.limits(plan_type) || Plan.limits("free")

    max_rooms =
      case plan_limits.max_rooms do
        :unlimited -> 999_999
        n -> n
      end

    max_mau =
      case plan_limits.max_mau do
        :unlimited -> 999_999
        n -> n
      end

    period_start = parse_unix_timestamp(stripe_sub[:current_period_start])
    period_end = parse_unix_timestamp(stripe_sub[:current_period_end])

    org
    |> Organization.billing_changeset(%{
      stripe_subscription_id: stripe_sub.id,
      stripe_subscription_status: stripe_sub.status,
      plan_type: plan_type,
      max_rooms: max_rooms,
      max_monthly_connections: max_mau,
      current_period_start: period_start,
      current_period_end: period_end
    })
    |> Repo.update()
  end

  # ── Webhook Event Processing ────────────────────────────

  @doc """
  Processes a Stripe webhook event. Dispatches by event type,
  records the event for idempotency, and updates org state.
  """
  def process_webhook_event(%{id: event_id, type: event_type} = event) do
    case record_billing_event(event_id, event_type, %{
           payload: event.data.object |> stringify_keys()
         }) do
      {:error, :already_processed} ->
        :ok

      {:ok, _billing_event} ->
        handle_webhook_event(event_type, event)
    end
  end

  defp handle_webhook_event("checkout.session.completed", event) do
    session = event.data.object
    org_id = session.metadata["organization_id"]

    with org when not is_nil(org) <- Repo.get(Organization, org_id),
         {:ok, stripe_sub} <- stripe_client().get_subscription(session.subscription),
         {:ok, _org} <- sync_subscription_from_stripe(org, stripe_sub) do
      :ok
    else
      _ -> :ok
    end
  end

  defp handle_webhook_event("customer.subscription.updated", event) do
    stripe_sub = event.data.object
    org = find_org_by_subscription_or_customer(stripe_sub)

    if org do
      {:ok, _org} = sync_subscription_from_stripe(org, stripe_sub)
    end

    :ok
  end

  defp handle_webhook_event("customer.subscription.deleted", event) do
    stripe_sub = event.data.object
    org = find_org_by_subscription_or_customer(stripe_sub)

    if org do
      {:ok, _org} = sync_subscription_from_stripe(org, stripe_sub)
    end

    :ok
  end

  defp handle_webhook_event("invoice.payment_failed", event) do
    invoice = event.data.object

    org =
      if invoice[:subscription] do
        Repo.get_by(Organization, stripe_subscription_id: invoice.subscription)
      end

    org =
      org ||
        if(invoice[:customer],
          do: Repo.get_by(Organization, stripe_customer_id: invoice.customer)
        )

    if org do
      org
      |> Organization.billing_changeset(%{stripe_subscription_status: "past_due"})
      |> Repo.update()
    end

    :ok
  end

  defp handle_webhook_event(_event_type, _event), do: :ok

  # ── Plan Enforcement ────────────────────────────────────

  @doc """
  Checks whether the organization can create another room.
  Returns `:ok` or `{:error, :room_limit_reached}`.
  """
  def can_create_room?(%Organization{} = org) do
    current_count = Syncforge.Rooms.count_rooms_for_organization(org.id)

    if current_count < org.max_rooms do
      :ok
    else
      {:error, :room_limit_reached}
    end
  end

  @doc """
  Checks whether the organization can accept another connection (MAU check).
  Uses connection_events to count distinct users in the current billing period.
  Returns `:ok` or `{:error, :connection_limit_reached}`.
  """
  def can_connect?(%Organization{} = org) do
    since = billing_period_start(org)
    current_mau = Syncforge.Analytics.unique_users(org.id, since)

    if current_mau < org.max_monthly_connections do
      :ok
    else
      {:error, :connection_limit_reached}
    end
  end

  @doc """
  Checks whether a feature is enabled for the organization's plan.
  Returns `true` or `false`.

  Organizations that have never configured billing (stripe_subscription_status
  is "none" or nil) get all features — enforcement only kicks in after a plan
  is explicitly set through the billing flow.
  """
  def feature_enabled?(%Organization{stripe_subscription_status: status}, _feature)
      when status in [nil, "none"] do
    true
  end

  def feature_enabled?(%Organization{plan_type: plan_type}, feature) do
    plan = plan_type || "free"
    Plan.has_feature?(plan, feature)
  end

  # ── Query Helpers ───────────────────────────────────────

  @doc "Returns true if the org has an active or trialing subscription."
  def active_subscription?(%Organization{stripe_subscription_status: status}) do
    status in ["active", "trialing"]
  end

  # ── Private Helpers ─────────────────────────────────────

  defp find_org_by_subscription_or_customer(stripe_sub) do
    org =
      if stripe_sub[:id] do
        Repo.get_by(Organization, stripe_subscription_id: stripe_sub.id)
      end

    org ||
      if stripe_sub[:customer] do
        Repo.get_by(Organization, stripe_customer_id: stripe_sub.customer)
      end
  end

  defp resolve_plan_from_subscription(stripe_sub) do
    case stripe_sub do
      %{status: "canceled"} ->
        "free"

      %{items: %{data: [%{price: %{id: price_id}} | _]}} ->
        Plan.plan_for_price_id(price_id) || "free"

      _ ->
        "free"
    end
  end

  defp parse_unix_timestamp(nil), do: nil

  defp parse_unix_timestamp(ts) when is_integer(ts) do
    DateTime.from_unix!(ts) |> DateTime.truncate(:microsecond)
  end

  defp parse_unix_timestamp(%DateTime{} = dt), do: DateTime.truncate(dt, :microsecond)

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), stringify_keys(v)}
      {k, v} -> {k, stringify_keys(v)}
    end)
  end

  defp stringify_keys(list) when is_list(list), do: Enum.map(list, &stringify_keys/1)
  defp stringify_keys(other), do: other

  defp billing_period_start(%Organization{current_period_start: nil}) do
    DateTime.add(DateTime.utc_now(), -30, :day)
  end

  defp billing_period_start(%Organization{current_period_start: start}) do
    start
  end
end

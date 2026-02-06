defmodule SyncforgeWeb.BillingLive do
  use SyncforgeWeb, :live_view

  alias Syncforge.{Organizations, Billing, Rooms, Analytics}

  @all_features [:presence, :cursors, :comments, :notifications, :voice, :analytics]

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    organizations = Organizations.list_user_organizations(user.id)
    current_org = pick_org(organizations, session["current_org_id"])

    billing_data = if current_org, do: load_billing_data(current_org), else: empty_billing()

    if current_org && connected?(socket) do
      Phoenix.PubSub.subscribe(Syncforge.PubSub, "billing:#{current_org.id}")
    end

    {:ok,
     socket
     |> assign(
       page_title: "Billing",
       organizations: organizations,
       current_org: current_org,
       active_nav: :billing
     )
     |> assign(billing_data)}
  end

  @impl true
  def handle_event("switch_org", %{"org_id" => org_id}, socket) do
    old_org = socket.assigns.current_org

    if old_org && connected?(socket) do
      Phoenix.PubSub.unsubscribe(Syncforge.PubSub, "billing:#{old_org.id}")
    end

    org = Enum.find(socket.assigns.organizations, &(&1.id == org_id))
    billing_data = if org, do: load_billing_data(org), else: empty_billing()

    if org && connected?(socket) do
      Phoenix.PubSub.subscribe(Syncforge.PubSub, "billing:#{org.id}")
    end

    {:noreply,
     socket
     |> assign(current_org: org)
     |> assign(billing_data)}
  end

  @impl true
  def handle_info({:billing_updated, org_id}, socket) do
    current_org = socket.assigns.current_org

    if current_org && current_org.id == org_id do
      org = Syncforge.Repo.get!(Syncforge.Accounts.Organization, org_id)
      billing_data = load_billing_data(org)
      {:noreply, socket |> assign(current_org: org) |> assign(billing_data)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-8">
      <h1 class="text-2xl font-bold">Billing</h1>
      <p class="text-base-content/60 mt-1">Manage your subscription and plan limits</p>
    </div>

    <%= if @current_org do %>
      <%!-- Status Alert --%>
      <%= if @subscription_status in ["past_due", "canceled", "unpaid"] do %>
        <div class="alert alert-warning mb-6">
          <.icon name="hero-exclamation-triangle" class="size-5" />
          <div>
            <p class="font-medium">Subscription status: {@subscription_status}</p>
            <p class="text-sm">
              <%= if @subscription_status == "past_due" do %>
                Your payment is overdue. Please update your payment method to avoid service interruption.
              <% else %>
                Your subscription has been canceled. Upgrade to restore full access.
              <% end %>
            </p>
          </div>
        </div>
      <% end %>

      <%!-- Plan Card --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-lg">Current Plan</h2>
            <%= if @plan_type do %>
              <div class="flex items-center gap-3 mt-2">
                <span class="text-3xl font-bold capitalize">{@plan_type}</span>
                <span class={"badge badge-sm #{status_badge_class(@subscription_status)}"}>
                  {@subscription_status}
                </span>
              </div>
              <%= if @current_period_end do %>
                <p class="text-sm text-base-content/60 mt-2">
                  Current period ends: {Calendar.strftime(@current_period_end, "%B %d, %Y")}
                </p>
              <% end %>
            <% else %>
              <p class="text-base-content/60 mt-2">No plan configured</p>
            <% end %>
            <div class="card-actions mt-4">
              <%= if @has_stripe_customer do %>
                <button class="btn btn-sm btn-outline" phx-click="manage_subscription">
                  Manage Subscription
                </button>
              <% end %>
              <button class="btn btn-sm btn-primary" phx-click="upgrade">
                Upgrade
              </button>
            </div>
          </div>
        </div>

        <%!-- Usage Card --%>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-lg">Usage</h2>
            <div class="space-y-4 mt-2">
              <div>
                <div class="flex justify-between text-sm mb-1">
                  <span>Rooms</span>
                  <span>{@room_count} / {@max_rooms}</span>
                </div>
                <progress
                  class={"progress #{if @room_count >= @max_rooms, do: "progress-error", else: "progress-primary"}"}
                  value={@room_count}
                  max={@max_rooms}
                >
                </progress>
              </div>
              <div>
                <div class="flex justify-between text-sm mb-1">
                  <span>Monthly Active Users</span>
                  <span>{@mau_count} / {@max_mau}</span>
                </div>
                <progress
                  class={"progress #{if @mau_count >= @max_mau, do: "progress-error", else: "progress-primary"}"}
                  value={@mau_count}
                  max={@max_mau}
                >
                </progress>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Features --%>
      <div class="card bg-base-200 shadow-sm">
        <div class="card-body">
          <h2 class="card-title text-lg">Features</h2>
          <div class="grid grid-cols-2 md:grid-cols-3 gap-3 mt-3">
            <%= for {feature, enabled} <- @features do %>
              <div class="flex items-center gap-2">
                <%= if enabled do %>
                  <.icon name="hero-check-circle" class="size-5 text-success" />
                <% else %>
                  <.icon name="hero-x-circle" class="size-5 text-base-content/30" />
                <% end %>
                <span class={"text-sm #{unless enabled, do: "text-base-content/40"}"}>
                  {feature_label(feature)}
                </span>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    <% else %>
      <div class="text-center py-12 text-base-content/50">
        <span class="hero-building-office size-12 mx-auto mb-4 block"></span>
        <p class="text-lg font-medium">Create an organization first</p>
        <p class="text-sm mt-1">
          Go to the <a href="/dashboard" class="link link-primary">Dashboard</a>
          to create an organization.
        </p>
      </div>
    <% end %>
    """
  end

  # ── Private Helpers ───────────────────────────────────

  defp load_billing_data(org) do
    room_count = Rooms.count_rooms_for_organization(org.id)
    since = billing_period_start(org)
    mau_count = Analytics.unique_users(org.id, since)

    max_rooms = org.max_rooms || 5
    max_mau = org.max_monthly_connections || 100

    plan_type =
      case org.stripe_subscription_status do
        status when status in [nil, "none"] -> nil
        _ -> org.plan_type
      end

    features =
      Enum.map(@all_features, fn feature ->
        enabled = Billing.feature_enabled?(org, feature)
        {feature, enabled}
      end)

    %{
      plan_type: plan_type,
      subscription_status: org.stripe_subscription_status || "none",
      current_period_end: org.current_period_end,
      has_stripe_customer: is_binary(org.stripe_customer_id) and org.stripe_customer_id != "",
      room_count: room_count,
      max_rooms: max_rooms,
      mau_count: mau_count,
      max_mau: max_mau,
      features: features
    }
  end

  defp empty_billing do
    %{
      plan_type: nil,
      subscription_status: "none",
      current_period_end: nil,
      has_stripe_customer: false,
      room_count: 0,
      max_rooms: 5,
      mau_count: 0,
      max_mau: 100,
      features: Enum.map(@all_features, fn f -> {f, false} end)
    }
  end

  defp billing_period_start(%{current_period_start: nil}) do
    DateTime.add(DateTime.utc_now(), -30, :day)
  end

  defp billing_period_start(%{current_period_start: start}), do: start

  defp status_badge_class("active"), do: "badge-success"
  defp status_badge_class("trialing"), do: "badge-info"
  defp status_badge_class("past_due"), do: "badge-warning"
  defp status_badge_class("canceled"), do: "badge-error"
  defp status_badge_class(_), do: "badge-ghost"

  defp feature_label(:presence), do: "Presence"
  defp feature_label(:cursors), do: "Cursors"
  defp feature_label(:comments), do: "Comments"
  defp feature_label(:notifications), do: "Notifications"
  defp feature_label(:voice), do: "Voice"
  defp feature_label(:analytics), do: "Analytics"
  defp feature_label(other), do: other |> Atom.to_string() |> String.capitalize()

  defp pick_org([], _), do: nil
  defp pick_org(orgs, nil), do: List.first(orgs)

  defp pick_org(orgs, preferred_id) do
    Enum.find(orgs, List.first(orgs), &(&1.id == preferred_id))
  end
end

defmodule SyncforgeWeb.AnalyticsLive do
  use SyncforgeWeb, :live_view

  alias Syncforge.Organizations
  alias Syncforge.Analytics

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    organizations = Organizations.list_user_organizations(user.id)
    current_org = pick_org(organizations, session["current_org_id"])
    period = "24h"

    stats = if current_org, do: load_stats(current_org.id, period), else: empty_stats()
    breakdown = if current_org, do: load_breakdown(current_org.id, period), else: []

    {:ok,
     socket
     |> assign(
       page_title: "Analytics",
       organizations: organizations,
       current_org: current_org,
       active_nav: :analytics,
       period: period,
       stats: stats,
       breakdown: breakdown
     )}
  end

  @impl true
  def handle_event("set_period", %{"period" => period}, socket) do
    org = socket.assigns.current_org

    stats = if org, do: load_stats(org.id, period), else: empty_stats()
    breakdown = if org, do: load_breakdown(org.id, period), else: []

    {:noreply, assign(socket, period: period, stats: stats, breakdown: breakdown)}
  end

  def handle_event("switch_org", %{"org_id" => org_id}, socket) do
    org = Enum.find(socket.assigns.organizations, &(&1.id == org_id))
    period = socket.assigns.period

    stats = if org, do: load_stats(org.id, period), else: empty_stats()
    breakdown = if org, do: load_breakdown(org.id, period), else: []

    {:noreply, assign(socket, current_org: org, stats: stats, breakdown: breakdown)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-8">
      <h1 class="text-2xl font-bold text-foreground">Analytics</h1>
      <p class="text-muted mt-1">Connection and usage analytics</p>
    </div>

    <%= if @current_org do %>
      <div class="flex gap-2 mb-6">
        <button
          :for={p <- ["24h", "7d", "30d"]}
          phx-click="set_period"
          phx-value-period={p}
          class={[
            "inline-flex items-center rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors",
            if(@period == p,
              do: "bg-primary text-primary-foreground hover:bg-primary-hover",
              else: "border border-border text-foreground hover:bg-surface-alt"
            )
          ]}
        >
          {p}
        </button>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        <div class="rounded-xl border border-border bg-surface-alt shadow-sm p-6">
          <div class="flex items-center justify-between">
            <h3 class="text-sm font-medium text-muted">Total Connections</h3>
            <span class="hero-signal size-5 text-muted-foreground"></span>
          </div>
          <p class="text-3xl font-bold text-foreground mt-1">{@stats.total_connections}</p>
          <p class="text-xs text-muted-foreground mt-1">Join events in period</p>
        </div>
        <div class="rounded-xl border border-border bg-surface-alt shadow-sm p-6">
          <div class="flex items-center justify-between">
            <h3 class="text-sm font-medium text-muted">Unique Users</h3>
            <span class="hero-users size-5 text-muted-foreground"></span>
          </div>
          <p class="text-3xl font-bold text-foreground mt-1">{@stats.unique_users}</p>
          <p class="text-xs text-muted-foreground mt-1">Distinct users connected</p>
        </div>
        <div class="rounded-xl border border-border bg-surface-alt shadow-sm p-6">
          <div class="flex items-center justify-between">
            <h3 class="text-sm font-medium text-muted">Active Rooms</h3>
            <span class="hero-rectangle-group size-5 text-muted-foreground"></span>
          </div>
          <p class="text-3xl font-bold text-foreground mt-1">{@stats.active_rooms}</p>
          <p class="text-xs text-muted-foreground mt-1">Rooms with activity</p>
        </div>
      </div>

      <div class="rounded-xl border border-border bg-surface-alt shadow-sm">
        <div class="p-6">
          <h2 class="text-lg font-semibold text-foreground">Room Usage</h2>
          <%= if @breakdown == [] do %>
            <p class="text-muted-foreground text-sm py-4">No room activity in this period.</p>
          <% else %>
            <div class="overflow-x-auto mt-4">
              <table class="w-full text-sm text-left">
                <thead>
                  <tr class="border-b border-border text-muted">
                    <th class="pb-3 font-medium">Room</th>
                    <th class="pb-3 font-medium">Connections</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for {room_id, count} <- @breakdown do %>
                    <tr class="border-b border-border last:border-0">
                      <td class="py-3 font-mono text-sm text-foreground">{room_id}</td>
                      <td class="py-3 text-foreground">{count}</td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        </div>
      </div>
    <% else %>
      <div class="text-center py-12 text-muted-foreground">
        <span class="hero-building-office size-12 mx-auto mb-4 block"></span>
        <p class="text-lg font-medium">Create an organization first</p>
        <p class="text-sm mt-1">
          Go to the
          <a href="/dashboard" class="text-primary hover:underline font-medium">Dashboard</a>
          to create an organization.
        </p>
      </div>
    <% end %>
    """
  end

  defp load_stats(org_id, period) do
    since = Analytics.period_start(period)

    %{
      total_connections: Analytics.total_connections(org_id, since),
      unique_users: Analytics.unique_users(org_id, since),
      active_rooms: Analytics.active_rooms(org_id, since)
    }
  end

  defp load_breakdown(org_id, period) do
    since = Analytics.period_start(period)
    Analytics.room_usage_breakdown(org_id, since)
  end

  defp empty_stats do
    %{total_connections: 0, unique_users: 0, active_rooms: 0}
  end

  defp pick_org([], _), do: nil
  defp pick_org(orgs, nil), do: List.first(orgs)

  defp pick_org(orgs, preferred_id) do
    Enum.find(orgs, List.first(orgs), &(&1.id == preferred_id))
  end
end

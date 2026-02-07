defmodule SyncforgeWeb.DashboardLive do
  @moduledoc """
  Dashboard overview page with a bento grid layout showing stats,
  recent rooms, quick start, and system status.
  """

  use SyncforgeWeb, :live_view

  alias Syncforge.{Organizations, Rooms, Analytics}

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    organizations = Organizations.list_user_organizations(user.id)
    current_org = pick_org(organizations, session["current_org_id"])

    dashboard = if current_org, do: load_dashboard(current_org), else: %{}

    {:ok,
     socket
     |> assign(
       page_title: "Dashboard",
       organizations: organizations,
       current_org: current_org,
       active_nav: :overview
     )
     |> assign(dashboard)}
  end

  @impl true
  def handle_event("switch_org", %{"org_id" => org_id}, socket) do
    org = Enum.find(socket.assigns.organizations, &(&1.id == org_id))

    if org do
      dashboard = load_dashboard(org)

      {:noreply,
       socket
       |> assign(current_org: org)
       |> assign(dashboard)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("create_org", %{"org" => %{"name" => name}}, socket) do
    user = socket.assigns.current_user

    case Organizations.create_organization(user, %{name: name}) do
      {:ok, org, _membership} ->
        organizations = Organizations.list_user_organizations(user.id)
        dashboard = load_dashboard(org)

        {:noreply,
         socket
         |> assign(organizations: organizations, current_org: org)
         |> assign(dashboard)
         |> put_flash(:info, "Organization created!")}

      {:error, _step, changeset, _changes} ->
        message =
          changeset
          |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
          |> Enum.map_join(", ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)

        {:noreply, put_flash(socket, :error, "Failed to create organization: #{message}")}
    end
  end

  # ── Data Loading ────────────────────────────────

  defp load_dashboard(org) do
    since = Analytics.period_start("24h")
    rooms = Rooms.list_rooms_for_organization(org.id)
    api_keys = Organizations.list_api_keys(org.id)

    %{
      rooms_count: length(rooms),
      members_count: Organizations.count_members(org.id),
      connections_count: Analytics.total_connections(org.id, since),
      recent_rooms: Enum.take(rooms, 5),
      api_key_prefix: first_key_prefix(api_keys),
      has_api_key: api_keys != [],
      has_rooms: rooms != []
    }
  end

  defp first_key_prefix([%{key_prefix: prefix} | _]), do: prefix <> "..."
  defp first_key_prefix(_), do: nil

  defp pick_org([], _session_org_id), do: nil

  defp pick_org(organizations, session_org_id) when is_binary(session_org_id) do
    Enum.find(organizations, List.first(organizations), &(&1.id == session_org_id))
  end

  defp pick_org(organizations, _), do: List.first(organizations)

  # ── Render ──────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%!-- Page Header --%>
      <div class="mb-8">
        <h1 class="text-3xl font-extrabold tracking-tight text-foreground">
          Project Overview
        </h1>
        <p class="text-muted text-base mt-1">
          Manage your collaboration infrastructure and monitor usage.
        </p>
      </div>

      <%= if @current_org do %>
        <%!-- Bento Grid --%>
        <div class="grid grid-cols-1 xl:grid-cols-3 gap-5">
          <%!-- Row 1: Three stat cards --%>
          <.stat_card
            title="Active Connections"
            value={@connections_count}
            icon="hero-signal"
            trend_label="24h"
            color="primary"
          />
          <.stat_card
            title="Total Rooms"
            value={@rooms_count}
            icon="hero-rectangle-group"
            trend_label={if @rooms_count > 0, do: "active", else: nil}
            color="emerald"
          />
          <.stat_card
            title="Team Members"
            value={@members_count}
            icon="hero-users"
            trend_label={nil}
            color="amber"
          />

          <%!-- Row 2: Recent Rooms (span 2) + Quick Start (span 1) --%>
          <div class="xl:col-span-2 rounded-xl border border-border bg-surface-alt shadow-sm">
            <div class="p-6">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-base font-semibold text-foreground">Recent Active Rooms</h2>
                <.link
                  navigate={~p"/dashboard/rooms"}
                  class="text-xs text-primary hover:underline font-medium"
                >
                  View all
                </.link>
              </div>

              <%= if @recent_rooms == [] do %>
                <div class="text-center py-8">
                  <.icon
                    name="hero-rectangle-group"
                    class="size-10 mx-auto mb-2 text-muted-foreground/30"
                  />
                  <p class="text-sm text-muted-foreground">No rooms yet</p>
                  <.link
                    navigate={~p"/dashboard/rooms"}
                    class="text-xs text-primary hover:underline font-medium mt-1 inline-block"
                  >
                    Create your first room
                  </.link>
                </div>
              <% else %>
                <div class="space-y-1">
                  <.room_row :for={room <- @recent_rooms} room={room} />
                </div>
              <% end %>
            </div>
          </div>

          <div class="rounded-xl border border-border bg-surface-alt shadow-sm">
            <div class="p-6">
              <div class="flex items-center gap-2 mb-4">
                <div class="flex items-center justify-center size-8 rounded-lg bg-primary/10">
                  <.icon name="hero-bolt" class="size-4 text-primary" />
                </div>
                <h2 class="text-base font-semibold text-foreground">Quick Start</h2>
              </div>

              <%= if @api_key_prefix do %>
                <div class="mb-4">
                  <p class="text-xs text-muted mb-1.5">Project API Key</p>
                  <div class="flex items-center gap-2 rounded-lg bg-surface-strong px-3 py-2">
                    <code class="text-xs text-foreground flex-1 font-mono">
                      {@api_key_prefix}
                    </code>
                    <.link
                      navigate={~p"/dashboard/api-keys"}
                      class="text-muted-foreground hover:text-foreground transition-colors"
                    >
                      <.icon name="hero-eye" class="size-3.5" />
                    </.link>
                  </div>
                </div>
              <% end %>

              <div class="space-y-2">
                <a
                  href="https://docs.syncforge.io"
                  target="_blank"
                  rel="noopener"
                  class="flex items-center justify-between rounded-lg px-3 py-2 text-sm text-foreground hover:bg-surface-strong transition-colors group"
                >
                  <span>SDK Documentation</span>
                  <.icon
                    name="hero-arrow-top-right-on-square"
                    class="size-3.5 text-muted-foreground group-hover:text-foreground transition-colors"
                  />
                </a>
                <a
                  href="https://github.com/syncforge/examples"
                  target="_blank"
                  rel="noopener"
                  class="flex items-center justify-between rounded-lg px-3 py-2 text-sm text-foreground hover:bg-surface-strong transition-colors group"
                >
                  <span>View Samples</span>
                  <.icon
                    name="hero-arrow-top-right-on-square"
                    class="size-3.5 text-muted-foreground group-hover:text-foreground transition-colors"
                  />
                </a>
              </div>

              <div class="border-t border-border mt-4 pt-4">
                <%= if @has_api_key do %>
                  <.link
                    navigate={~p"/dashboard/api-keys"}
                    class="flex items-center justify-center gap-1.5 w-full rounded-lg bg-primary px-3 py-2 text-xs font-semibold text-primary-foreground hover:bg-primary-hover transition-colors"
                  >
                    <.icon name="hero-key" class="size-3.5" /> Manage API Keys
                  </.link>
                <% else %>
                  <.link
                    navigate={~p"/dashboard/api-keys"}
                    class="flex items-center justify-center gap-1.5 w-full rounded-lg bg-primary px-3 py-2 text-xs font-semibold text-primary-foreground hover:bg-primary-hover transition-colors"
                  >
                    <.icon name="hero-plus" class="size-3.5" /> Create API Key
                  </.link>
                <% end %>
              </div>
            </div>
          </div>

          <%!-- Row 3: Quick Actions (span 2) + System Status (span 1) --%>
          <div class="xl:col-span-2 rounded-xl border border-border bg-surface-alt shadow-sm">
            <div class="p-6">
              <h2 class="text-base font-semibold text-foreground mb-4">Quick Actions</h2>
              <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
                <.action_card
                  navigate={~p"/dashboard/rooms"}
                  icon="hero-plus"
                  label="New Room"
                />
                <.action_card
                  navigate={~p"/dashboard/api-keys"}
                  icon="hero-key"
                  label="API Key"
                />
                <.action_card
                  navigate={~p"/dashboard/analytics"}
                  icon="hero-chart-bar"
                  label="Analytics"
                />
                <.action_card
                  navigate={~p"/dashboard/billing"}
                  icon="hero-credit-card"
                  label="Billing"
                />
              </div>
            </div>
          </div>

          <div class="rounded-xl border border-emerald-500/20 bg-emerald-500/5 shadow-sm">
            <div class="p-6">
              <div class="flex items-center gap-2 mb-2">
                <span class="relative flex size-2.5">
                  <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75">
                  </span>
                  <span class="relative inline-flex rounded-full size-2.5 bg-emerald-500"></span>
                </span>
                <h2 class="text-base font-semibold text-foreground">All Systems Operational</h2>
              </div>
              <p class="text-xs text-muted-foreground">
                SyncForge infrastructure is running normally. Real-time channels, presence tracking, and API services are all healthy.
              </p>
              <div class="mt-4 space-y-2">
                <.status_row label="WebSocket Channels" status="operational" />
                <.status_row label="Presence Tracking" status="operational" />
                <.status_row label="REST API" status="operational" />
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <%!-- Getting Started --%>
        <div class="rounded-xl border border-border bg-surface-alt shadow-sm max-w-lg">
          <div class="p-6">
            <h2 class="text-lg font-semibold text-foreground">Getting Started</h2>
            <p class="text-muted text-sm mt-1">
              Create your first organization to start using SyncForge.
            </p>

            <ul class="mt-4 space-y-2">
              <li class="flex items-center gap-2 text-sm">
                <.icon name="hero-check-circle" class="size-5 text-success" />
                <span class="line-through text-muted-foreground">Create an account</span>
              </li>
              <li class="flex items-center gap-2 text-sm text-foreground">
                <.icon name="hero-minus-circle" class="size-5 text-muted-foreground" />
                <span>Create your first organization</span>
              </li>
              <li class="flex items-center gap-2 text-sm text-muted-foreground">
                <.icon name="hero-minus-circle" class="size-5 text-muted-foreground" />
                <span>Create a room</span>
              </li>
              <li class="flex items-center gap-2 text-sm text-muted-foreground">
                <.icon name="hero-minus-circle" class="size-5 text-muted-foreground" />
                <span>Generate an API key</span>
              </li>
            </ul>

            <div class="border-t border-border my-4"></div>

            <.form for={%{}} id="create-org-form" phx-submit="create_org" class="flex gap-2">
              <input
                type="text"
                name="org[name]"
                placeholder="Organization name"
                class="flex-1 rounded-lg border border-input-border bg-input px-3 py-1.5 text-sm text-foreground placeholder-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary"
                required
              />
              <button
                type="submit"
                class="inline-flex items-center rounded-lg bg-primary px-3 py-1.5 text-xs font-semibold text-primary-foreground hover:bg-primary-hover transition-colors"
              >
                Create
              </button>
            </.form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Private Components ──────────────────────────

  defp stat_card(assigns) do
    accent =
      case assigns.color do
        "primary" -> "text-primary bg-primary/10"
        "emerald" -> "text-emerald-500 bg-emerald-500/10"
        "amber" -> "text-amber-500 bg-amber-500/10"
        _ -> "text-primary bg-primary/10"
      end

    assigns = assign(assigns, :accent, accent)

    ~H"""
    <div class="rounded-xl border border-border bg-surface-alt shadow-sm p-6">
      <div class="flex items-center justify-between mb-3">
        <div class={"flex items-center justify-center size-9 rounded-lg #{@accent}"}>
          <.icon name={@icon} class="size-4.5" />
        </div>
        <%= if @trend_label do %>
          <span class="inline-flex items-center rounded-full bg-surface-strong px-2 py-0.5 text-[10px] font-medium text-muted-foreground">
            {@trend_label}
          </span>
        <% end %>
      </div>
      <p class="text-3xl font-bold tracking-tight text-foreground">{@value}</p>
      <p class="text-xs text-muted-foreground mt-0.5">{@title}</p>
    </div>
    """
  end

  defp room_row(assigns) do
    color =
      case assigns.room.type do
        :document -> "bg-primary/10 text-primary"
        :whiteboard -> "bg-amber-500/10 text-amber-500"
        :canvas -> "bg-emerald-500/10 text-emerald-500"
        :video -> "bg-red-500/10 text-red-500"
        _ -> "bg-surface-strong text-muted-foreground"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <div class="flex items-center gap-3 rounded-lg px-3 py-2.5 hover:bg-surface-strong/50 transition-colors">
      <div class={"flex items-center justify-center size-8 rounded-lg #{@color}"}>
        <.icon name="hero-rectangle-group" class="size-4" />
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-sm font-medium text-foreground truncate">{@room.name}</p>
        <p class="text-xs text-muted-foreground">
          {String.capitalize(to_string(@room.type))} &middot; {Calendar.strftime(
            @room.inserted_at,
            "%b %d"
          )}
        </p>
      </div>
      <div>
        <%= if @room.is_public do %>
          <span class="inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-medium bg-emerald-500/10 text-emerald-500">
            Public
          </span>
        <% else %>
          <span class="inline-flex items-center rounded-full px-2 py-0.5 text-[10px] font-medium bg-amber-500/10 text-amber-500">
            Private
          </span>
        <% end %>
      </div>
    </div>
    """
  end

  defp action_card(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="flex flex-col items-center justify-center gap-2 rounded-xl border border-border bg-surface-alt p-4 hover:bg-surface-strong/50 hover:border-border-strong transition-colors group"
    >
      <div class="flex items-center justify-center size-9 rounded-lg bg-surface-strong group-hover:bg-primary/10 transition-colors">
        <.icon
          name={@icon}
          class="size-4.5 text-muted-foreground group-hover:text-primary transition-colors"
        />
      </div>
      <span class="text-xs font-medium text-foreground">{@label}</span>
    </.link>
    """
  end

  defp status_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <span class="text-xs text-muted-foreground">{@label}</span>
      <div class="flex items-center gap-1.5">
        <span class="size-1.5 rounded-full bg-emerald-500"></span>
        <span class="text-[10px] font-medium text-emerald-500 capitalize">{@status}</span>
      </div>
    </div>
    """
  end
end

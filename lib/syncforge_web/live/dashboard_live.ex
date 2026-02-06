defmodule SyncforgeWeb.DashboardLive do
  @moduledoc """
  Dashboard overview page showing stat cards, getting-started checklist,
  and organization context.
  """

  use SyncforgeWeb, :live_view

  alias Syncforge.Organizations
  alias Syncforge.Rooms

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    organizations = Organizations.list_user_organizations(user.id)

    # Restore selected org from session or default to first
    current_org = pick_org(organizations, session["current_org_id"])

    stats = if current_org, do: load_stats(current_org), else: %{}

    {:ok,
     socket
     |> assign(
       page_title: "Dashboard",
       organizations: organizations,
       current_org: current_org,
       active_nav: :overview,
       stats: stats
     )}
  end

  @impl true
  def handle_event("switch_org", %{"org_id" => org_id}, socket) do
    org = Enum.find(socket.assigns.organizations, &(&1.id == org_id))

    if org do
      stats = load_stats(org)

      {:noreply,
       socket
       |> assign(current_org: org, stats: stats)}
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
        stats = load_stats(org)

        {:noreply,
         socket
         |> assign(
           organizations: organizations,
           current_org: org,
           stats: stats
         )
         |> put_flash(:info, "Organization created!")}

      {:error, _step, changeset, _changes} ->
        message =
          changeset
          |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
          |> Enum.map_join(", ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)

        {:noreply, put_flash(socket, :error, "Failed to create organization: #{message}")}
    end
  end

  defp pick_org([], _session_org_id), do: nil

  defp pick_org(organizations, session_org_id) when is_binary(session_org_id) do
    Enum.find(organizations, List.first(organizations), &(&1.id == session_org_id))
  end

  defp pick_org(organizations, _), do: List.first(organizations)

  defp load_stats(org) do
    %{
      rooms: Rooms.count_rooms_for_organization(org.id),
      members: Organizations.count_members(org.id),
      api_keys: Organizations.count_api_keys(org.id)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="mb-8">
        <h1 class="text-2xl font-bold">Dashboard</h1>
        <p class="text-base-content/60 mt-1">
          Welcome, {@current_user.name}!
        </p>
      </div>

      <%= if @current_org do %>
        <%!-- Stat Cards --%>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
          <.stat_card
            title="Rooms"
            value={@stats.rooms}
            icon="hero-rectangle-group"
            description="Active collaboration rooms"
          />
          <.stat_card
            title="Members"
            value={@stats.members}
            icon="hero-users"
            description="Organization members"
          />
          <.stat_card
            title="API Keys"
            value={@stats.api_keys}
            icon="hero-key"
            description="Active API keys"
          />
        </div>

        <%!-- Quick Actions --%>
        <div class="card bg-base-200 shadow-sm">
          <div class="card-body">
            <h2 class="card-title text-lg">Quick Actions</h2>
            <div class="flex flex-wrap gap-3 mt-2">
              <.link navigate={~p"/dashboard/rooms"} class="btn btn-sm btn-outline">
                <.icon name="hero-plus" class="size-4" /> New Room
              </.link>
              <.link navigate={~p"/dashboard/api-keys"} class="btn btn-sm btn-outline">
                <.icon name="hero-key" class="size-4" /> Create API Key
              </.link>
            </div>
          </div>
        </div>
      <% else %>
        <%!-- Getting Started --%>
        <div class="card bg-base-200 shadow-sm max-w-lg">
          <div class="card-body">
            <h2 class="card-title text-lg">Getting Started</h2>
            <p class="text-base-content/60 text-sm mt-1">
              Create your first organization to start using SyncForge.
            </p>

            <ul class="mt-4 space-y-2">
              <li class="flex items-center gap-2 text-sm">
                <.icon name="hero-check-circle" class="size-5 text-success" />
                <span class="line-through text-base-content/40">Create an account</span>
              </li>
              <li class="flex items-center gap-2 text-sm">
                <.icon name="hero-minus-circle" class="size-5 text-base-content/30" />
                <span>Create your first organization</span>
              </li>
              <li class="flex items-center gap-2 text-sm text-base-content/40">
                <.icon name="hero-minus-circle" class="size-5 text-base-content/30" />
                <span>Create a room</span>
              </li>
              <li class="flex items-center gap-2 text-sm text-base-content/40">
                <.icon name="hero-minus-circle" class="size-5 text-base-content/30" />
                <span>Generate an API key</span>
              </li>
            </ul>

            <div class="divider"></div>

            <.form for={%{}} id="create-org-form" phx-submit="create_org" class="flex gap-2">
              <input
                type="text"
                name="org[name]"
                placeholder="Organization name"
                class="input input-bordered input-sm flex-1"
                required
              />
              <button type="submit" class="btn btn-primary btn-sm">
                Create
              </button>
            </.form>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp stat_card(assigns) do
    ~H"""
    <div class="card bg-base-200 shadow-sm">
      <div class="card-body">
        <div class="flex items-center justify-between">
          <h3 class="text-sm font-medium text-base-content/60">{@title}</h3>
          <.icon name={@icon} class="size-5 text-base-content/40" />
        </div>
        <p class="text-3xl font-bold mt-1">{@value}</p>
        <p class="text-xs text-base-content/50 mt-1">{@description}</p>
      </div>
    </div>
    """
  end
end

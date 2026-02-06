defmodule SyncforgeWeb.LogsLive do
  use SyncforgeWeb, :live_view

  alias Syncforge.Organizations
  alias Syncforge.Analytics

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    organizations = Organizations.list_user_organizations(user.id)
    current_org = pick_org(organizations, session["current_org_id"])

    events =
      if current_org,
        do: Analytics.list_recent_events(current_org.id, limit: 50),
        else: []

    if connected?(socket) && current_org do
      Phoenix.PubSub.subscribe(Syncforge.PubSub, "org_logs:#{current_org.id}")
    end

    {:ok,
     socket
     |> assign(
       page_title: "Logs",
       organizations: organizations,
       current_org: current_org,
       active_nav: :logs,
       has_events: events != []
     )
     |> stream(:events, events)}
  end

  @impl true
  def handle_info({:new_event, event}, socket) do
    {:noreply,
     socket
     |> assign(:has_events, true)
     |> stream_insert(:events, event, at: 0)}
  end

  @impl true
  def handle_event("switch_org", %{"org_id" => org_id}, socket) do
    # Unsubscribe from old org
    if socket.assigns.current_org do
      Phoenix.PubSub.unsubscribe(
        Syncforge.PubSub,
        "org_logs:#{socket.assigns.current_org.id}"
      )
    end

    org = Enum.find(socket.assigns.organizations, &(&1.id == org_id))

    events =
      if org,
        do: Analytics.list_recent_events(org.id, limit: 50),
        else: []

    # Subscribe to new org
    if org do
      Phoenix.PubSub.subscribe(Syncforge.PubSub, "org_logs:#{org.id}")
    end

    {:noreply,
     socket
     |> assign(current_org: org, has_events: events != [])
     |> stream(:events, events, reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-8">
      <h1 class="text-2xl font-bold">Logs</h1>
      <p class="text-base-content/60 mt-1">Real-time connection event log</p>
    </div>

    <%= if @current_org do %>
      <div class="card bg-base-200 shadow-sm">
        <div class="card-body">
          <div id="events-log" phx-update="stream">
            <div
              :for={{dom_id, event} <- @streams.events}
              id={dom_id}
              class="flex items-center gap-4 py-2 border-b border-base-300 last:border-0"
            >
              <span class={[
                "badge badge-sm",
                if(event.event_type == "join", do: "badge-success", else: "badge-warning")
              ]}>
                {event.event_type}
              </span>
              <span class="text-sm">
                <%= if event.user do %>
                  {event.user.name || event.user.email}
                <% else %>
                  <span class="text-base-content/40">Anonymous</span>
                <% end %>
              </span>
              <span class="text-sm text-base-content/50">
                <%= if event.room do %>
                  {event.room.name}
                <% else %>
                  <span class="text-base-content/40">—</span>
                <% end %>
              </span>
              <span class="text-xs text-base-content/40 ml-auto">
                {Calendar.strftime(event.inserted_at, "%Y-%m-%d %H:%M:%S")}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div :if={!@has_events} class="text-center py-12 text-base-content/50">
        <span class="hero-document-text size-12 mx-auto mb-4 block"></span>
        <p class="text-lg font-medium">No events yet</p>
        <p class="text-sm mt-1">Events will appear here as users connect to rooms.</p>
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

  defp pick_org([], _), do: nil
  defp pick_org(orgs, nil), do: List.first(orgs)

  defp pick_org(orgs, preferred_id) do
    Enum.find(orgs, List.first(orgs), &(&1.id == preferred_id))
  end
end

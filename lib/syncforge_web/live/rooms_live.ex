defmodule SyncforgeWeb.RoomsLive do
  use SyncforgeWeb, :live_view

  alias Syncforge.Organizations
  alias Syncforge.Rooms

  @impl true
  def mount(_params, session, socket) do
    user = socket.assigns.current_user
    organizations = Organizations.list_user_organizations(user.id)
    current_org = pick_org(organizations, session["current_org_id"])

    rooms =
      if current_org,
        do: Rooms.list_rooms_for_organization(current_org.id),
        else: []

    {:ok,
     socket
     |> assign(
       page_title: "Rooms",
       organizations: organizations,
       current_org: current_org,
       active_nav: :rooms,
       rooms: rooms
     )}
  end

  @impl true
  def handle_event("create_room", %{"room" => room_params}, socket) do
    org = socket.assigns.current_org

    attrs =
      room_params
      |> Map.put("organization_id", org.id)

    case Rooms.create_room(attrs) do
      {:ok, _room} ->
        rooms = Rooms.list_rooms_for_organization(org.id)

        {:noreply,
         socket
         |> put_flash(:info, "Room created")
         |> assign(rooms: rooms)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create room")}
    end
  end

  def handle_event("delete_room", %{"id" => room_id}, socket) do
    org = socket.assigns.current_org

    case Rooms.get_room(room_id) do
      %{organization_id: org_id} = room when org_id == org.id ->
        {:ok, _} = Rooms.delete_room(room)
        rooms = Rooms.list_rooms_for_organization(org.id)

        {:noreply,
         socket
         |> put_flash(:info, "Room deleted")
         |> assign(rooms: rooms)}

      _ ->
        {:noreply, put_flash(socket, :error, "Room not found")}
    end
  end

  def handle_event("switch_org", %{"org_id" => org_id}, socket) do
    org = Enum.find(socket.assigns.organizations, &(&1.id == org_id))

    rooms =
      if org,
        do: Rooms.list_rooms_for_organization(org.id),
        else: []

    {:noreply, assign(socket, current_org: org, rooms: rooms)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-8 flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold text-foreground">Rooms</h1>
        <p class="text-muted mt-1">Manage your collaboration rooms</p>
      </div>
    </div>

    <%= if @current_org do %>
      <div class="rounded-xl border border-border bg-surface-alt shadow-sm mb-6">
        <div class="p-6">
          <h2 class="text-lg font-semibold text-foreground">Create Room</h2>
          <form id="create-room-form" phx-submit="create_room" class="flex gap-3 items-end mt-3">
            <div class="flex-1 space-y-1">
              <label class="block text-sm font-medium text-foreground">Name</label>
              <input
                type="text"
                name="room[name]"
                placeholder="Room name"
                required
                class="w-full rounded-lg border border-input-border bg-input px-3 py-1.5 text-sm text-foreground placeholder-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary"
              />
            </div>
            <div class="space-y-1">
              <label class="block text-sm font-medium text-foreground">Type</label>
              <select
                name="room[type]"
                class="rounded-lg border border-input-border bg-input px-3 py-1.5 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary"
              >
                <option value="general">General</option>
                <option value="document">Document</option>
                <option value="whiteboard">Whiteboard</option>
                <option value="canvas">Canvas</option>
                <option value="video">Video</option>
              </select>
            </div>
            <button
              type="submit"
              class="inline-flex items-center gap-1.5 rounded-lg bg-primary px-3 py-1.5 text-xs font-semibold text-primary-foreground hover:bg-primary-hover transition-colors"
            >
              <span class="hero-plus size-4"></span> Create
            </button>
          </form>
        </div>
      </div>

      <%= if @rooms == [] do %>
        <div class="text-center py-12 text-muted-foreground">
          <span class="hero-rectangle-group size-12 mx-auto mb-4 block"></span>
          <p class="text-lg font-medium">No rooms yet</p>
          <p class="text-sm mt-1">Create your first room above to get started.</p>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="w-full text-sm text-left">
            <thead>
              <tr class="border-b border-border text-muted">
                <th class="pb-3 font-medium">Name</th>
                <th class="pb-3 font-medium">Type</th>
                <th class="pb-3 font-medium">Slug</th>
                <th class="pb-3 font-medium">Visibility</th>
                <th class="pb-3 font-medium">Max Participants</th>
                <th class="pb-3"></th>
              </tr>
            </thead>
            <tbody>
              <%= for room <- @rooms do %>
                <tr class="border-b border-border last:border-0">
                  <td class="py-3 font-medium text-foreground">{room.name}</td>
                  <td class="py-3">
                    <span class="inline-flex items-center rounded-full border border-border px-2 py-0.5 text-xs font-medium text-muted">
                      {room.type}
                    </span>
                  </td>
                  <td class="py-3 text-muted-foreground text-sm">{room.slug}</td>
                  <td class="py-3">
                    <%= if room.is_public do %>
                      <span class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-success/10 text-success">
                        Public
                      </span>
                    <% else %>
                      <span class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium bg-warning/10 text-warning">
                        Private
                      </span>
                    <% end %>
                  </td>
                  <td class="py-3 text-foreground">{room.max_participants}</td>
                  <td class="py-3">
                    <button
                      phx-click="delete_room"
                      phx-value-id={room.id}
                      data-confirm="Are you sure you want to delete this room?"
                      class="p-1 rounded text-error hover:bg-error/10 transition-colors"
                    >
                      <span class="hero-trash size-4"></span>
                    </button>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    <% else %>
      <div class="text-center py-12 text-muted-foreground">
        <span class="hero-building-office size-12 mx-auto mb-4 block"></span>
        <p class="text-lg font-medium">Create an organization first</p>
        <p class="text-sm mt-1">
          Go to the
          <a href="/dashboard" class="text-primary hover:underline font-medium">Dashboard</a>
          to create an organization, then come back to manage rooms.
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

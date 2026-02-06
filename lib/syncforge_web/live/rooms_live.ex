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
        <h1 class="text-2xl font-bold">Rooms</h1>
        <p class="text-base-content/60 mt-1">Manage your collaboration rooms</p>
      </div>
    </div>

    <%= if @current_org do %>
      <div class="card bg-base-200 shadow-sm mb-6">
        <div class="card-body">
          <h2 class="card-title text-lg">Create Room</h2>
          <form id="create-room-form" phx-submit="create_room" class="flex gap-3 items-end">
            <div class="form-control flex-1">
              <label class="label"><span class="label-text">Name</span></label>
              <input
                type="text"
                name="room[name]"
                placeholder="Room name"
                required
                class="input input-bordered input-sm"
              />
            </div>
            <div class="form-control">
              <label class="label"><span class="label-text">Type</span></label>
              <select name="room[type]" class="select select-bordered select-sm">
                <option value="general">General</option>
                <option value="document">Document</option>
                <option value="whiteboard">Whiteboard</option>
                <option value="canvas">Canvas</option>
                <option value="video">Video</option>
              </select>
            </div>
            <button type="submit" class="btn btn-primary btn-sm">
              <span class="hero-plus size-4"></span> Create
            </button>
          </form>
        </div>
      </div>

      <%= if @rooms == [] do %>
        <div class="text-center py-12 text-base-content/50">
          <span class="hero-rectangle-group size-12 mx-auto mb-4 block"></span>
          <p class="text-lg font-medium">No rooms yet</p>
          <p class="text-sm mt-1">Create your first room above to get started.</p>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="table table-zebra">
            <thead>
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th>Slug</th>
                <th>Visibility</th>
                <th>Max Participants</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for room <- @rooms do %>
                <tr>
                  <td class="font-medium">{room.name}</td>
                  <td>
                    <span class="badge badge-outline badge-sm">{room.type}</span>
                  </td>
                  <td class="text-base-content/50 text-sm">{room.slug}</td>
                  <td>
                    <%= if room.is_public do %>
                      <span class="badge badge-success badge-sm">Public</span>
                    <% else %>
                      <span class="badge badge-warning badge-sm">Private</span>
                    <% end %>
                  </td>
                  <td>{room.max_participants}</td>
                  <td>
                    <button
                      phx-click="delete_room"
                      phx-value-id={room.id}
                      data-confirm="Are you sure you want to delete this room?"
                      class="btn btn-ghost btn-xs text-error"
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
      <div class="text-center py-12 text-base-content/50">
        <span class="hero-building-office size-12 mx-auto mb-4 block"></span>
        <p class="text-lg font-medium">Create an organization first</p>
        <p class="text-sm mt-1">
          Go to the <a href="/dashboard" class="link link-primary">Dashboard</a>
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

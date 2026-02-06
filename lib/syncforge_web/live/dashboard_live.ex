defmodule SyncforgeWeb.DashboardLive do
  @moduledoc """
  Dashboard overview page. Placeholder for PR 2 which adds the full layout.
  """

  use SyncforgeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Dashboard")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-8">
      <h1 class="text-2xl font-bold mb-4">Dashboard</h1>
      <p class="text-base-content/60">
        Welcome, {@current_user.name}!
      </p>
      <.link href={~p"/session"} method="delete" class="btn btn-outline btn-sm mt-4">
        Log out
      </.link>
    </div>
    """
  end
end

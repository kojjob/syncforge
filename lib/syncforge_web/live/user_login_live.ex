defmodule SyncforgeWeb.UserLoginLive do
  @moduledoc """
  LiveView for the login page.

  Renders a login form that POSTs to `UserSessionController.create/2`
  to set the session cookie.
  """

  use SyncforgeWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email) || ""
    {:ok, assign(socket, page_title: "Log in", email: email), temporary_assigns: [email: ""]}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm mt-20">
      <div class="text-center mb-8">
        <h1 class="text-2xl font-bold">Sign in to SyncForge</h1>
        <p class="text-sm text-base-content/60 mt-2">
          Don't have an account?
          <.link navigate={~p"/register"} class="link link-primary font-semibold">
            Sign up
          </.link>
        </p>
      </div>

      <div class="card bg-base-200 shadow-sm">
        <div class="card-body">
          <form action={~p"/session"} method="post" class="space-y-4">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <div class="form-control">
              <label class="label" for="email">
                <span class="label-text">Email</span>
              </label>
              <input
                type="email"
                id="email"
                name="email"
                value={@email}
                class="input input-bordered w-full"
                placeholder="you@example.com"
                required
                autofocus
              />
            </div>

            <div class="form-control">
              <label class="label" for="password">
                <span class="label-text">Password</span>
              </label>
              <input
                type="password"
                id="password"
                name="password"
                class="input input-bordered w-full"
                placeholder="Your password"
                required
              />
            </div>

            <button type="submit" class="btn btn-primary w-full">
              Sign in
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end

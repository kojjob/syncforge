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
        <h1 class="text-2xl font-bold text-foreground">Sign in to SyncForge</h1>
        <p class="text-sm text-muted mt-2">
          Don't have an account?
          <.link navigate={~p"/register"} class="text-primary hover:underline font-semibold">
            Sign up
          </.link>
        </p>
      </div>

      <div class="rounded-xl border border-border bg-surface-alt shadow-sm">
        <div class="p-6">
          <form action={~p"/session"} method="post" class="space-y-4">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <div class="space-y-1">
              <label class="block text-sm font-medium text-foreground" for="email">
                Email
              </label>
              <input
                type="email"
                id="email"
                name="email"
                value={@email}
                class="w-full rounded-lg border border-input-border bg-input px-3 py-2 text-sm text-foreground placeholder-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary"
                placeholder="you@example.com"
                required
                autofocus
              />
            </div>

            <div class="space-y-1">
              <label class="block text-sm font-medium text-foreground" for="password">
                Password
              </label>
              <input
                type="password"
                id="password"
                name="password"
                class="w-full rounded-lg border border-input-border bg-input px-3 py-2 text-sm text-foreground placeholder-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary"
                placeholder="Your password"
                required
              />
            </div>

            <button
              type="submit"
              class="w-full rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground hover:bg-primary-hover transition-colors"
            >
              Sign in
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end
end

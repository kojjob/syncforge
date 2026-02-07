defmodule SyncforgeWeb.UserRegisterLive do
  @moduledoc """
  LiveView for the registration page.

  Uses `Accounts.change_user_registration/2` for real-time validation
  and a phx-submit handler that registers the user and redirects to
  the login page for sign-in.
  """

  use SyncforgeWeb, :live_view

  alias Syncforge.Accounts

  @impl true
  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%Syncforge.Accounts.User{})

    {:ok,
     assign(socket,
       page_title: "Register",
       form: to_form(changeset, as: "user"),
       trigger_submit: false
     )}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %Syncforge.Accounts.User{}
      |> Accounts.change_user_registration(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created successfully! Please log in.")
         |> redirect(to: "/login")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, as: "user"))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm mt-20">
      <div class="text-center mb-8">
        <h1 class="text-2xl font-bold text-foreground">Create your account</h1>
        <p class="text-sm text-muted mt-2">
          Already have an account?
          <.link navigate={~p"/login"} class="text-primary hover:underline font-semibold">
            Sign in
          </.link>
        </p>
      </div>

      <div class="rounded-xl border border-border bg-surface-alt shadow-sm">
        <div class="p-6">
          <.form for={@form} id="user-form" phx-change="validate" phx-submit="save" class="space-y-4">
            <div class="space-y-1">
              <label class="block text-sm font-medium text-foreground" for="user_name">
                Name
              </label>
              <.input field={@form[:name]} type="text" placeholder="Your name" required />
            </div>

            <div class="space-y-1">
              <label class="block text-sm font-medium text-foreground" for="user_email">
                Email
              </label>
              <.input field={@form[:email]} type="email" placeholder="you@example.com" required />
            </div>

            <div class="space-y-1">
              <label class="block text-sm font-medium text-foreground" for="user_password">
                Password
              </label>
              <.input
                field={@form[:password]}
                type="password"
                placeholder="Min. 8 characters"
                required
              />
            </div>

            <button
              type="submit"
              class="w-full rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-primary-foreground hover:bg-primary-hover transition-colors"
              phx-disable-with="Creating account..."
            >
              Create account
            </button>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end

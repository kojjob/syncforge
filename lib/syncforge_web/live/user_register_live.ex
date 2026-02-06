defmodule SyncforgeWeb.UserRegisterLive do
  @moduledoc """
  LiveView for the registration page.

  Uses `Accounts.change_user_registration/2` for real-time validation
  and POSTs to a phx-submit handler that registers the user and redirects
  through the session controller to set the cookie.
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
        <h1 class="text-2xl font-bold">Create your account</h1>
        <p class="text-sm text-base-content/60 mt-2">
          Already have an account?
          <.link navigate={~p"/login"} class="link link-primary font-semibold">
            Sign in
          </.link>
        </p>
      </div>

      <div class="card bg-base-200 shadow-sm">
        <div class="card-body">
          <.form for={@form} id="user-form" phx-change="validate" phx-submit="save" class="space-y-4">
            <div class="form-control">
              <label class="label" for="user_name">
                <span class="label-text">Name</span>
              </label>
              <.input field={@form[:name]} type="text" placeholder="Your name" required />
            </div>

            <div class="form-control">
              <label class="label" for="user_email">
                <span class="label-text">Email</span>
              </label>
              <.input field={@form[:email]} type="email" placeholder="you@example.com" required />
            </div>

            <div class="form-control">
              <label class="label" for="user_password">
                <span class="label-text">Password</span>
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
              class="btn btn-primary w-full"
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

defmodule SyncforgeWeb.Live.Hooks.RequireLiveAuth do
  @moduledoc """
  An `on_mount` hook that requires a user to be authenticated via browser session.

  Loads the current user from the session token and assigns it to the socket.
  Redirects to `/login` if no valid session exists.

  ## Usage

      live_session :authenticated, on_mount: [{SyncforgeWeb.Live.Hooks.RequireLiveAuth, :require_auth}] do
        live "/dashboard", DashboardLive
      end
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias Syncforge.Accounts

  def on_mount(:require_auth, _params, session, socket) do
    case session do
      %{"user_id" => user_id} when is_binary(user_id) ->
        case Accounts.get_user(user_id) do
          nil ->
            {:halt,
             socket
             |> put_flash(:error, "You must log in to access this page.")
             |> redirect(to: "/login")}

          user ->
            {:cont, assign(socket, :current_user, user)}
        end

      _ ->
        {:halt,
         socket
         |> put_flash(:error, "You must log in to access this page.")
         |> redirect(to: "/login")}
    end
  end
end

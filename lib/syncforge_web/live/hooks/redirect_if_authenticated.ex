defmodule SyncforgeWeb.Live.Hooks.RedirectIfAuthenticated do
  @moduledoc """
  An `on_mount` hook that redirects already-authenticated users away from login/register pages.

  ## Usage

      live_session :unauthenticated, on_mount: [{SyncforgeWeb.Live.Hooks.RedirectIfAuthenticated, :redirect_if_authenticated}] do
        live "/login", UserLoginLive
        live "/register", UserRegisterLive
      end
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias Syncforge.Accounts

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    case session do
      %{"user_id" => user_id} when is_binary(user_id) ->
        case Accounts.get_user(user_id) do
          nil ->
            {:cont, assign(socket, :current_user, nil)}

          _user ->
            {:halt, socket |> redirect(to: "/dashboard")}
        end

      _ ->
        {:cont, assign(socket, :current_user, nil)}
    end
  end
end

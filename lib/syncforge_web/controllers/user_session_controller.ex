defmodule SyncforgeWeb.UserSessionController do
  @moduledoc """
  Handles browser session creation and deletion for LiveView auth.

  LiveView cannot set cookies during WebSocket mount, so login/register
  forms POST to this controller which sets the session, then redirects
  into the authenticated LiveView session.
  """

  use SyncforgeWeb, :controller

  alias Syncforge.Accounts

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_by_email_and_password(email, password) do
      {:ok, user} ->
        Accounts.update_last_sign_in(user)

        conn
        |> renew_session()
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Welcome back!")
        |> redirect(to: "/dashboard")

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: "/login")
    end
  end

  def delete(conn, _params) do
    conn
    |> renew_session()
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: "/login")
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end
end

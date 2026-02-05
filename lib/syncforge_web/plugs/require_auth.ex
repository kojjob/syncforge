defmodule SyncforgeWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug that requires a valid Bearer token in the Authorization header.
  Verifies the token using Phoenix.Token with the same salt as UserSocket,
  then fetches the user from the database and assigns to conn.assigns.current_user.
  """

  import Plug.Conn

  alias Syncforge.Accounts

  # 14 days in seconds
  @max_age 86_400 * 14

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, token} <- extract_token(conn),
         {:ok, user_data} <- verify_token(token),
         %{} = user <- Accounts.get_user(user_data.id) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Unauthorized"})
        |> halt()
    end
  end

  defp extract_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> {:ok, token}
      _ -> :error
    end
  end

  defp verify_token(token) do
    case Phoenix.Token.verify(SyncforgeWeb.Endpoint, "user socket", token, max_age: @max_age) do
      {:ok, user_data} -> {:ok, user_data}
      {:error, _reason} -> :error
    end
  end
end

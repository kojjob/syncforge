defmodule SyncforgeWeb.UserSocket do
  @moduledoc """
  WebSocket handler for real-time collaboration.

  Authenticates users via signed tokens and routes them to
  appropriate channels (rooms, notifications, etc.).
  """

  use Phoenix.Socket

  alias SyncforgeWeb.RoomChannel
  alias SyncforgeWeb.NotificationChannel

  # Channels
  channel "room:*", RoomChannel
  channel "notification:*", NotificationChannel

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user.
  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case verify_token(token) do
      {:ok, user} ->
        socket =
          socket
          |> assign(:current_user, user)
          |> assign(:user_id, user.id)

        {:ok, socket}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  # Socket IDs are used to identify all sockets for a given user.
  # This allows broadcasting to all user's connected devices.
  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

  # Token verification
  # In production, tokens should be generated with an expiry
  defp verify_token(token) do
    # Max age of 2 weeks (in seconds)
    max_age = 86_400 * 14

    case Phoenix.Token.verify(SyncforgeWeb.Endpoint, "user socket", token, max_age: max_age) do
      {:ok, user} -> {:ok, user}
      {:error, reason} -> {:error, reason}
    end
  end
end

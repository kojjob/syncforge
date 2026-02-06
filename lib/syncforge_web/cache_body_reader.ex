defmodule SyncforgeWeb.CacheBodyReader do
  @moduledoc """
  Caches the raw request body so it can be used for Stripe webhook
  signature verification after Plug.Parsers has consumed it.

  Only caches for the `/api/webhooks/stripe` path to avoid unnecessary
  memory usage on other routes.
  """

  def read_body(%Plug.Conn{request_path: "/api/webhooks/stripe"} = conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        conn = Plug.Conn.put_private(conn, :raw_body, body)
        {:ok, body, conn}

      {:more, body, conn} ->
        conn = Plug.Conn.put_private(conn, :raw_body, body)
        {:more, body, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def read_body(conn, opts) do
    Plug.Conn.read_body(conn, opts)
  end
end

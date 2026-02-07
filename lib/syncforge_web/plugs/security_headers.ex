defmodule SyncforgeWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Sets security response headers.

  Two modes:
  - `:browser` — full security headers including CSP with per-request nonce
  - `:api` — minimal headers (X-Content-Type-Options, Referrer-Policy)
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    mode = Keyword.get(opts, :mode, :browser)

    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> maybe_add_browser_headers(mode)
  end

  defp maybe_add_browser_headers(conn, :api), do: conn

  defp maybe_add_browser_headers(conn, :browser) do
    nonce = generate_nonce()

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", build_csp(nonce, conn))
    |> put_resp_header(
      "permissions-policy",
      "camera=(), microphone=(), geolocation=(), payment=(self)"
    )
  end

  defp build_csp(nonce, conn) do
    host = conn.host || "localhost"
    port = conn.port || 443

    [
      "default-src 'self'",
      "script-src 'self' 'nonce-#{nonce}'",
      "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
      "font-src 'self' https://fonts.gstatic.com data:",
      "connect-src 'self' ws://#{host} ws://#{host}:#{port} wss://#{host} wss://#{host}:#{port} https://api.stripe.com",
      "frame-src https://js.stripe.com https://hooks.stripe.com",
      "frame-ancestors 'none'"
    ]
    |> Enum.join("; ")
  end

  defp generate_nonce do
    :crypto.strong_rand_bytes(16) |> Base.encode64(padding: false)
  end
end

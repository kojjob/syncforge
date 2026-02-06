defmodule SyncforgeWeb.Plugs.RateLimiter do
  @moduledoc """
  HTTP rate limiting plug using Hammer 7 ETS backend.

  Returns 429 Too Many Requests with Retry-After header when the limit is exceeded.

  ## Options

    * `:limit` - Maximum number of requests per window (required)
    * `:scale` - Window size in milliseconds (required)
    * `:by` - Rate limit key strategy: `:ip` or `:user` (default `:ip`)
    * `:hammer` - Hammer backend module or ETS table name (default `Syncforge.RateLimiter`)
    * `:disabled` - If true, skip rate limiting (useful for tests)
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    if Keyword.get(opts, :disabled, false) do
      conn
    else
      hammer = Keyword.get(opts, :hammer, Syncforge.RateLimiter)
      limit = Keyword.fetch!(opts, :limit)
      scale = Keyword.fetch!(opts, :scale)
      by = Keyword.get(opts, :by, :ip)

      case rate_limit_request(conn, hammer, limit: limit, scale: scale, by: by) do
        :ok ->
          conn

        {:deny, retry_after_ms} ->
          retry_after_s = max(div(retry_after_ms, 1000), 1)

          conn
          |> put_resp_content_type("application/json")
          |> put_resp_header("retry-after", Integer.to_string(retry_after_s))
          |> send_resp(429, Jason.encode!(%{error: "Rate limit exceeded. Try again later."}))
          |> halt()
      end
    end
  end

  @doc """
  Checks rate limit for a request. Returns `:ok` or `{:deny, retry_after_ms}`.
  """
  def rate_limit_request(conn, hammer, opts) do
    limit = Keyword.fetch!(opts, :limit)
    scale = Keyword.fetch!(opts, :scale)
    by = Keyword.get(opts, :by, :ip)

    key = build_key(conn, by)

    case do_hit(hammer, key, scale, limit) do
      {:allow, _count} -> :ok
      {:deny, retry_after} -> {:deny, retry_after}
    end
  end

  defp build_key(conn, :ip) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()
    "rl:#{conn.request_path}:#{ip}"
  end

  defp build_key(conn, :user) do
    user_id = conn.assigns[:current_user] && conn.assigns.current_user.id
    "rl:#{conn.request_path}:user:#{user_id || "anon"}"
  end

  defp do_hit(hammer, key, scale, limit) when is_atom(hammer) do
    hammer.hit(key, scale, limit)
  end
end

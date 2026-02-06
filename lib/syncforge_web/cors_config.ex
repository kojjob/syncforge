defmodule SyncforgeWeb.CorsConfig do
  @moduledoc """
  Dynamic CORS origin resolution.

  Only allows CORS on `/api` and `/socket` paths. Browser routes
  (HTML pages) do not get CORS headers.

  Reads allowed origins from application config. Supports:
  - `:all` — allow any origin (test/dev)
  - A list of strings — specific origins

  Corsica calls the origin checker as `Module.function(conn, origin)`,
  so this function must accept 2 args and return a boolean.
  """

  def allowed_origins(conn, origin) do
    if cors_path?(conn.request_path) do
      case Application.get_env(:syncforge, :cors_allowed_origins, :all) do
        :all -> true
        origins when is_list(origins) -> origin in origins
        _ -> false
      end
    else
      false
    end
  end

  defp cors_path?("/api" <> _), do: true
  defp cors_path?("/socket" <> _), do: true
  defp cors_path?(_), do: false
end

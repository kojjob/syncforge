defmodule SyncforgeWeb.HealthController do
  @moduledoc """
  Health check endpoint for load balancers and orchestrators.

  Returns 200 when the application and its dependencies are healthy,
  or 503 when a critical dependency (e.g., database) is down.
  """

  use SyncforgeWeb, :controller

  def show(conn, _params) do
    db_check = check_database()

    status = if db_check == "ok", do: :ok, else: :service_unavailable

    json(conn |> put_status(status), %{
      status: if(status == :ok, do: "healthy", else: "unhealthy"),
      version: Application.spec(:syncforge, :vsn) |> to_string(),
      checks: %{
        database: db_check
      }
    })
  end

  defp check_database do
    Syncforge.Repo.query!("SELECT 1")
    "ok"
  rescue
    _ -> "error"
  end
end

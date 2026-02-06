defmodule SyncforgeWeb.HealthControllerTest do
  use SyncforgeWeb.ConnCase, async: true

  describe "GET /health" do
    test "returns 200 with healthy status when database is up", %{conn: conn} do
      conn = get(conn, "/health")

      assert json_response(conn, 200) == %{
               "status" => "healthy",
               "version" => "0.1.0",
               "checks" => %{
                 "database" => "ok"
               }
             }
    end

    test "does not require authentication", %{conn: conn} do
      # Health endpoint should be publicly accessible (no Bearer token needed)
      conn = get(conn, "/health")

      assert conn.status == 200
    end

    test "returns JSON content type", %{conn: conn} do
      conn = get(conn, "/health")

      assert {"content-type", content_type} =
               List.keyfind(conn.resp_headers, "content-type", 0)

      assert content_type =~ "application/json"
    end
  end
end

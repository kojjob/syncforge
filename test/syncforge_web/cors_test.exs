defmodule SyncforgeWeb.CorsTest do
  use SyncforgeWeb.ConnCase, async: true

  describe "CORS preflight on /api" do
    test "returns CORS headers for allowed origin" do
      conn =
        build_conn(:options, "/api/login")
        |> put_req_header("origin", "http://localhost:3000")
        |> put_req_header("access-control-request-method", "POST")
        |> put_req_header("access-control-request-headers", "authorization, content-type")

      conn = SyncforgeWeb.Endpoint.call(conn, SyncforgeWeb.Endpoint.init([]))

      assert get_resp_header(conn, "access-control-allow-origin") != []
      assert get_resp_header(conn, "access-control-allow-methods") != []
    end

    test "returns CORS headers for allowed origin on /api paths" do
      conn =
        build_conn(:options, "/api/me")
        |> put_req_header("origin", "http://localhost:3000")
        |> put_req_header("access-control-request-method", "GET")

      conn = SyncforgeWeb.Endpoint.call(conn, SyncforgeWeb.Endpoint.init([]))

      assert get_resp_header(conn, "access-control-allow-origin") != []
    end
  end

  describe "CORS on non-API paths" do
    test "does not add CORS headers for browser routes" do
      conn =
        build_conn(:options, "/")
        |> put_req_header("origin", "http://localhost:3000")
        |> put_req_header("access-control-request-method", "GET")

      conn = SyncforgeWeb.Endpoint.call(conn, SyncforgeWeb.Endpoint.init([]))

      # Browser routes should not get CORS headers
      assert get_resp_header(conn, "access-control-allow-origin") == []
    end
  end
end

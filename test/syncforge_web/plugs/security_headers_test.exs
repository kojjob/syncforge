defmodule SyncforgeWeb.Plugs.SecurityHeadersTest do
  use SyncforgeWeb.ConnCase, async: true

  alias SyncforgeWeb.Plugs.SecurityHeaders

  describe "browser headers (call/2 with mode: :browser)" do
    setup do
      conn =
        build_conn(:get, "/")
        |> SecurityHeaders.call(mode: :browser)

      %{conn: conn}
    end

    test "sets Content-Security-Policy with nonce", %{conn: conn} do
      csp = Plug.Conn.get_resp_header(conn, "content-security-policy") |> List.first()
      assert csp =~ "default-src 'self'"
      assert csp =~ ~r/script-src 'self' 'nonce-[A-Za-z0-9+\/=]+'/
      assert csp =~ "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com"
      assert csp =~ "font-src 'self' https://fonts.gstatic.com data:"
      assert csp =~ "connect-src 'self'"
      assert csp =~ "ws://www.example.com"
      assert csp =~ "ws://www.example.com:80"
      assert csp =~ "wss://www.example.com"
      assert csp =~ "wss://www.example.com:80"
      assert csp =~ "frame-ancestors 'none'"
    end

    test "stores csp_nonce in assigns", %{conn: conn} do
      assert is_binary(conn.assigns[:csp_nonce])
      assert byte_size(conn.assigns[:csp_nonce]) > 0
    end

    test "CSP nonce matches the nonce in the header", %{conn: conn} do
      nonce = conn.assigns[:csp_nonce]
      csp = Plug.Conn.get_resp_header(conn, "content-security-policy") |> List.first()
      assert csp =~ "'nonce-#{nonce}'"
    end

    test "sets Referrer-Policy", %{conn: conn} do
      assert Plug.Conn.get_resp_header(conn, "referrer-policy") == [
               "strict-origin-when-cross-origin"
             ]
    end

    test "sets Permissions-Policy", %{conn: conn} do
      pp = Plug.Conn.get_resp_header(conn, "permissions-policy") |> List.first()
      assert pp =~ "camera=()"
      assert pp =~ "microphone=()"
      assert pp =~ "geolocation=()"
    end

    test "sets X-Content-Type-Options", %{conn: conn} do
      assert Plug.Conn.get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end
  end

  describe "API headers (call/2 with mode: :api)" do
    setup do
      conn =
        build_conn(:get, "/api/me")
        |> SecurityHeaders.call(mode: :api)

      %{conn: conn}
    end

    test "sets X-Content-Type-Options", %{conn: conn} do
      assert Plug.Conn.get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    end

    test "sets Referrer-Policy", %{conn: conn} do
      assert Plug.Conn.get_resp_header(conn, "referrer-policy") == [
               "strict-origin-when-cross-origin"
             ]
    end

    test "does NOT set Content-Security-Policy", %{conn: conn} do
      assert Plug.Conn.get_resp_header(conn, "content-security-policy") == []
    end

    test "does NOT set csp_nonce in assigns", %{conn: conn} do
      refute Map.has_key?(conn.assigns, :csp_nonce)
    end
  end
end

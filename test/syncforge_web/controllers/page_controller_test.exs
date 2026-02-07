defmodule SyncforgeWeb.PageControllerTest do
  use SyncforgeWeb.ConnCase

  test "GET / renders landing page", %{conn: conn} do
    conn = get(conn, ~p"/")
    # Landing page (LiveView) is now the root
    assert html_response(conn, 200) =~ "landing-page"
    assert html_response(conn, 200) =~ "Collaboration"
  end

  test "GET /home renders original home page", %{conn: conn} do
    conn = get(conn, ~p"/home")
    assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
  end

  test "GET /docs renders docs page", %{conn: conn} do
    conn = get(conn, ~p"/docs")
    assert html_response(conn, 200) =~ "SyncForge Documentation"
  end

  test "GET /blog renders blog page", %{conn: conn} do
    conn = get(conn, ~p"/blog")
    assert html_response(conn, 200) =~ "SyncForge Blog"
  end

  test "GET /privacy renders privacy page", %{conn: conn} do
    conn = get(conn, ~p"/privacy")
    assert html_response(conn, 200) =~ "Privacy"
  end

  test "GET /contact renders contact page", %{conn: conn} do
    conn = get(conn, ~p"/contact")
    assert html_response(conn, 200) =~ "Contact Sales"
  end
end

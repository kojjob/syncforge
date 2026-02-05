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
end

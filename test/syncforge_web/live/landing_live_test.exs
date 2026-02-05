defmodule SyncforgeWeb.LandingLiveTest do
  use SyncforgeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Landing Page" do
    test "renders the landing page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Collaboration"
      assert html =~ "landing-page"
      assert html =~ "SyncForge"
    end

    test "contains hero section with tagline", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "made seamless"
      assert html =~ "Add real-time presence"
    end

    test "displays feature sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Presence"
      assert html =~ "Live Cursors"
      assert html =~ "Comments"
      assert html =~ "Notifications"
    end

    test "displays pricing tiers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Free"
      assert html =~ "$49"
      assert html =~ "$199"
      assert html =~ "$499"
    end

    test "theme toggle changes theme", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Default theme is system
      assert render(view) =~ ~s(data-theme="system")

      # Toggle to dark
      html =
        view
        |> element(~s(button[phx-click="toggle_theme"][phx-value-theme="dark"]))
        |> render_click()

      assert html =~ ~s(data-theme="dark")

      # Toggle to light
      html =
        view
        |> element(~s(button[phx-click="toggle_theme"][phx-value-theme="light"]))
        |> render_click()

      assert html =~ ~s(data-theme="light")
    end

    test "tab switching shows different code examples", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      # Default tab is presence
      assert html =~ "Initialize SyncForge"

      # Switch to cursors tab
      html =
        view
        |> element(~s(button[phx-click="set_tab"][phx-value-tab="cursors"]))
        |> render_click()

      assert html =~ "Track and display live cursors"

      # Switch to comments tab
      html =
        view
        |> element(~s(button[phx-click="set_tab"][phx-value-tab="comments"]))
        |> render_click()

      assert html =~ "Add threaded comments"
    end

    test "contains navigation links", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~s(href="#features")
      assert html =~ ~s(href="#developers")
      assert html =~ ~s(href="#pricing")
    end

    test "contains call-to-action buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Get started"
      assert html =~ "Start building free"
    end
  end
end

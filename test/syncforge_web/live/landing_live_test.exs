defmodule SyncforgeWeb.LandingLiveTest do
  use SyncforgeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Syncforge.Marketing

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
      assert html =~ ~s(href="/register")
      refute html =~ ~s(href="/signup")
    end

    test "links to supporting marketing pages", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~s(href="/docs")
      assert html =~ ~s(href="/blog")
      assert html =~ ~s(href="/privacy")
      assert html =~ ~s(href="/contact")
    end
  end

  describe "waitlist signup" do
    test "submitting a valid email creates a signup and shows success feedback", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      email = "landing-#{System.unique_integer([:positive])}@example.com"

      html =
        view
        |> form(".cta-form", %{"email" => email})
        |> render_submit()

      assert html =~ "on the waitlist"
      assert Marketing.get_waitlist_signup_by_email(email)
    end

    test "submitting a duplicate email shows an already-on-waitlist error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      email = "duplicate-#{System.unique_integer([:positive])}@example.com"

      _first =
        view
        |> form(".cta-form", %{"email" => email})
        |> render_submit()

      html =
        view
        |> form(".cta-form", %{"email" => String.upcase(email)})
        |> render_submit()

      assert html =~ "This email is already on the waitlist."
    end

    test "submitting an invalid email shows validation feedback", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> form(".cta-form", %{"email" => "not-an-email"})
        |> render_submit()

      assert html =~ "Please enter a valid email address."
    end
  end
end

defmodule SyncforgeWeb.ApiKeysLiveTest do
  use SyncforgeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Syncforge.AccountsFixtures

  alias Syncforge.Organizations

  describe "GET /dashboard/api-keys" do
    test "redirects unauthenticated user to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/dashboard/api-keys")
    end

    test "renders API keys page for authenticated user with org", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, _org, _} = Organizations.create_organization(user, %{name: "Test Org"})

      {:ok, _lv, html} = live(conn, ~p"/dashboard/api-keys")

      assert html =~ "API Keys"
    end

    test "shows empty state when no API keys exist", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, _org, _} = Organizations.create_organization(user, %{name: "Test Org"})

      {:ok, _lv, html} = live(conn, ~p"/dashboard/api-keys")

      assert html =~ "No API keys yet"
    end

    test "lists active API keys for current org", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "Test Org"})

      {:ok, _key, _raw} =
        Organizations.create_api_key(org, %{label: "My Pub Key", type: "publishable"})

      {:ok, _lv, html} = live(conn, ~p"/dashboard/api-keys")

      assert html =~ "My Pub Key"
      assert html =~ "sf_pub_"
    end

    test "creates a new API key and shows the raw key once", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, _org, _} = Organizations.create_organization(user, %{name: "Test Org"})

      {:ok, lv, _html} = live(conn, ~p"/dashboard/api-keys")

      html =
        lv
        |> form("#create-api-key-form", api_key: %{label: "New Key", type: "publishable"})
        |> render_submit()

      # Should show the raw key
      assert html =~ "sf_pub_"
      assert html =~ "New Key"
      assert html =~ "created"
    end

    test "revokes an API key", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "Test Org"})

      {:ok, key, _raw} =
        Organizations.create_api_key(org, %{label: "Temp Key", type: "publishable"})

      {:ok, lv, html} = live(conn, ~p"/dashboard/api-keys")
      assert html =~ "Temp Key"

      html = lv |> element("[phx-click='revoke_key'][phx-value-id='#{key.id}']") |> render_click()

      assert html =~ "revoked"
    end

    test "shows revoked keys when toggle is on", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "Test Org"})

      {:ok, key, _raw} =
        Organizations.create_api_key(org, %{label: "Old Key", type: "secret"})

      {:ok, _} = Organizations.revoke_api_key(key)

      {:ok, lv, html} = live(conn, ~p"/dashboard/api-keys")

      # By default revoked keys are not shown
      refute html =~ "Old Key"

      # Toggle to show revoked
      html = lv |> element("[phx-click='toggle_revoked']") |> render_click()
      assert html =~ "Old Key"
      assert html =~ "Revoked"
    end

    test "shows no-org message when user has no organizations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/api-keys")

      assert html =~ "Create an organization"
    end

    test "distinguishes between publishable and secret key types", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "Test Org"})

      {:ok, _pub, _raw1} =
        Organizations.create_api_key(org, %{label: "Pub Key", type: "publishable"})

      {:ok, _sec, _raw2} =
        Organizations.create_api_key(org, %{label: "Sec Key", type: "secret"})

      {:ok, _lv, html} = live(conn, ~p"/dashboard/api-keys")

      assert html =~ "Pub Key"
      assert html =~ "Sec Key"
      assert html =~ "publishable"
      assert html =~ "secret"
    end
  end
end

defmodule SyncforgeWeb.BillingLiveTest do
  use SyncforgeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Syncforge.AccountsFixtures

  alias Syncforge.Organizations

  describe "GET /dashboard/billing" do
    test "redirects unauthenticated user to login", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/login"}}} = live(conn, ~p"/dashboard/billing")
    end

    test "renders billing page for authenticated user", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/billing")

      assert html =~ "Billing"
    end

    test "shows no-org message when user has no organizations", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/dashboard/billing")

      assert html =~ "Create an organization"
    end

    test "shows current plan info for org without billing", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, _org, _} = Organizations.create_organization(user, %{name: "My Org"})

      {:ok, _lv, html} = live(conn, ~p"/dashboard/billing")

      # Org without billing should show as "No plan configured"
      assert html =~ "No plan configured"
      assert html =~ "Upgrade"
    end

    test "shows plan details for org with active subscription", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "Pro Org"})

      # Set the org to pro plan
      {:ok, _org} =
        org
        |> Syncforge.Accounts.Organization.billing_changeset(%{
          plan_type: "pro",
          max_rooms: 100,
          max_monthly_connections: 10_000,
          stripe_subscription_status: "active",
          stripe_customer_id: "cus_test_123"
        })
        |> Syncforge.Repo.update()

      {:ok, _lv, html} = live(conn, ~p"/dashboard/billing")

      assert html =~ "Pro"
      assert html =~ "active"
    end

    test "shows usage meters for rooms and connections", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "Usage Org"})

      {:ok, _org} =
        org
        |> Syncforge.Accounts.Organization.billing_changeset(%{
          plan_type: "free",
          max_rooms: 5,
          max_monthly_connections: 100,
          stripe_subscription_status: "active"
        })
        |> Syncforge.Repo.update()

      {:ok, _lv, html} = live(conn, ~p"/dashboard/billing")

      assert html =~ "Rooms"
      assert html =~ "/ 5"
      assert html =~ "Monthly Active Users"
      assert html =~ "/ 100"
    end

    test "shows feature availability list", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "Feature Org"})

      {:ok, _org} =
        org
        |> Syncforge.Accounts.Organization.billing_changeset(%{
          plan_type: "pro",
          max_rooms: 100,
          max_monthly_connections: 10_000,
          stripe_subscription_status: "active"
        })
        |> Syncforge.Repo.update()

      {:ok, _lv, html} = live(conn, ~p"/dashboard/billing")

      assert html =~ "Features"
      assert html =~ "Presence"
      assert html =~ "Comments"
    end

    test "shows past-due warning for past_due subscription", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org, _} = Organizations.create_organization(user, %{name: "PastDue Org"})

      {:ok, _org} =
        org
        |> Syncforge.Accounts.Organization.billing_changeset(%{
          plan_type: "pro",
          max_rooms: 100,
          max_monthly_connections: 10_000,
          stripe_subscription_status: "past_due",
          stripe_customer_id: "cus_test_pd"
        })
        |> Syncforge.Repo.update()

      {:ok, _lv, html} = live(conn, ~p"/dashboard/billing")

      assert html =~ "past_due"
    end

    test "org switching reloads billing data", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)
      {:ok, org1, _} = Organizations.create_organization(user, %{name: "Free Org"})

      {:ok, _org1} =
        org1
        |> Syncforge.Accounts.Organization.billing_changeset(%{
          plan_type: "free",
          max_rooms: 5,
          max_monthly_connections: 100,
          stripe_subscription_status: "active"
        })
        |> Syncforge.Repo.update()

      {:ok, org2, _} = Organizations.create_organization(user, %{name: "Pro Org 2"})

      {:ok, _org2} =
        org2
        |> Syncforge.Accounts.Organization.billing_changeset(%{
          plan_type: "pro",
          max_rooms: 100,
          max_monthly_connections: 10_000,
          stripe_subscription_status: "active"
        })
        |> Syncforge.Repo.update()

      {:ok, lv, _html} = live(conn, ~p"/dashboard/billing")

      # Switch to org2
      html = lv |> element("select") |> render_change(%{"org_id" => org2.id})

      assert html =~ "Pro"
    end
  end
end

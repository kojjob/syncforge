defmodule Syncforge.Billing.PlanEnforcementTest do
  use Syncforge.DataCase, async: true

  import Syncforge.BillingFixtures
  import Syncforge.OrganizationsFixtures

  alias Syncforge.Billing
  alias Syncforge.Rooms

  describe "can_create_room?/1" do
    test "allows room creation when under limit" do
      {org, _owner} = organization_with_plan("free")
      # free plan: max_rooms = 5, no rooms created yet
      assert :ok = Billing.can_create_room?(org)
    end

    test "denies room creation when at limit" do
      {org, _owner} = organization_with_plan("free")
      # free plan: max_rooms = 5

      # Create 5 rooms to hit the limit
      for i <- 1..5 do
        {:ok, _room} =
          Rooms.create_room(%{
            name: "Room #{i}",
            organization_id: org.id,
            is_public: true
          })
      end

      assert {:error, :room_limit_reached} = Billing.can_create_room?(org)
    end

    test "allows unlimited rooms on business plan" do
      {org, _owner} = organization_with_plan("business")
      # business plan: max_rooms = 999_999 (unlimited sentinel)

      # Create a few rooms — should still be under limit
      for i <- 1..3 do
        {:ok, _room} =
          Rooms.create_room(%{
            name: "Room #{i}",
            organization_id: org.id,
            is_public: true
          })
      end

      assert :ok = Billing.can_create_room?(org)
    end

    test "allows room creation on pro plan with headroom" do
      {org, _owner} = organization_with_plan("pro")
      # pro plan: max_rooms = 100

      {:ok, _room} =
        Rooms.create_room(%{name: "Room 1", organization_id: org.id, is_public: true})

      assert :ok = Billing.can_create_room?(org)
    end
  end

  describe "can_connect?/1" do
    test "allows connection when under MAU limit" do
      {org, _owner} = organization_with_plan("pro")
      # pro plan: max_monthly_connections = 10_000, no events yet
      assert :ok = Billing.can_connect?(org)
    end

    test "denies connection when MAU limit reached" do
      # Create an org with a very low MAU limit for testing
      {org, owner} = organization_fixture()

      {:ok, org} =
        org
        |> Syncforge.Accounts.Organization.billing_changeset(%{
          plan_type: "free",
          max_rooms: 5,
          max_monthly_connections: 2
        })
        |> Syncforge.Repo.update()

      # Create a room for the events
      {:ok, room} =
        Rooms.create_room(%{name: "MAU Test Room", organization_id: org.id, is_public: true})

      # Create 2 distinct users with join events to hit the limit
      user2 = Syncforge.AccountsFixtures.user_fixture(%{password: "password123!"})

      {:ok, _} =
        Syncforge.Analytics.record_event(%{
          event_type: "join",
          organization_id: org.id,
          user_id: owner.id,
          room_id: room.id,
          metadata: %{}
        })

      {:ok, _} =
        Syncforge.Analytics.record_event(%{
          event_type: "join",
          organization_id: org.id,
          user_id: user2.id,
          room_id: room.id,
          metadata: %{}
        })

      assert {:error, :connection_limit_reached} = Billing.can_connect?(org)
    end

    test "allows connection on enterprise plan (unlimited)" do
      {org, _owner} = organization_with_plan("enterprise")
      # enterprise plan: max_monthly_connections = 999_999
      assert :ok = Billing.can_connect?(org)
    end

    test "allows connection when org has no billing period (uses 30d fallback)" do
      {org, _owner} = organization_fixture()
      # No billing period set, no events
      assert :ok = Billing.can_connect?(org)
    end
  end

  describe "feature_enabled?/2" do
    test "free plan has presence and cursors" do
      {org, _owner} = organization_with_plan("free")
      assert Billing.feature_enabled?(org, :presence)
      assert Billing.feature_enabled?(org, :cursors)
    end

    test "free plan does not have comments" do
      {org, _owner} = organization_with_plan("free")
      refute Billing.feature_enabled?(org, :comments)
    end

    test "pro plan has comments and notifications" do
      {org, _owner} = organization_with_plan("pro")
      assert Billing.feature_enabled?(org, :comments)
      assert Billing.feature_enabled?(org, :notifications)
    end

    test "pro plan does not have voice" do
      {org, _owner} = organization_with_plan("pro")
      refute Billing.feature_enabled?(org, :voice)
    end

    test "business plan has voice and analytics" do
      {org, _owner} = organization_with_plan("business")
      assert Billing.feature_enabled?(org, :voice)
      assert Billing.feature_enabled?(org, :analytics)
    end

    test "enterprise plan has all features" do
      {org, _owner} = organization_with_plan("enterprise")
      assert Billing.feature_enabled?(org, :presence)
      assert Billing.feature_enabled?(org, :voice)
      assert Billing.feature_enabled?(org, :analytics)
      assert Billing.feature_enabled?(org, :some_future_feature)
    end

    test "org without billing configured gets all features" do
      {org, _owner} = organization_fixture()
      # org has stripe_subscription_status: "none" (default) — no billing configured
      assert Billing.feature_enabled?(org, :presence)
      assert Billing.feature_enabled?(org, :comments)
      assert Billing.feature_enabled?(org, :voice)
    end
  end
end

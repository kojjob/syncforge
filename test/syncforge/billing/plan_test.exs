defmodule Syncforge.Billing.PlanTest do
  use ExUnit.Case, async: true

  alias Syncforge.Billing.Plan

  describe "limits/1" do
    test "returns limits for free plan" do
      limits = Plan.limits("free")
      assert limits.max_rooms == 5
      assert limits.max_mau == 100
      assert is_list(limits.features)
      assert :presence in limits.features
      assert :cursors in limits.features
    end

    test "returns limits for starter plan" do
      limits = Plan.limits("starter")
      assert limits.max_rooms == 10
      assert limits.max_mau == 1_000
    end

    test "returns limits for pro plan" do
      limits = Plan.limits("pro")
      assert limits.max_rooms == 100
      assert limits.max_mau == 10_000
      assert :comments in limits.features
      assert :notifications in limits.features
    end

    test "returns limits for business plan" do
      limits = Plan.limits("business")
      assert limits.max_rooms == :unlimited
      assert limits.max_mau == 50_000
      assert :voice in limits.features
      assert :analytics in limits.features
    end

    test "returns limits for enterprise plan" do
      limits = Plan.limits("enterprise")
      assert limits.max_rooms == :unlimited
      assert limits.max_mau == :unlimited
      assert limits.features == :all
    end

    test "returns nil for unknown plan" do
      assert Plan.limits("nonexistent") == nil
    end
  end

  describe "price_id/1" do
    test "returns configured price ID for starter" do
      assert Plan.price_id("starter") == "price_test_starter"
    end

    test "returns configured price ID for pro" do
      assert Plan.price_id("pro") == "price_test_pro"
    end

    test "returns configured price ID for business" do
      assert Plan.price_id("business") == "price_test_business"
    end

    test "returns nil for free plan (no Stripe price)" do
      assert Plan.price_id("free") == nil
    end

    test "returns nil for enterprise (custom pricing)" do
      assert Plan.price_id("enterprise") == nil
    end
  end

  describe "plan_for_price_id/1" do
    test "resolves price ID to plan type" do
      assert Plan.plan_for_price_id("price_test_starter") == "starter"
      assert Plan.plan_for_price_id("price_test_pro") == "pro"
      assert Plan.plan_for_price_id("price_test_business") == "business"
    end

    test "returns nil for unknown price ID" do
      assert Plan.plan_for_price_id("price_unknown") == nil
    end
  end

  describe "features/1" do
    test "free plan has presence and cursors" do
      features = Plan.features("free")
      assert :presence in features
      assert :cursors in features
      refute :comments in features
    end

    test "pro plan includes comments and notifications" do
      features = Plan.features("pro")
      assert :comments in features
      assert :notifications in features
    end

    test "enterprise plan returns :all" do
      assert Plan.features("enterprise") == :all
    end

    test "returns empty list for unknown plan" do
      assert Plan.features("nonexistent") == []
    end
  end

  describe "has_feature?/2" do
    test "free plan has presence" do
      assert Plan.has_feature?("free", :presence)
    end

    test "free plan does not have comments" do
      refute Plan.has_feature?("free", :comments)
    end

    test "enterprise plan has all features" do
      assert Plan.has_feature?("enterprise", :comments)
      assert Plan.has_feature?("enterprise", :voice)
      assert Plan.has_feature?("enterprise", :anything)
    end
  end

  describe "paid_plans/0" do
    test "returns only paid plan types" do
      paid = Plan.paid_plans()
      assert "starter" in paid
      assert "pro" in paid
      assert "business" in paid
      refute "free" in paid
      refute "enterprise" in paid
    end
  end
end

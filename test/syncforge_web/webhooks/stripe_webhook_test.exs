defmodule SyncforgeWeb.StripeWebhookTest do
  use Syncforge.DataCase, async: true

  import Syncforge.BillingFixtures

  alias Syncforge.Billing
  alias Syncforge.Billing.BillingEvent

  describe "process_webhook_event/1 - checkout.session.completed" do
    test "upgrades org to the purchased plan" do
      {org, _owner} = organization_with_stripe()
      price_id = Application.get_env(:syncforge, :stripe_prices)[:pro]

      event = %{
        id: "evt_checkout_#{System.unique_integer([:positive])}",
        type: "checkout.session.completed",
        data: %{
          object: %{
            metadata: %{"organization_id" => org.id},
            subscription: "sub_new_from_checkout"
          }
        }
      }

      # The handler needs to fetch the subscription to get the price
      Syncforge.Billing.StripeClientMock
      |> Mox.expect(:get_subscription, fn "sub_new_from_checkout" ->
        {:ok,
         %{
           id: "sub_new_from_checkout",
           status: "active",
           items: %{data: [%{price: %{id: price_id}}]},
           current_period_start: DateTime.utc_now() |> DateTime.to_unix(),
           current_period_end: DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.to_unix()
         }}
      end)

      assert :ok = Billing.process_webhook_event(event)

      updated_org = Syncforge.Repo.get!(Syncforge.Accounts.Organization, org.id)
      assert updated_org.plan_type == "pro"
      assert updated_org.stripe_subscription_id == "sub_new_from_checkout"
      assert updated_org.stripe_subscription_status == "active"
    end
  end

  describe "process_webhook_event/1 - customer.subscription.updated" do
    test "syncs subscription changes to org" do
      {org, _owner} = organization_with_stripe()
      price_id = Application.get_env(:syncforge, :stripe_prices)[:business]

      event = %{
        id: "evt_sub_updated_#{System.unique_integer([:positive])}",
        type: "customer.subscription.updated",
        data: %{
          object: %{
            id: org.stripe_subscription_id,
            status: "active",
            items: %{data: [%{price: %{id: price_id}}]},
            current_period_start: DateTime.utc_now() |> DateTime.to_unix(),
            current_period_end:
              DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.to_unix(),
            customer: org.stripe_customer_id
          }
        }
      }

      assert :ok = Billing.process_webhook_event(event)

      updated_org = Syncforge.Repo.get!(Syncforge.Accounts.Organization, org.id)
      assert updated_org.plan_type == "business"
    end
  end

  describe "process_webhook_event/1 - customer.subscription.deleted" do
    test "downgrades org to free plan" do
      {org, _owner} = organization_with_stripe(%{plan_type: "pro"})

      event = %{
        id: "evt_sub_deleted_#{System.unique_integer([:positive])}",
        type: "customer.subscription.deleted",
        data: %{
          object: %{
            id: org.stripe_subscription_id,
            status: "canceled",
            items: %{data: []},
            current_period_start: DateTime.utc_now() |> DateTime.to_unix(),
            current_period_end:
              DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.to_unix(),
            customer: org.stripe_customer_id
          }
        }
      }

      assert :ok = Billing.process_webhook_event(event)

      updated_org = Syncforge.Repo.get!(Syncforge.Accounts.Organization, org.id)
      assert updated_org.plan_type == "free"
      assert updated_org.stripe_subscription_status == "canceled"
    end
  end

  describe "process_webhook_event/1 - invoice.payment_failed" do
    test "marks subscription as past_due" do
      {org, _owner} = organization_with_stripe(%{stripe_subscription_status: "active"})

      event = %{
        id: "evt_inv_failed_#{System.unique_integer([:positive])}",
        type: "invoice.payment_failed",
        data: %{
          object: %{
            subscription: org.stripe_subscription_id,
            customer: org.stripe_customer_id
          }
        }
      }

      assert :ok = Billing.process_webhook_event(event)

      updated_org = Syncforge.Repo.get!(Syncforge.Accounts.Organization, org.id)
      assert updated_org.stripe_subscription_status == "past_due"
    end
  end

  describe "process_webhook_event/1 - idempotency" do
    test "skips already-processed events" do
      {org, _owner} = organization_with_stripe()
      event_id = "evt_idempotent_#{System.unique_integer([:positive])}"
      price_id = Application.get_env(:syncforge, :stripe_prices)[:pro]

      event = %{
        id: event_id,
        type: "customer.subscription.updated",
        data: %{
          object: %{
            id: org.stripe_subscription_id,
            status: "active",
            items: %{data: [%{price: %{id: price_id}}]},
            current_period_start: DateTime.utc_now() |> DateTime.to_unix(),
            current_period_end:
              DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.to_unix(),
            customer: org.stripe_customer_id
          }
        }
      }

      # Process first time
      assert :ok = Billing.process_webhook_event(event)

      # Process second time — should be idempotent
      assert :ok = Billing.process_webhook_event(event)

      # Only one billing event record
      count =
        Syncforge.Repo.aggregate(
          from(e in BillingEvent, where: e.stripe_event_id == ^event_id),
          :count
        )

      assert count == 1
    end
  end

  describe "process_webhook_event/1 - unknown event" do
    test "records but does not error on unknown event types" do
      event = %{
        id: "evt_unknown_#{System.unique_integer([:positive])}",
        type: "some.unknown.event",
        data: %{object: %{}}
      }

      assert :ok = Billing.process_webhook_event(event)
    end
  end
end

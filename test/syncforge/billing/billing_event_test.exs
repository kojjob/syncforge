defmodule Syncforge.Billing.BillingEventTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Billing.BillingEvent

  describe "changeset/2" do
    test "valid changeset with required fields" do
      changeset =
        BillingEvent.changeset(%BillingEvent{}, %{
          stripe_event_id: "evt_123",
          event_type: "checkout.session.completed",
          payload: %{"id" => "evt_123"}
        })

      assert changeset.valid?
    end

    test "requires stripe_event_id" do
      changeset =
        BillingEvent.changeset(%BillingEvent{}, %{
          event_type: "checkout.session.completed",
          payload: %{}
        })

      assert %{stripe_event_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires event_type" do
      changeset =
        BillingEvent.changeset(%BillingEvent{}, %{
          stripe_event_id: "evt_123",
          payload: %{}
        })

      assert %{event_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires payload" do
      changeset =
        BillingEvent.changeset(%BillingEvent{}, %{
          stripe_event_id: "evt_123",
          event_type: "checkout.session.completed"
        })

      assert %{payload: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts optional organization_id" do
      changeset =
        BillingEvent.changeset(%BillingEvent{}, %{
          stripe_event_id: "evt_123",
          event_type: "checkout.session.completed",
          payload: %{},
          organization_id: Ecto.UUID.generate()
        })

      assert changeset.valid?
    end

    test "accepts optional error field" do
      changeset =
        BillingEvent.changeset(%BillingEvent{}, %{
          stripe_event_id: "evt_123",
          event_type: "checkout.session.completed",
          payload: %{},
          error: "Something went wrong"
        })

      assert changeset.valid?
    end

    test "enforces unique stripe_event_id on insert" do
      {:ok, _event} =
        %BillingEvent{}
        |> BillingEvent.changeset(%{
          stripe_event_id: "evt_unique_test",
          event_type: "test.event",
          payload: %{"test" => true}
        })
        |> Syncforge.Repo.insert()

      {:error, changeset} =
        %BillingEvent{}
        |> BillingEvent.changeset(%{
          stripe_event_id: "evt_unique_test",
          event_type: "test.event",
          payload: %{"test" => true}
        })
        |> Syncforge.Repo.insert()

      assert %{stripe_event_id: ["has already been taken"]} = errors_on(changeset)
    end
  end
end

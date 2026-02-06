defmodule Syncforge.Billing.OrganizationBillingFieldsTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Accounts.Organization

  describe "billing fields on organization" do
    test "billing fields default to nil/none" do
      changeset =
        Organization.create_changeset(%Organization{}, %{name: "Test Org"})

      org = Ecto.Changeset.apply_changes(changeset)

      assert org.stripe_customer_id == nil
      assert org.stripe_subscription_id == nil
      assert org.stripe_subscription_status == "none"
      assert org.billing_email == nil
      assert org.current_period_start == nil
      assert org.current_period_end == nil
    end

    test "billing_changeset accepts billing fields" do
      changeset =
        Organization.billing_changeset(%Organization{}, %{
          stripe_customer_id: "cus_123",
          stripe_subscription_id: "sub_456",
          stripe_subscription_status: "active",
          billing_email: "billing@example.com",
          current_period_start: ~U[2026-02-01 00:00:00.000000Z],
          current_period_end: ~U[2026-03-01 00:00:00.000000Z]
        })

      assert changeset.valid?

      org = Ecto.Changeset.apply_changes(changeset)
      assert org.stripe_customer_id == "cus_123"
      assert org.stripe_subscription_id == "sub_456"
      assert org.stripe_subscription_status == "active"
      assert org.billing_email == "billing@example.com"
    end

    test "billing_changeset validates subscription status values" do
      changeset =
        Organization.billing_changeset(%Organization{}, %{
          stripe_subscription_status: "invalid_status"
        })

      assert %{stripe_subscription_status: [_]} = errors_on(changeset)
    end

    test "billing_changeset allows valid subscription statuses" do
      for status <- ~w(none active past_due canceled trialing unpaid incomplete) do
        changeset =
          Organization.billing_changeset(%Organization{}, %{
            stripe_subscription_status: status
          })

        assert changeset.valid?,
               "Expected status '#{status}' to be valid, got errors: #{inspect(errors_on(changeset))}"
      end
    end

    test "billing_changeset also updates plan_type and limits" do
      changeset =
        Organization.billing_changeset(%Organization{}, %{
          plan_type: "pro",
          max_rooms: 100,
          max_monthly_connections: 10_000
        })

      assert changeset.valid?

      org = Ecto.Changeset.apply_changes(changeset)
      assert org.plan_type == "pro"
      assert org.max_rooms == 100
      assert org.max_monthly_connections == 10_000
    end
  end
end

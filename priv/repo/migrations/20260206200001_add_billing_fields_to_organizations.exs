defmodule Syncforge.Repo.Migrations.AddBillingFieldsToOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :stripe_customer_id, :string
      add :stripe_subscription_id, :string
      add :stripe_subscription_status, :string, default: "none", null: false
      add :billing_email, :string
      add :current_period_start, :utc_datetime_usec
      add :current_period_end, :utc_datetime_usec
    end

    create unique_index(:organizations, [:stripe_customer_id],
             where: "stripe_customer_id IS NOT NULL"
           )

    create index(:organizations, [:stripe_subscription_id])
    create index(:organizations, [:stripe_subscription_status])
  end
end

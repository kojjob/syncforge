defmodule Syncforge.Repo.Migrations.CreateBillingEvents do
  use Ecto.Migration

  def change do
    create table(:billing_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :stripe_event_id, :string, null: false
      add :event_type, :string, null: false
      add :payload, :map, null: false, default: %{}
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :nilify_all)
      add :processed_at, :utc_datetime_usec
      add :error, :text

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:billing_events, [:stripe_event_id])
    create index(:billing_events, [:organization_id])
    create index(:billing_events, [:event_type])
  end
end

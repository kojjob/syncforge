defmodule Syncforge.Repo.Migrations.AddPerfCompositeIndexes do
  use Ecto.Migration

  def change do
    # Composite index for Analytics queries that filter by org + event_type + time range
    create index(:connection_events, [:organization_id, :event_type, :inserted_at])
  end
end

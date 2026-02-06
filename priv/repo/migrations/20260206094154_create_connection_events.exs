defmodule Syncforge.Repo.Migrations.CreateConnectionEvents do
  use Ecto.Migration

  def change do
    create table(:connection_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all)
      add :room_id, references(:rooms, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :event_type, :string, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:connection_events, [:organization_id])
    create index(:connection_events, [:room_id])
    create index(:connection_events, [:user_id])
    create index(:connection_events, [:event_type])
    create index(:connection_events, [:inserted_at])
  end
end

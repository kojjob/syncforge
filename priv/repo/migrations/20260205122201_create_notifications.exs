defmodule Syncforge.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :payload, :map, default: %{}
      add :read_at, :utc_datetime_usec

      add :user_id, :binary_id, null: false
      add :actor_id, :binary_id
      add :room_id, references(:rooms, on_delete: :delete_all, type: :binary_id)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:actor_id])
    create index(:notifications, [:room_id])
    create index(:notifications, [:user_id, :read_at])
    create index(:notifications, [:inserted_at])
  end
end

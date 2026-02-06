defmodule Syncforge.Repo.Migrations.CreateApiKeysAndAddOrgToRooms do
  use Ecto.Migration

  def change do
    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :label, :string, null: false
      add :key_prefix, :string, null: false
      add :key_hash, :string, null: false
      add :type, :string, null: false, default: "publishable"
      add :status, :string, null: false, default: "active"
      add :scopes, {:array, :string}, null: false, default: ["read", "write"]
      add :rate_limit, :integer, null: false, default: 1000
      add :expires_at, :utc_datetime_usec
      add :allowed_origins, {:array, :string}, null: false, default: []
      add :created_by_id, :binary_id

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:api_keys, [:key_hash])
    create index(:api_keys, [:organization_id])
    create index(:api_keys, [:status])
    create index(:api_keys, [:key_prefix])

    alter table(:rooms) do
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:rooms, [:organization_id])
  end
end

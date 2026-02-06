defmodule Syncforge.Repo.Migrations.CreateMemberships do
  use Ecto.Migration

  def change do
    create table(:memberships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false, default: "member"
      add :status, :string, null: false, default: "active"
      add :invited_at, :utc_datetime_usec
      add :accepted_at, :utc_datetime_usec
      add :invited_by_id, :binary_id

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:memberships, [:user_id, :organization_id])
    create index(:memberships, [:organization_id])
    create index(:memberships, [:user_id])
    create index(:memberships, [:status])
  end
end

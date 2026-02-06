defmodule Syncforge.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def change do
    create table(:organizations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :logo_url, :string
      add :plan_type, :string, null: false, default: "free"
      add :max_rooms, :integer, null: false, default: 3
      add :max_monthly_connections, :integer, null: false, default: 50
      add :settings, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:organizations, [:slug])
    create index(:organizations, [:plan_type])
  end
end

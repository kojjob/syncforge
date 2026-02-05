defmodule Syncforge.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    # Create enum type for room types
    execute(
      "CREATE TYPE room_type AS ENUM ('general', 'document', 'whiteboard', 'canvas', 'video')",
      "DROP TYPE room_type"
    )

    create table(:rooms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :type, :room_type, null: false, default: "general"
      add :description, :text
      add :max_participants, :integer, null: false, default: 100
      add :is_public, :boolean, null: false, default: true
      add :config, :map, null: false, default: %{}
      add :metadata, :map, null: false, default: %{}

      # Future foreign keys (will be added when User/Organization schemas exist)
      # add :creator_id, references(:users, type: :binary_id)
      # add :organization_id, references(:organizations, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    # Unique index on slug for URL-based lookups
    create unique_index(:rooms, [:slug])

    # Index for listing public rooms
    create index(:rooms, [:is_public])

    # Index for filtering by type
    create index(:rooms, [:type])

    # Composite index for common queries
    create index(:rooms, [:is_public, :type])
  end
end

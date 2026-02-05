defmodule Syncforge.Repo.Migrations.CreateActivities do
  @moduledoc """
  Creates the activities table for room-level activity feeds.

  Activities track collaboration events within a room, providing a shared
  chronological history visible to all room members.
  """

  use Ecto.Migration

  def change do
    create table(:activities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :room_id, references(:rooms, type: :binary_id, on_delete: :delete_all), null: false
      add :actor_id, :binary_id
      add :subject_id, :binary_id
      add :subject_type, :string
      add :payload, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    # Index for listing activities by room (primary access pattern)
    create index(:activities, [:room_id])

    # Compound index for paginated queries ordered by time
    create index(:activities, [:room_id, :inserted_at])

    # Index for actor-based queries (e.g., "activities by user")
    create index(:activities, [:actor_id])

    # Index for cleanup of old activities
    create index(:activities, [:inserted_at])
  end
end

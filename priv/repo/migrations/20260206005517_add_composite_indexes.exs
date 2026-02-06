defmodule Syncforge.Repo.Migrations.AddCompositeIndexes do
  use Ecto.Migration

  def change do
    # Comments: paginated listing by room
    create_if_not_exists index(:comments, [:room_id, :inserted_at])
    # Comments: threaded queries
    create index(:comments, [:room_id, :parent_id])
    # Comments: anchor lookups within a room
    create index(:comments, [:room_id, :anchor_id])

    # Notifications: paginated listing by user sorted by time
    create index(:notifications, [:user_id, :inserted_at])
  end
end

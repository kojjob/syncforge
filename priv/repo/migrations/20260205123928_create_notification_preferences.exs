defmodule Syncforge.Repo.Migrations.CreateNotificationPreferences do
  use Ecto.Migration

  def change do
    create table(:notification_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, :binary_id, null: false

      # Per-type preferences (all default to true)
      add :comment_mention, :boolean, default: true, null: false
      add :comment_reply, :boolean, default: true, null: false
      add :comment_resolved, :boolean, default: true, null: false
      add :reaction_added, :boolean, default: true, null: false
      add :room_invite, :boolean, default: true, null: false
      add :user_joined, :boolean, default: true, null: false

      # Delivery channel preferences
      add :email_enabled, :boolean, default: true, null: false
      add :push_enabled, :boolean, default: true, null: false

      timestamps(type: :utc_datetime_usec)
    end

    # Each user can only have one preference record
    create unique_index(:notification_preferences, [:user_id])
  end
end

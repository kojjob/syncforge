defmodule Syncforge.Repo.Migrations.CreateReactions do
  use Ecto.Migration

  def change do
    create table(:reactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :emoji, :string, null: false
      add :user_id, :binary_id, null: false

      add :comment_id, references(:comments, on_delete: :delete_all, type: :binary_id),
        null: false

      timestamps(type: :utc_datetime)
    end

    create index(:reactions, [:comment_id])
    create index(:reactions, [:user_id])
    create unique_index(:reactions, [:comment_id, :user_id, :emoji])
  end
end

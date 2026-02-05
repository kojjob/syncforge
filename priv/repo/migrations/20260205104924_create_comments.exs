defmodule Syncforge.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :anchor_id, :string
      add :anchor_type, :string
      add :position, :map
      add :resolved_at, :utc_datetime

      add :room_id, references(:rooms, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, :binary_id, null: false
      add :parent_id, references(:comments, on_delete: :delete_all, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:comments, [:room_id])
    create index(:comments, [:user_id])
    create index(:comments, [:parent_id])
    create index(:comments, [:anchor_id])
    create index(:comments, [:resolved_at])
  end
end

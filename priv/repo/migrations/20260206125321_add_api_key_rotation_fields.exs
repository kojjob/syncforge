defmodule Syncforge.Repo.Migrations.AddApiKeyRotationFields do
  use Ecto.Migration

  def change do
    alter table(:api_keys) do
      add :rotated_at, :utc_datetime_usec
      add :replaced_by_id, references(:api_keys, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:api_keys, [:replaced_by_id])
  end
end

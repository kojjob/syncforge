defmodule Syncforge.Repo.Migrations.AddPasswordResetAndConfirmationTokens do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :reset_password_token_hash, :string
      add :reset_password_sent_at, :utc_datetime_usec
      add :confirmation_token_hash, :string
      add :confirmation_sent_at, :utc_datetime_usec
    end

    create unique_index(:users, [:reset_password_token_hash])
    create unique_index(:users, [:confirmation_token_hash])
  end
end

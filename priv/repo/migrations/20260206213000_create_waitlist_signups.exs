defmodule Syncforge.Repo.Migrations.CreateWaitlistSignups do
  use Ecto.Migration

  def change do
    create table(:waitlist_signups, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :source, :string, null: false, default: "landing_page"
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:waitlist_signups, [:email])
    create index(:waitlist_signups, [:inserted_at])
  end
end

defmodule Syncforge.Analytics.ConnectionEvent do
  @moduledoc """
  Records channel join/leave events for analytics.

  Event types:
  - `join` — user joined a room channel
  - `leave` — user left a room channel
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "connection_events" do
    field :event_type, :string
    field :metadata, :map, default: %{}

    belongs_to :organization, Syncforge.Accounts.Organization
    belongs_to :room, Syncforge.Rooms.Room
    belongs_to :user, Syncforge.Accounts.User

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_type, :metadata, :organization_id, :room_id, :user_id])
    |> validate_required([:event_type])
    |> validate_inclusion(:event_type, ~w(join leave))
  end
end

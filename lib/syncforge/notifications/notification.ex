defmodule Syncforge.Notifications.Notification do
  @moduledoc """
  Schema for user notifications.

  Notifications track activity that users should be aware of, such as:
  - Being mentioned in a comment
  - Receiving a reply to a comment
  - Having a comment resolved
  - Receiving a reaction on a comment
  - Being invited to a room
  - A new user joining a room
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Syncforge.Rooms.Room

  @valid_types ~w(comment_mention comment_reply comment_resolved reaction_added room_invite user_joined)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notifications" do
    field :type, :string
    field :payload, :map, default: %{}
    field :read_at, :utc_datetime_usec

    field :user_id, :binary_id
    field :actor_id, :binary_id
    belongs_to :room, Room

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Returns the list of valid notification types.
  """
  def valid_types, do: @valid_types

  @doc """
  Changeset for creating a notification.
  """
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:type, :user_id, :actor_id, :room_id, :payload, :read_at])
    |> validate_required([:type, :user_id])
    |> validate_inclusion(:type, @valid_types)
    |> foreign_key_constraint(:room_id)
  end
end

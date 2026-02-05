defmodule Syncforge.Activity.Activity do
  @moduledoc """
  Schema for room activity feed entries.

  Activities track collaboration events within a room, providing a shared
  chronological history visible to all room members. This complements the
  user-centric notification system.

  ## Key Differences from Notifications

  - **Scope**: Room-centric vs. user-centric
  - **Visibility**: Shared history visible to all room members
  - **Read Status**: No read/unread tracking (always visible)
  - **Preferences**: Not subject to per-user delivery preferences

  ## Activity Types

  - `user_joined` - User joined the room
  - `user_left` - User left the room
  - `comment_created` - New comment posted
  - `comment_resolved` - Comment thread resolved
  - `comment_deleted` - Comment removed
  - `reaction_added` - Emoji reaction added
  - `reaction_removed` - Emoji reaction removed
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Syncforge.Rooms.Room

  @valid_types ~w(user_joined user_left comment_created comment_resolved comment_deleted reaction_added reaction_removed)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "activities" do
    field :type, :string
    field :actor_id, :binary_id
    field :subject_id, :binary_id
    field :subject_type, :string
    field :payload, :map, default: %{}

    belongs_to :room, Room

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Returns the list of valid activity types.
  """
  def valid_types, do: @valid_types

  @doc """
  Changeset for creating an activity.

  ## Required Fields

  - `type` - Must be one of the valid activity types
  - `room_id` - The room where the activity occurred

  ## Optional Fields

  - `actor_id` - Who performed the action (nil for system events)
  - `subject_id` - What was acted upon (e.g., comment_id)
  - `subject_type` - Type of subject (e.g., "comment")
  - `payload` - Additional context data
  """
  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:type, :room_id, :actor_id, :subject_id, :subject_type, :payload])
    |> validate_required([:type, :room_id])
    |> validate_inclusion(:type, @valid_types)
    |> foreign_key_constraint(:room_id)
  end
end

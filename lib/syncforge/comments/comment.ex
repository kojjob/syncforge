defmodule Syncforge.Comments.Comment do
  @moduledoc """
  Represents a comment in a collaboration room.

  Comments can be:
  - Anchored to specific elements via `anchor_id` and `anchor_type`
  - Positioned at specific coordinates via `position`
  - Threaded via `parent_id` for replies
  - Resolved via `resolved_at` timestamp

  ## Anchor Types

  - `element` - Attached to a specific DOM element
  - `selection` - Attached to a text selection
  - `point` - Attached to a specific coordinate point

  ## Threading

  Comments support threading through the `parent_id` field.
  Top-level comments have `parent_id = nil`.
  Replies reference their parent comment's ID.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Syncforge.Rooms.Room

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_anchor_types ["element", "selection", "point"]

  schema "comments" do
    field :body, :string
    field :anchor_id, :string
    field :anchor_type, :string
    field :position, :map
    field :resolved_at, :utc_datetime
    field :user_id, :binary_id

    belongs_to :room, Room
    belongs_to :parent, __MODULE__
    has_many :replies, __MODULE__, foreign_key: :parent_id

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid anchor types.
  """
  def valid_anchor_types, do: @valid_anchor_types

  @doc """
  Builds a changeset for creating a new comment.
  """
  def create_changeset(comment, attrs) do
    comment
    |> cast(attrs, [
      :body,
      :anchor_id,
      :anchor_type,
      :position,
      :room_id,
      :user_id,
      :parent_id
    ])
    |> validate_required([:body, :room_id, :user_id])
    |> validate_length(:body, min: 1, max: 10_000)
    |> validate_inclusion(:anchor_type, @valid_anchor_types)
    |> foreign_key_constraint(:room_id)
    |> foreign_key_constraint(:parent_id)
  end

  @doc """
  Builds a changeset for updating an existing comment.

  Note: `room_id` and `user_id` cannot be changed after creation.
  """
  def update_changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :anchor_id, :anchor_type, :position])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 10_000)
    |> validate_inclusion(:anchor_type, @valid_anchor_types)
  end

  @doc """
  Builds a changeset for resolving or unresolving a comment.
  """
  def resolve_changeset(comment, resolved_at) do
    comment
    |> cast(%{resolved_at: resolved_at}, [:resolved_at])
  end
end

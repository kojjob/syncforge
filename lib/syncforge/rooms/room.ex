defmodule Syncforge.Rooms.Room do
  @moduledoc """
  Represents a collaboration room where users interact in real-time.

  Rooms are the primary container for real-time collaboration features:
  - Presence tracking (who's in the room)
  - Live cursors
  - Document sync
  - Comments and annotations

  ## Room Types

  - `general` - Default room type for basic collaboration
  - `document` - Text document collaboration (Google Docs-like)
  - `whiteboard` - Freeform canvas collaboration
  - `canvas` - Design collaboration (Figma-like)
  - `video` - Video conferencing room

  ## Configuration

  The `config` field stores room-specific settings as JSON:
  - `theme` - UI theme for the room
  - `allow_anonymous` - Whether anonymous users can join
  - `features` - List of enabled features (cursors, comments, etc.)

  ## Metadata

  The `metadata` field stores arbitrary data:
  - `created_by` - User ID who created the room
  - `project_id` - External project reference
  - Custom application-specific data
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_types ~w(general document whiteboard canvas video)

  schema "rooms" do
    field :name, :string
    field :slug, :string

    field :type, Ecto.Enum,
      values: [:general, :document, :whiteboard, :canvas, :video],
      default: :general

    field :description, :string
    field :max_participants, :integer, default: 100
    field :is_public, :boolean, default: true
    field :config, :map, default: %{}
    field :metadata, :map, default: %{}

    belongs_to :organization, Syncforge.Accounts.Organization

    # Future associations
    # belongs_to :creator, Syncforge.Accounts.User
    # has_many :documents, Syncforge.Documents.Document
    # has_many :comments, Syncforge.Comments.Comment

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid room types.
  """
  def valid_types, do: @valid_types

  @doc """
  Builds a changeset for creating a new room.
  """
  def create_changeset(room, attrs) do
    room
    |> cast(attrs, [
      :name,
      :slug,
      :type,
      :description,
      :max_participants,
      :is_public,
      :config,
      :metadata,
      :organization_id
    ])
    |> validate_required([:name])
    |> generate_slug_if_missing()
    |> validate_length(:name, min: 1, max: 255)
    |> validate_slug_format()
    |> validate_number(:max_participants, greater_than: 0)
    |> validate_inclusion(:type, [:general, :document, :whiteboard, :canvas, :video])
    |> unique_constraint(:slug)
  end

  @doc """
  Builds a changeset for updating an existing room.
  """
  def update_changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :slug, :description, :max_participants, :is_public, :config, :metadata])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_slug_format()
    |> validate_number(:max_participants, greater_than: 0)
    |> unique_constraint(:slug)
  end

  # Generate a URL-safe slug from the name if not provided
  defp generate_slug_if_missing(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        name = get_change(changeset, :name) || get_field(changeset, :name)

        if name do
          slug = slugify(name)
          put_change(changeset, :slug, slug)
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  # Convert a string to a URL-safe slug
  defp slugify(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/[\s_]+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  # Validate that the slug is URL-safe
  defp validate_slug_format(changeset) do
    validate_format(changeset, :slug, ~r/^[a-z0-9_-]+$/,
      message: "must be URL-safe (letters, numbers, hyphens, underscores)"
    )
  end
end

defmodule Syncforge.Accounts.Organization do
  @moduledoc """
  Represents an organization for multi-tenant collaboration.

  Organizations group users (via memberships) and rooms together,
  with configurable plan limits and settings.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_plan_types ~w(free starter pro business enterprise)

  schema "organizations" do
    field :name, :string
    field :slug, :string
    field :logo_url, :string
    field :plan_type, :string, default: "free"
    field :max_rooms, :integer, default: 3
    field :max_monthly_connections, :integer, default: 50
    field :settings, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  def valid_plan_types, do: @valid_plan_types

  @doc """
  Builds a changeset for creating a new organization.
  Auto-generates a slug from the name if not provided.
  """
  def create_changeset(organization, attrs) do
    organization
    |> cast(attrs, [
      :name,
      :slug,
      :logo_url,
      :plan_type,
      :max_rooms,
      :max_monthly_connections,
      :settings
    ])
    |> validate_required([:name])
    |> generate_slug_if_missing()
    |> validate_length(:name, min: 1, max: 255)
    |> validate_slug_format()
    |> validate_inclusion(:plan_type, @valid_plan_types)
    |> validate_number(:max_rooms, greater_than: 0)
    |> validate_number(:max_monthly_connections, greater_than: 0)
    |> unique_constraint(:slug)
  end

  @doc """
  Builds a changeset for updating an existing organization.
  Does not auto-generate slug — slug changes must be explicit.
  """
  def update_changeset(organization, attrs) do
    organization
    |> cast(attrs, [
      :name,
      :slug,
      :logo_url,
      :plan_type,
      :max_rooms,
      :max_monthly_connections,
      :settings
    ])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_slug_format()
    |> validate_inclusion(:plan_type, @valid_plan_types)
    |> validate_number(:max_rooms, greater_than: 0)
    |> validate_number(:max_monthly_connections, greater_than: 0)
    |> unique_constraint(:slug)
  end

  defp generate_slug_if_missing(changeset) do
    case get_change(changeset, :slug) do
      nil ->
        name = get_change(changeset, :name) || get_field(changeset, :name)

        if name do
          put_change(changeset, :slug, slugify(name))
        else
          changeset
        end

      _ ->
        changeset
    end
  end

  defp slugify(string) do
    string
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/[\s_]+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp validate_slug_format(changeset) do
    validate_format(changeset, :slug, ~r/^[a-z0-9_-]+$/,
      message: "must be URL-safe (letters, numbers, hyphens, underscores)"
    )
  end
end

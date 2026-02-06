defmodule Syncforge.Accounts.Membership do
  @moduledoc """
  Represents a user's membership in an organization.

  Memberships track role, status, and invitation metadata.
  A user can belong to multiple organizations, each with a different role.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Syncforge.Accounts.{Organization, User}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_roles ~w(owner admin member viewer)
  @valid_statuses ~w(active invited suspended)

  schema "memberships" do
    field :role, :string, default: "member"
    field :status, :string, default: "active"
    field :invited_at, :utc_datetime_usec
    field :accepted_at, :utc_datetime_usec
    field :invited_by_id, :binary_id

    belongs_to :user, User
    belongs_to :organization, Organization

    timestamps(type: :utc_datetime_usec)
  end

  def valid_roles, do: @valid_roles
  def valid_statuses, do: @valid_statuses

  @doc """
  Builds a changeset for creating a direct membership (no invitation flow).
  """
  def create_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :status, :user_id, :organization_id, :invited_by_id])
    |> validate_required([:role, :user_id, :organization_id])
    |> validate_inclusion(:role, @valid_roles)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:organization_id)
    |> unique_constraint([:user_id, :organization_id])
  end

  @doc """
  Builds a changeset for inviting a user to an organization.
  Sets status to "invited" and records invited_at timestamp.
  """
  def invite_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :user_id, :organization_id, :invited_by_id])
    |> validate_required([:role, :user_id, :organization_id])
    |> validate_inclusion(:role, @valid_roles)
    |> put_change(:status, "invited")
    |> put_change(:invited_at, DateTime.utc_now() |> DateTime.truncate(:microsecond))
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:organization_id)
    |> unique_constraint([:user_id, :organization_id])
  end

  @doc """
  Builds a changeset for accepting an invitation.
  Sets status to "active" and records accepted_at timestamp.
  """
  def accept_changeset(membership) do
    membership
    |> change()
    |> put_change(:status, "active")
    |> put_change(:accepted_at, DateTime.utc_now() |> DateTime.truncate(:microsecond))
  end

  @doc """
  Builds a changeset for changing a member's role.
  """
  def role_changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_inclusion(:role, @valid_roles)
  end
end

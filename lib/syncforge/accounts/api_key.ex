defmodule Syncforge.Accounts.ApiKey do
  @moduledoc """
  Represents an API key for authenticating SDK and API requests.

  API keys use the same security pattern as user tokens:
  raw key is sent to the user, SHA-256 hash is stored in the database.
  The key_prefix (first 12 chars) allows identification without exposing the key.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Syncforge.Accounts.Organization

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_types ~w(publishable secret)
  @valid_statuses ~w(active revoked)

  schema "api_keys" do
    field :label, :string
    field :key_prefix, :string
    field :key_hash, :string
    field :type, :string, default: "publishable"
    field :status, :string, default: "active"
    field :scopes, {:array, :string}, default: ["read", "write"]
    field :rate_limit, :integer, default: 1000
    field :expires_at, :utc_datetime_usec
    field :allowed_origins, {:array, :string}, default: []
    field :created_by_id, :binary_id

    belongs_to :organization, Organization

    timestamps(type: :utc_datetime_usec)
  end

  def valid_types, do: @valid_types
  def valid_statuses, do: @valid_statuses

  @doc """
  Generates a new API key with the appropriate prefix.

  Returns `{raw_key, key_prefix, key_hash}`.
  The raw_key is sent to the user once and never stored.
  """
  def generate_key(type) when type in ["publishable", "secret"] do
    prefix_str = if type == "publishable", do: "sf_pub_", else: "sf_sec_"
    random = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    raw_key = prefix_str <> random
    key_prefix = String.slice(raw_key, 0, 12)
    key_hash = :crypto.hash(:sha256, raw_key) |> Base.encode64()
    {raw_key, key_prefix, key_hash}
  end

  @doc """
  Builds a changeset for creating a new API key.
  """
  def create_changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [
      :label,
      :key_prefix,
      :key_hash,
      :type,
      :status,
      :scopes,
      :rate_limit,
      :expires_at,
      :allowed_origins,
      :created_by_id,
      :organization_id
    ])
    |> validate_required([:label, :key_prefix, :key_hash, :organization_id])
    |> validate_inclusion(:type, @valid_types)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:rate_limit, greater_than: 0)
    |> foreign_key_constraint(:organization_id)
    |> unique_constraint(:key_hash)
  end

  @doc """
  Builds a changeset for revoking an API key.
  """
  def revoke_changeset(api_key) do
    api_key
    |> change()
    |> put_change(:status, "revoked")
  end
end

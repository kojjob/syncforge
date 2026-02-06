defmodule Syncforge.Organizations do
  @moduledoc """
  Context for managing organizations, memberships, and API keys.

  Organizations are the multi-tenancy unit in SyncForge. Each organization
  has members (with roles) and API keys for SDK/API authentication.
  """

  import Ecto.Query

  alias Syncforge.Repo
  alias Syncforge.Accounts.{Organization, Membership, ApiKey}

  # --- Organization CRUD ---

  @doc """
  Creates an organization and an owner membership for the given user
  within a single database transaction.

  Returns `{:ok, organization, membership}` or `{:error, step, changeset, changes}`.
  """
  def create_organization(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(
      :organization,
      Organization.create_changeset(%Organization{}, attrs)
    )
    |> Ecto.Multi.insert(:membership, fn %{organization: org} ->
      Membership.create_changeset(%Membership{}, %{
        user_id: user.id,
        organization_id: org.id,
        role: "owner"
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{organization: org, membership: membership}} ->
        {:ok, org, membership}

      {:error, step, changeset, changes} ->
        {:error, step, changeset, changes}
    end
  end

  @doc """
  Gets an organization by ID. Returns nil if not found.
  """
  def get_organization(id), do: Repo.get(Organization, id)

  @doc """
  Gets an organization by ID. Raises if not found.
  """
  def get_organization!(id), do: Repo.get!(Organization, id)

  @doc """
  Gets an organization by slug. Returns nil if not found.
  """
  def get_organization_by_slug(slug) do
    Repo.get_by(Organization, slug: slug)
  end

  @doc """
  Updates an organization.
  """
  def update_organization(org, attrs) do
    org
    |> Organization.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an organization. Cascades to memberships and API keys.
  Rooms have their organization_id set to nil.
  """
  def delete_organization(org) do
    Repo.delete(org)
  end

  # --- User Organizations ---

  @doc """
  Lists organizations for a user (only active memberships).
  """
  def list_user_organizations(user_id) do
    Organization
    |> join(:inner, [o], m in Membership, on: m.organization_id == o.id)
    |> where([_o, m], m.user_id == ^user_id and m.status == "active")
    |> Repo.all()
  end

  # --- Membership Management ---

  @doc """
  Adds a member to an organization with the given role.
  """
  def add_member(org, user_id, role) do
    %Membership{}
    |> Membership.create_changeset(%{
      user_id: user_id,
      organization_id: org.id,
      role: role
    })
    |> Repo.insert()
  end

  @doc """
  Removes a member from an organization.
  Returns `{:error, :last_owner}` if the member is the last owner.
  Returns `{:error, :not_found}` if the membership doesn't exist.
  """
  def remove_member(org, user_id) do
    case get_membership(org.id, user_id) do
      nil ->
        {:error, :not_found}

      membership ->
        if membership.role == "owner" and count_owners(org.id) <= 1 do
          {:error, :last_owner}
        else
          Repo.delete(membership)
        end
    end
  end

  @doc """
  Updates a member's role.
  Returns `{:error, :last_owner}` if demoting the last owner.
  """
  def update_member_role(org, user_id, new_role) do
    case get_membership(org.id, user_id) do
      nil ->
        {:error, :not_found}

      membership ->
        if membership.role == "owner" and new_role != "owner" and count_owners(org.id) <= 1 do
          {:error, :last_owner}
        else
          membership
          |> Membership.role_changeset(%{role: new_role})
          |> Repo.update()
        end
    end
  end

  @doc """
  Gets a membership by organization and user ID.
  """
  def get_membership(org_id, user_id) do
    Repo.get_by(Membership, organization_id: org_id, user_id: user_id)
  end

  @doc """
  Checks if a user has one of the given roles in an organization.
  """
  def user_has_role?(org_id, user_id, roles) when is_list(roles) do
    Membership
    |> where([m], m.organization_id == ^org_id and m.user_id == ^user_id)
    |> where([m], m.role in ^roles and m.status == "active")
    |> Repo.exists?()
  end

  # --- API Key Management ---

  @doc """
  Creates an API key for the organization.
  Returns `{:ok, api_key, raw_key}`.
  """
  def create_api_key(org, attrs) do
    type = Map.get(attrs, :type, "publishable") |> to_string()
    {raw_key, prefix, hash} = ApiKey.generate_key(type)

    result =
      %ApiKey{}
      |> ApiKey.create_changeset(
        attrs
        |> Map.put(:key_prefix, prefix)
        |> Map.put(:key_hash, hash)
        |> Map.put(:organization_id, org.id)
      )
      |> Repo.insert()

    case result do
      {:ok, api_key} -> {:ok, api_key, raw_key}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Revokes an API key.
  """
  def revoke_api_key(api_key) do
    api_key
    |> ApiKey.revoke_changeset()
    |> Repo.update()
  end

  @doc """
  Lists API keys for an organization. By default only active keys.
  Pass `include_revoked: true` to include revoked keys.
  """
  def list_api_keys(org_id, opts \\ []) do
    query =
      from(k in ApiKey, where: k.organization_id == ^org_id, order_by: [desc: k.inserted_at])

    query =
      if Keyword.get(opts, :include_revoked, false) do
        query
      else
        where(query, [k], k.status == "active")
      end

    Repo.all(query)
  end

  @doc """
  Gets an API key by ID, scoped to a specific organization.
  Returns nil if not found or doesn't belong to the org.
  """
  def get_api_key_for_org(org_id, key_id) do
    ApiKey
    |> where([k], k.id == ^key_id and k.organization_id == ^org_id)
    |> Repo.one()
  end

  # --- Dashboard Helpers ---

  @doc """
  Counts active members in an organization.
  """
  def count_members(org_id) do
    Membership
    |> where([m], m.organization_id == ^org_id and m.status == "active")
    |> Repo.aggregate(:count)
  end

  @doc """
  Lists active members in an organization with their user preloaded.
  """
  def list_members(org_id) do
    Membership
    |> where([m], m.organization_id == ^org_id and m.status == "active")
    |> preload(:user)
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end

  @doc """
  Counts active API keys for an organization.
  """
  def count_api_keys(org_id) do
    ApiKey
    |> where([k], k.organization_id == ^org_id and k.status == "active")
    |> Repo.aggregate(:count)
  end

  # --- Private Helpers ---

  defp count_owners(org_id) do
    Membership
    |> where([m], m.organization_id == ^org_id and m.role == "owner" and m.status == "active")
    |> Repo.aggregate(:count)
  end
end

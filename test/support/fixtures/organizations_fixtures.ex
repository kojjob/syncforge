defmodule Syncforge.OrganizationsFixtures do
  @moduledoc """
  Test helpers for creating Organizations entities.
  """

  alias Syncforge.AccountsFixtures

  def unique_org_name, do: "org-#{System.unique_integer([:positive])}"

  def valid_organization_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: unique_org_name()
    })
  end

  @doc """
  Creates an organization with an owner membership.
  If no user is provided, creates one.
  Returns `{org, owner}`.
  """
  def organization_fixture(user \\ nil, attrs \\ %{}) do
    owner = user || AccountsFixtures.user_fixture()

    {:ok, org, _membership} =
      Syncforge.Organizations.create_organization(
        owner,
        valid_organization_attributes(attrs)
      )

    {org, owner}
  end

  @doc """
  Creates a membership for an existing org and user.
  """
  def membership_fixture(org, user, attrs \\ %{}) do
    {:ok, membership} =
      Syncforge.Organizations.add_member(
        org,
        user.id,
        Map.get(attrs, :role, "member")
      )

    membership
  end

  @doc """
  Creates an API key for an existing organization.
  Returns `{api_key, raw_key}`.
  """
  def api_key_fixture(org, attrs \\ %{}) do
    {:ok, api_key, raw_key} =
      Syncforge.Organizations.create_api_key(
        org,
        Enum.into(attrs, %{label: "test-key-#{System.unique_integer([:positive])}"})
      )

    {api_key, raw_key}
  end
end

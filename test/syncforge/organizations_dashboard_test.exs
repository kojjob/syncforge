defmodule Syncforge.OrganizationsDashboardTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Organizations

  import Syncforge.AccountsFixtures

  describe "count_members/1" do
    test "returns count of active members in an organization" do
      owner = user_fixture()
      member = user_fixture()

      {:ok, org, _membership} =
        Organizations.create_organization(owner, %{name: "Count Test Org"})

      {:ok, _} = Organizations.add_member(org, member.id, "member")

      assert Organizations.count_members(org.id) == 2
    end

    test "does not count invited members" do
      owner = user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Invited Test"})

      # Add an invited member manually
      invited = user_fixture()

      %Syncforge.Accounts.Membership{}
      |> Syncforge.Accounts.Membership.invite_changeset(%{
        user_id: invited.id,
        organization_id: org.id,
        role: "member"
      })
      |> Syncforge.Repo.insert!()

      # Only the owner (active) should be counted
      assert Organizations.count_members(org.id) == 1
    end

    test "returns 0 for org with no members" do
      # Use a random UUID that doesn't exist
      assert Organizations.count_members(Ecto.UUID.generate()) == 0
    end
  end

  describe "list_members/1" do
    test "returns active members with user preloaded" do
      owner = user_fixture(%{name: "Org Owner"})
      member = user_fixture(%{name: "Org Member"})

      {:ok, org, _} = Organizations.create_organization(owner, %{name: "List Test Org"})
      {:ok, _} = Organizations.add_member(org, member.id, "member")

      members = Organizations.list_members(org.id)

      assert length(members) == 2
      names = Enum.map(members, & &1.user.name) |> Enum.sort()
      assert names == ["Org Member", "Org Owner"]
    end

    test "returns empty list for nonexistent org" do
      assert Organizations.list_members(Ecto.UUID.generate()) == []
    end
  end

  describe "count_api_keys/1" do
    test "counts active API keys for an organization" do
      owner = user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Key Count Org"})

      {:ok, _key1, _raw1} =
        Organizations.create_api_key(org, %{label: "Key 1", type: "publishable"})

      {:ok, _key2, _raw2} =
        Organizations.create_api_key(org, %{label: "Key 2", type: "secret"})

      assert Organizations.count_api_keys(org.id) == 2
    end

    test "does not count revoked keys" do
      owner = user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Revoked Key Org"})

      {:ok, key, _raw} =
        Organizations.create_api_key(org, %{label: "Temp Key", type: "publishable"})

      {:ok, _} = Organizations.revoke_api_key(key)

      assert Organizations.count_api_keys(org.id) == 0
    end
  end
end

defmodule Syncforge.OrganizationsTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Organizations
  alias Syncforge.Accounts.{Membership, ApiKey}
  alias Syncforge.AccountsFixtures

  describe "create_organization/2" do
    test "creates organization and owner membership in a transaction" do
      user = AccountsFixtures.user_fixture()
      {:ok, org, membership} = Organizations.create_organization(user, %{name: "Acme Corp"})

      assert org.name == "Acme Corp"
      assert org.slug == "acme-corp"
      assert org.plan_type == "free"
      assert membership.user_id == user.id
      assert membership.organization_id == org.id
      assert membership.role == "owner"
      assert membership.status == "active"
    end

    test "returns error for invalid attrs" do
      user = AccountsFixtures.user_fixture()
      {:error, :organization, changeset, _} = Organizations.create_organization(user, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "enforces unique slug" do
      user = AccountsFixtures.user_fixture()
      {:ok, _org, _} = Organizations.create_organization(user, %{name: "Acme Corp"})

      {:error, :organization, changeset, _} =
        Organizations.create_organization(user, %{name: "Acme Corp"})

      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_organization/1" do
    test "returns organization by id" do
      user = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(user, %{name: "Test Org"})

      found = Organizations.get_organization(org.id)
      assert found.id == org.id
    end

    test "returns nil for non-existent id" do
      assert Organizations.get_organization(Ecto.UUID.generate()) == nil
    end
  end

  describe "get_organization!/1" do
    test "returns organization by id" do
      user = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(user, %{name: "Test Org"})

      found = Organizations.get_organization!(org.id)
      assert found.id == org.id
    end

    test "raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Organizations.get_organization!(Ecto.UUID.generate())
      end
    end
  end

  describe "get_organization_by_slug/1" do
    test "returns organization by slug" do
      user = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(user, %{name: "Slug Test"})

      found = Organizations.get_organization_by_slug(org.slug)
      assert found.id == org.id
    end

    test "returns nil for non-existent slug" do
      assert Organizations.get_organization_by_slug("nonexistent") == nil
    end
  end

  describe "update_organization/2" do
    test "updates the organization" do
      user = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(user, %{name: "Old Name"})

      {:ok, updated} = Organizations.update_organization(org, %{name: "New Name"})
      assert updated.name == "New Name"
      # slug should NOT change automatically
      assert updated.slug == org.slug
    end

    test "returns error for invalid attrs" do
      user = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(user, %{name: "Test Org"})

      {:error, changeset} = Organizations.update_organization(org, %{name: nil})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "delete_organization/1" do
    test "deletes the organization" do
      user = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(user, %{name: "To Delete"})

      {:ok, _deleted} = Organizations.delete_organization(org)
      assert Organizations.get_organization(org.id) == nil
    end

    test "cascades deletion to memberships" do
      user = AccountsFixtures.user_fixture()
      {:ok, org, membership} = Organizations.create_organization(user, %{name: "Cascade Test"})

      {:ok, _} = Organizations.delete_organization(org)
      assert Repo.get(Membership, membership.id) == nil
    end

    test "cascades deletion to api keys" do
      user = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(user, %{name: "Cascade Keys"})
      {:ok, api_key, _raw} = Organizations.create_api_key(org, %{label: "Test Key"})

      {:ok, _} = Organizations.delete_organization(org)
      assert Repo.get(ApiKey, api_key.id) == nil
    end

    test "nilifies organization_id on rooms" do
      user = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(user, %{name: "Room Nilify"})

      # Create a room linked to this org
      {:ok, room} =
        %Syncforge.Rooms.Room{}
        |> Syncforge.Rooms.Room.create_changeset(%{
          name: "Test Room",
          organization_id: org.id
        })
        |> Repo.insert()

      {:ok, _} = Organizations.delete_organization(org)
      room = Repo.get(Syncforge.Rooms.Room, room.id)
      assert room != nil
      assert room.organization_id == nil
    end
  end

  describe "list_user_organizations/1" do
    test "returns organizations for user with active memberships" do
      user = AccountsFixtures.user_fixture()
      {:ok, org1, _} = Organizations.create_organization(user, %{name: "Org One"})
      {:ok, org2, _} = Organizations.create_organization(user, %{name: "Org Two"})

      orgs = Organizations.list_user_organizations(user.id)
      org_ids = Enum.map(orgs, & &1.id)
      assert org1.id in org_ids
      assert org2.id in org_ids
    end

    test "excludes organizations with non-active memberships" do
      user = AccountsFixtures.user_fixture()
      {:ok, org, membership} = Organizations.create_organization(user, %{name: "Suspended Org"})

      # Manually suspend the membership
      membership |> Ecto.Changeset.change(%{status: "suspended"}) |> Repo.update!()

      orgs = Organizations.list_user_organizations(user.id)
      org_ids = Enum.map(orgs, & &1.id)
      refute org.id in org_ids
    end

    test "returns empty list for user with no organizations" do
      user = AccountsFixtures.user_fixture()
      assert Organizations.list_user_organizations(user.id) == []
    end
  end

  describe "add_member/3" do
    test "adds a member to an organization" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Team Org"})
      new_member = AccountsFixtures.user_fixture()

      {:ok, membership} = Organizations.add_member(org, new_member.id, "member")
      assert membership.user_id == new_member.id
      assert membership.organization_id == org.id
      assert membership.role == "member"
    end

    test "prevents duplicate membership" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Dupe Test"})
      member = AccountsFixtures.user_fixture()

      {:ok, _} = Organizations.add_member(org, member.id, "member")
      {:error, changeset} = Organizations.add_member(org, member.id, "viewer")
      assert %{user_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "remove_member/2" do
    test "removes a member from an organization" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Remove Test"})
      member = AccountsFixtures.user_fixture()
      {:ok, _} = Organizations.add_member(org, member.id, "member")

      {:ok, _} = Organizations.remove_member(org, member.id)
      assert Organizations.get_membership(org.id, member.id) == nil
    end

    test "returns error when member not found" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Not Found"})

      assert {:error, :not_found} = Organizations.remove_member(org, Ecto.UUID.generate())
    end

    test "prevents removing the last owner" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Last Owner"})

      assert {:error, :last_owner} = Organizations.remove_member(org, owner.id)
    end

    test "allows removing an owner if another owner exists" do
      owner1 = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner1, %{name: "Two Owners"})
      owner2 = AccountsFixtures.user_fixture()
      {:ok, _} = Organizations.add_member(org, owner2.id, "owner")

      {:ok, _} = Organizations.remove_member(org, owner1.id)
      assert Organizations.get_membership(org.id, owner1.id) == nil
    end
  end

  describe "update_member_role/3" do
    test "updates a member's role" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Role Update"})
      member = AccountsFixtures.user_fixture()
      {:ok, _} = Organizations.add_member(org, member.id, "member")

      {:ok, updated} = Organizations.update_member_role(org, member.id, "admin")
      assert updated.role == "admin"
    end

    test "prevents demoting the last owner" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Last Owner Demote"})

      assert {:error, :last_owner} = Organizations.update_member_role(org, owner.id, "admin")
    end

    test "allows demoting an owner if another owner exists" do
      owner1 = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner1, %{name: "Demote OK"})
      owner2 = AccountsFixtures.user_fixture()
      {:ok, _} = Organizations.add_member(org, owner2.id, "owner")

      {:ok, updated} = Organizations.update_member_role(org, owner1.id, "admin")
      assert updated.role == "admin"
    end
  end

  describe "get_membership/2" do
    test "returns membership" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, membership} = Organizations.create_organization(owner, %{name: "Get Member"})

      found = Organizations.get_membership(org.id, owner.id)
      assert found.id == membership.id
    end

    test "returns nil when not found" do
      assert Organizations.get_membership(Ecto.UUID.generate(), Ecto.UUID.generate()) == nil
    end
  end

  describe "user_has_role?/3" do
    test "returns true when user has matching role" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Role Check"})

      assert Organizations.user_has_role?(org.id, owner.id, ["owner"])
      assert Organizations.user_has_role?(org.id, owner.id, ["owner", "admin"])
    end

    test "returns false when user does not have matching role" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "No Role"})

      refute Organizations.user_has_role?(org.id, owner.id, ["member", "viewer"])
    end

    test "returns false for non-member" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Non Member"})
      outsider = AccountsFixtures.user_fixture()

      refute Organizations.user_has_role?(org.id, outsider.id, ["owner", "admin", "member"])
    end
  end

  describe "create_api_key/2" do
    test "creates an api key and returns the raw key" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Key Org"})

      {:ok, api_key, raw_key} = Organizations.create_api_key(org, %{label: "My Key"})
      assert api_key.label == "My Key"
      assert api_key.organization_id == org.id
      assert api_key.status == "active"
      assert String.starts_with?(raw_key, "sf_pub_")
      # Verify hash matches
      expected_hash = :crypto.hash(:sha256, raw_key) |> Base.encode64()
      assert api_key.key_hash == expected_hash
    end

    test "allows specifying key type" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Secret Key Org"})

      {:ok, api_key, raw_key} =
        Organizations.create_api_key(org, %{label: "Secret", type: "secret"})

      assert api_key.type == "secret"
      assert String.starts_with?(raw_key, "sf_sec_")
    end
  end

  describe "revoke_api_key/1" do
    test "revokes an api key" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "Revoke Org"})
      {:ok, api_key, _raw} = Organizations.create_api_key(org, %{label: "To Revoke"})

      {:ok, revoked} = Organizations.revoke_api_key(api_key)
      assert revoked.status == "revoked"
    end
  end

  describe "list_api_keys/1" do
    test "returns only active api keys by default" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "List Keys"})
      {:ok, active_key, _} = Organizations.create_api_key(org, %{label: "Active"})
      {:ok, to_revoke, _} = Organizations.create_api_key(org, %{label: "To Revoke"})
      {:ok, _revoked} = Organizations.revoke_api_key(to_revoke)

      keys = Organizations.list_api_keys(org.id)
      key_ids = Enum.map(keys, & &1.id)
      assert active_key.id in key_ids
      refute to_revoke.id in key_ids
    end

    test "returns all api keys when include_revoked is true" do
      owner = AccountsFixtures.user_fixture()
      {:ok, org, _} = Organizations.create_organization(owner, %{name: "All Keys"})
      {:ok, _, _} = Organizations.create_api_key(org, %{label: "Key 1"})
      {:ok, to_revoke, _} = Organizations.create_api_key(org, %{label: "Key 2"})
      {:ok, _} = Organizations.revoke_api_key(to_revoke)

      keys = Organizations.list_api_keys(org.id, include_revoked: true)
      assert length(keys) == 2
    end
  end
end

defmodule Syncforge.Accounts.MembershipTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Accounts.{Membership, Organization}
  alias Syncforge.AccountsFixtures

  setup do
    user = AccountsFixtures.user_fixture()

    {:ok, org} =
      %Organization{}
      |> Organization.create_changeset(%{name: "Test Org"})
      |> Repo.insert()

    %{user: user, org: org}
  end

  describe "create_changeset/2" do
    test "valid attributes produce a valid changeset", %{user: user, org: org} do
      attrs = %{user_id: user.id, organization_id: org.id, role: "member"}
      changeset = Membership.create_changeset(%Membership{}, attrs)
      assert changeset.valid?
    end

    test "requires user_id" do
      changeset = Membership.create_changeset(%Membership{}, %{role: "member"})
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires organization_id", %{user: user} do
      changeset = Membership.create_changeset(%Membership{}, %{user_id: user.id, role: "member"})
      assert %{organization_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires role", %{user: user, org: org} do
      changeset =
        Membership.create_changeset(%Membership{}, %{
          user_id: user.id,
          organization_id: org.id,
          role: nil
        })

      assert %{role: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates role inclusion", %{user: user, org: org} do
      changeset =
        Membership.create_changeset(%Membership{}, %{
          user_id: user.id,
          organization_id: org.id,
          role: "superadmin"
        })

      assert %{role: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts valid roles", %{user: user, org: org} do
      for role <- ~w(owner admin member viewer) do
        changeset =
          Membership.create_changeset(%Membership{}, %{
            user_id: user.id,
            organization_id: org.id,
            role: role
          })

        assert changeset.valid?, "expected role #{role} to be valid"
      end
    end

    test "validates status inclusion", %{user: user, org: org} do
      changeset =
        Membership.create_changeset(%Membership{}, %{
          user_id: user.id,
          organization_id: org.id,
          role: "member",
          status: "banned"
        })

      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "enforces unique user per organization", %{user: user, org: org} do
      attrs = %{user_id: user.id, organization_id: org.id, role: "member"}
      {:ok, _} = %Membership{} |> Membership.create_changeset(attrs) |> Repo.insert()

      {:error, changeset} =
        %Membership{} |> Membership.create_changeset(attrs) |> Repo.insert()

      assert %{user_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "invite_changeset/2" do
    test "sets status to invited and invited_at", %{user: user, org: org} do
      inviter = AccountsFixtures.user_fixture()

      attrs = %{
        user_id: user.id,
        organization_id: org.id,
        role: "member",
        invited_by_id: inviter.id
      }

      changeset = Membership.invite_changeset(%Membership{}, attrs)
      assert changeset.valid?
      assert get_change(changeset, :status) == "invited"
      assert get_change(changeset, :invited_at)
    end
  end

  describe "accept_changeset/1" do
    test "sets status to active and accepted_at", %{user: user, org: org} do
      {:ok, membership} =
        %Membership{}
        |> Membership.invite_changeset(%{
          user_id: user.id,
          organization_id: org.id,
          role: "member"
        })
        |> Repo.insert()

      changeset = Membership.accept_changeset(membership)
      assert changeset.valid?
      assert get_change(changeset, :status) == "active"
      assert get_change(changeset, :accepted_at)
    end
  end

  describe "role_changeset/2" do
    test "allows changing role", %{user: user, org: org} do
      {:ok, membership} =
        %Membership{}
        |> Membership.create_changeset(%{
          user_id: user.id,
          organization_id: org.id,
          role: "member"
        })
        |> Repo.insert()

      changeset = Membership.role_changeset(membership, %{role: "admin"})
      assert changeset.valid?
      assert get_change(changeset, :role) == "admin"
    end

    test "validates role inclusion on role change", %{user: user, org: org} do
      {:ok, membership} =
        %Membership{}
        |> Membership.create_changeset(%{
          user_id: user.id,
          organization_id: org.id,
          role: "member"
        })
        |> Repo.insert()

      changeset = Membership.role_changeset(membership, %{role: "dictator"})
      assert %{role: ["is invalid"]} = errors_on(changeset)
    end
  end
end

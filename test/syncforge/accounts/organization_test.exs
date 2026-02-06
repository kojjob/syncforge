defmodule Syncforge.Accounts.OrganizationTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Accounts.Organization

  describe "create_changeset/2" do
    test "valid attributes produce a valid changeset" do
      attrs = %{name: "Acme Corp"}
      changeset = Organization.create_changeset(%Organization{}, attrs)
      assert changeset.valid?
    end

    test "requires name" do
      changeset = Organization.create_changeset(%Organization{}, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "auto-generates slug from name" do
      attrs = %{name: "My Awesome Org"}
      changeset = Organization.create_changeset(%Organization{}, attrs)
      assert get_change(changeset, :slug) == "my-awesome-org"
    end

    test "uses provided slug instead of generating" do
      attrs = %{name: "Acme Corp", slug: "custom-slug"}
      changeset = Organization.create_changeset(%Organization{}, attrs)
      assert get_change(changeset, :slug) == "custom-slug"
    end

    test "validates slug format" do
      attrs = %{name: "Acme Corp", slug: "INVALID SLUG!"}
      changeset = Organization.create_changeset(%Organization{}, attrs)

      assert %{slug: ["must be URL-safe (letters, numbers, hyphens, underscores)"]} =
               errors_on(changeset)
    end

    test "validates plan_type inclusion" do
      attrs = %{name: "Acme Corp", plan_type: "ultra"}
      changeset = Organization.create_changeset(%Organization{}, attrs)
      assert %{plan_type: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts valid plan types" do
      for plan_type <- ~w(free starter pro business enterprise) do
        attrs = %{name: "Acme Corp", plan_type: plan_type}
        changeset = Organization.create_changeset(%Organization{}, attrs)
        assert changeset.valid?, "expected #{plan_type} to be valid"
      end
    end

    test "defaults plan_type to free" do
      attrs = %{name: "Acme Corp"}
      changeset = Organization.create_changeset(%Organization{}, attrs)
      # Default is set at schema level, not changeset level
      org = Ecto.Changeset.apply_changes(changeset)
      assert org.plan_type == "free"
    end

    test "defaults max_rooms to 3" do
      attrs = %{name: "Acme Corp"}
      changeset = Organization.create_changeset(%Organization{}, attrs)
      org = Ecto.Changeset.apply_changes(changeset)
      assert org.max_rooms == 3
    end

    test "defaults settings to empty map" do
      attrs = %{name: "Acme Corp"}
      changeset = Organization.create_changeset(%Organization{}, attrs)
      org = Ecto.Changeset.apply_changes(changeset)
      assert org.settings == %{}
    end

    test "slug uniqueness is enforced at the database level" do
      attrs = %{name: "Acme Corp", slug: "acme-corp"}
      {:ok, _org} = %Organization{} |> Organization.create_changeset(attrs) |> Repo.insert()

      {:error, changeset} =
        %Organization{} |> Organization.create_changeset(attrs) |> Repo.insert()

      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "validates name length" do
      attrs = %{name: String.duplicate("a", 256)}
      changeset = Organization.create_changeset(%Organization{}, attrs)
      assert %{name: ["should be at most 255 character(s)"]} = errors_on(changeset)
    end

    test "slugifies special characters properly" do
      attrs = %{name: "Héllo Wörld! @#$%"}
      changeset = Organization.create_changeset(%Organization{}, attrs)
      slug = get_change(changeset, :slug)
      assert slug =~ ~r/^[a-z0-9_-]+$/
    end
  end

  describe "update_changeset/2" do
    setup do
      {:ok, org} =
        %Organization{}
        |> Organization.create_changeset(%{name: "Original Name"})
        |> Repo.insert()

      %{org: org}
    end

    test "allows updating name", %{org: org} do
      changeset = Organization.update_changeset(org, %{name: "New Name"})
      assert changeset.valid?
      assert get_change(changeset, :name) == "New Name"
    end

    test "requires name", %{org: org} do
      changeset = Organization.update_changeset(org, %{name: nil})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "does not auto-generate slug on update", %{org: org} do
      original_slug = org.slug
      changeset = Organization.update_changeset(org, %{name: "Totally Different Name"})
      assert changeset.valid?
      # Slug should not change unless explicitly provided
      refute get_change(changeset, :slug)
      org_updated = Ecto.Changeset.apply_changes(changeset)
      assert org_updated.slug == original_slug
    end

    test "allows explicit slug update", %{org: org} do
      changeset = Organization.update_changeset(org, %{slug: "new-slug"})
      assert changeset.valid?
      assert get_change(changeset, :slug) == "new-slug"
    end

    test "allows updating plan_type and limits", %{org: org} do
      changeset =
        Organization.update_changeset(org, %{
          plan_type: "pro",
          max_rooms: 100,
          max_monthly_connections: 10_000
        })

      assert changeset.valid?
    end
  end
end

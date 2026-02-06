defmodule Syncforge.Accounts.ApiKeyTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Accounts.{ApiKey, Organization}

  setup do
    {:ok, org} =
      %Organization{}
      |> Organization.create_changeset(%{name: "Test Org"})
      |> Repo.insert()

    %{org: org}
  end

  describe "create_changeset/2" do
    test "valid attributes produce a valid changeset", %{org: org} do
      {_raw_key, prefix, hash} = ApiKey.generate_key("publishable")

      attrs = %{
        label: "Production Key",
        key_prefix: prefix,
        key_hash: hash,
        organization_id: org.id
      }

      changeset = ApiKey.create_changeset(%ApiKey{}, attrs)
      assert changeset.valid?
    end

    test "requires label", %{org: org} do
      {_raw, prefix, hash} = ApiKey.generate_key("publishable")

      changeset =
        ApiKey.create_changeset(%ApiKey{}, %{
          key_prefix: prefix,
          key_hash: hash,
          organization_id: org.id
        })

      assert %{label: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires organization_id" do
      {_raw, prefix, hash} = ApiKey.generate_key("publishable")

      changeset =
        ApiKey.create_changeset(%ApiKey{}, %{
          label: "Test Key",
          key_prefix: prefix,
          key_hash: hash
        })

      assert %{organization_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates type inclusion", %{org: org} do
      {_raw, prefix, hash} = ApiKey.generate_key("publishable")

      changeset =
        ApiKey.create_changeset(%ApiKey{}, %{
          label: "Test Key",
          key_prefix: prefix,
          key_hash: hash,
          organization_id: org.id,
          type: "admin"
        })

      assert %{type: ["is invalid"]} = errors_on(changeset)
    end

    test "validates status inclusion", %{org: org} do
      {_raw, prefix, hash} = ApiKey.generate_key("publishable")

      changeset =
        ApiKey.create_changeset(%ApiKey{}, %{
          label: "Test Key",
          key_prefix: prefix,
          key_hash: hash,
          organization_id: org.id,
          status: "deleted"
        })

      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "defaults type to publishable" do
      key = %ApiKey{}
      assert key.type == "publishable"
    end

    test "defaults status to active" do
      key = %ApiKey{}
      assert key.status == "active"
    end

    test "enforces key_hash uniqueness", %{org: org} do
      {_raw, prefix, hash} = ApiKey.generate_key("publishable")

      attrs = %{
        label: "Key 1",
        key_prefix: prefix,
        key_hash: hash,
        organization_id: org.id
      }

      {:ok, _} = %ApiKey{} |> ApiKey.create_changeset(attrs) |> Repo.insert()

      {:error, changeset} =
        %ApiKey{}
        |> ApiKey.create_changeset(%{attrs | label: "Key 2"})
        |> Repo.insert()

      assert %{key_hash: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "generate_key/1" do
    test "publishable key has sf_pub_ prefix" do
      {raw_key, prefix, _hash} = ApiKey.generate_key("publishable")
      assert String.starts_with?(raw_key, "sf_pub_")
      assert String.starts_with?(prefix, "sf_pub_")
    end

    test "secret key has sf_sec_ prefix" do
      {raw_key, prefix, _hash} = ApiKey.generate_key("secret")
      assert String.starts_with?(raw_key, "sf_sec_")
      assert String.starts_with?(prefix, "sf_sec_")
    end

    test "prefix is first 12 characters of raw key" do
      {raw_key, prefix, _hash} = ApiKey.generate_key("publishable")
      assert prefix == String.slice(raw_key, 0, 12)
    end

    test "hash is not the raw key" do
      {raw_key, _prefix, hash} = ApiKey.generate_key("publishable")
      refute raw_key == hash
    end

    test "generates unique keys each time" do
      {raw1, _, _} = ApiKey.generate_key("publishable")
      {raw2, _, _} = ApiKey.generate_key("publishable")
      refute raw1 == raw2
    end
  end

  describe "revoke_changeset/1" do
    test "sets status to revoked", %{org: org} do
      {_raw, prefix, hash} = ApiKey.generate_key("publishable")

      {:ok, api_key} =
        %ApiKey{}
        |> ApiKey.create_changeset(%{
          label: "To Revoke",
          key_prefix: prefix,
          key_hash: hash,
          organization_id: org.id
        })
        |> Repo.insert()

      changeset = ApiKey.revoke_changeset(api_key)
      assert changeset.valid?
      assert get_change(changeset, :status) == "revoked"
    end
  end
end

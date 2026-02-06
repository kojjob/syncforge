defmodule Syncforge.Organizations.ApiKeyRotationTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Organizations
  alias Syncforge.Accounts.ApiKey

  setup do
    user = Syncforge.AccountsFixtures.user_fixture()
    {:ok, org, _membership} = Organizations.create_organization(user, %{name: "RotationOrg"})
    {:ok, api_key, raw_key} = Organizations.create_api_key(org, %{label: "Original Key"})
    %{user: user, org: org, api_key: api_key, raw_key: raw_key}
  end

  describe "rotate_api_key/2" do
    test "creates a new key and marks old key as rotating", %{org: org, api_key: old_key} do
      assert {:ok, new_key, new_raw_key, rotated_old_key} =
               Organizations.rotate_api_key(org, old_key)

      # New key should be active
      assert new_key.status == "active"
      assert new_key.organization_id == org.id
      assert new_key.label == old_key.label
      assert new_key.type == old_key.type
      assert is_binary(new_raw_key)

      # Old key should be in "rotating" status
      assert rotated_old_key.status == "rotating"
      assert rotated_old_key.rotated_at != nil
      assert rotated_old_key.replaced_by_id == new_key.id
    end

    test "cannot rotate a revoked key", %{org: org, api_key: api_key} do
      {:ok, revoked} = Organizations.revoke_api_key(api_key)

      assert {:error, :key_not_active} = Organizations.rotate_api_key(org, revoked)
    end

    test "cannot rotate a key from a different org", %{api_key: api_key} do
      other_user = Syncforge.AccountsFixtures.user_fixture()
      {:ok, other_org, _} = Organizations.create_organization(other_user, %{name: "OtherOrg"})

      assert {:error, :key_not_found} = Organizations.rotate_api_key(other_org, api_key)
    end

    test "rotating key is still found in active key list during grace period", %{
      org: org,
      api_key: api_key
    } do
      {:ok, _new_key, _raw, _old} = Organizations.rotate_api_key(org, api_key)

      # list_api_keys should return both active and rotating keys
      keys = Organizations.list_api_keys(org.id)
      statuses = Enum.map(keys, & &1.status)
      assert "active" in statuses
      assert "rotating" in statuses
    end
  end

  describe "expire_rotating_keys/1" do
    test "expires rotating keys past the grace period", %{org: org, api_key: api_key} do
      {:ok, _new_key, _raw, rotated_old} = Organizations.rotate_api_key(org, api_key)

      # Manually backdate the rotated_at to simulate grace period expiry
      past_time = DateTime.add(DateTime.utc_now(), -25, :hour)

      Syncforge.Repo.update_all(
        from(k in ApiKey, where: k.id == ^rotated_old.id),
        set: [rotated_at: past_time]
      )

      # Run expiration
      {count, _} = Organizations.expire_rotating_keys(24)
      assert count >= 1

      # Verify the key is now revoked
      expired = Syncforge.Repo.get!(ApiKey, rotated_old.id)
      assert expired.status == "revoked"
    end

    test "does not expire rotating keys within the grace period", %{org: org, api_key: api_key} do
      {:ok, _new_key, _raw, _old} = Organizations.rotate_api_key(org, api_key)

      # Keys just rotated should not be expired
      {count, _} = Organizations.expire_rotating_keys(24)
      assert count == 0
    end
  end
end

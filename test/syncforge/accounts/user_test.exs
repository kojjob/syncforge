defmodule Syncforge.Accounts.UserTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Accounts.User

  @valid_attrs %{
    email: "test@example.com",
    password: "password123",
    name: "Test User"
  }

  describe "registration_changeset/2" do
    test "with valid attrs returns valid changeset" do
      changeset = User.registration_changeset(%User{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires email" do
      changeset = User.registration_changeset(%User{}, Map.delete(@valid_attrs, :email))
      refute changeset.valid?
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires password" do
      changeset = User.registration_changeset(%User{}, Map.delete(@valid_attrs, :password))
      refute changeset.valid?
      assert %{password: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires name" do
      changeset = User.registration_changeset(%User{}, Map.delete(@valid_attrs, :name))
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects invalid email format" do
      changeset = User.registration_changeset(%User{}, %{@valid_attrs | email: "not-an-email"})
      refute changeset.valid?
      assert %{email: ["has invalid format"]} = errors_on(changeset)
    end

    test "rejects short password" do
      changeset = User.registration_changeset(%User{}, %{@valid_attrs | password: "short"})
      refute changeset.valid?
      assert %{password: [msg]} = errors_on(changeset)
      assert msg =~ "at least"
    end

    test "hashes password" do
      changeset = User.registration_changeset(%User{}, @valid_attrs)
      assert changeset.changes[:password_hash]
      assert changeset.changes[:password_hash] != "password123"
    end

    test "downcases email" do
      changeset =
        User.registration_changeset(%User{}, %{@valid_attrs | email: "  TEST@Example.COM  "})

      assert changeset.changes[:email] == "test@example.com"
    end

    test "accepts valid email with avatar_url" do
      attrs = Map.put(@valid_attrs, :avatar_url, "https://example.com/avatar.png")
      changeset = User.registration_changeset(%User{}, attrs)
      assert changeset.valid?
      assert changeset.changes[:avatar_url] == "https://example.com/avatar.png"
    end
  end

  describe "update_changeset/2" do
    test "allows name and avatar_url changes" do
      user = %User{name: "Old Name"}

      changeset =
        User.update_changeset(user, %{name: "New Name", avatar_url: "https://img.com/new.png"})

      assert changeset.valid?
      assert changeset.changes[:name] == "New Name"
      assert changeset.changes[:avatar_url] == "https://img.com/new.png"
    end

    test "requires name" do
      user = %User{name: "Old Name"}
      changeset = User.update_changeset(user, %{name: ""})
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "valid_password?/2" do
    test "returns true for correct password" do
      hash = Bcrypt.hash_pwd_salt("correct_password")
      user = %User{password_hash: hash}
      assert User.valid_password?(user, "correct_password")
    end

    test "returns false for wrong password" do
      hash = Bcrypt.hash_pwd_salt("correct_password")
      user = %User{password_hash: hash}
      refute User.valid_password?(user, "wrong_password")
    end

    test "handles nil hash (timing-safe)" do
      refute User.valid_password?(%User{password_hash: nil}, "any_password")
    end

    test "handles nil user" do
      refute User.valid_password?(nil, "any_password")
    end
  end
end

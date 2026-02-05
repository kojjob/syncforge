defmodule Syncforge.AccountsTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Accounts
  alias Syncforge.Accounts.User

  import Syncforge.AccountsFixtures

  describe "register_user/1" do
    test "with valid data creates user" do
      attrs = valid_user_attributes()
      assert {:ok, %User{} = user} = Accounts.register_user(attrs)
      assert user.email == attrs.email
      assert user.name == attrs.name
      assert user.password == nil
      assert user.password_hash != nil
    end

    test "with missing fields fails" do
      assert {:error, changeset} = Accounts.register_user(%{})
      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "with duplicate email fails" do
      attrs = valid_user_attributes()
      {:ok, _user} = Accounts.register_user(attrs)
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "with invalid email fails" do
      attrs = valid_user_attributes(%{email: "not-valid"})
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert %{email: ["has invalid format"]} = errors_on(changeset)
    end

    test "with short password fails" do
      attrs = valid_user_attributes(%{password: "short"})
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert %{password: [_msg]} = errors_on(changeset)
    end
  end

  describe "get_user/1" do
    test "returns user by ID" do
      user = user_fixture()
      assert %User{} = fetched = Accounts.get_user(user.id)
      assert fetched.id == user.id
    end

    test "returns nil for non-existent ID" do
      assert Accounts.get_user(Ecto.UUID.generate()) == nil
    end
  end

  describe "get_user_by_email/1" do
    test "returns user (case-insensitive)" do
      user = user_fixture(%{email: "Mixed@Example.COM"})
      assert %User{} = fetched = Accounts.get_user_by_email("mixed@example.com")
      assert fetched.id == user.id
    end

    test "returns nil for non-existent email" do
      assert Accounts.get_user_by_email("nope@example.com") == nil
    end
  end

  describe "authenticate_by_email_and_password/2" do
    test "with correct password" do
      user = user_fixture(%{password: "correct_password"})

      assert {:ok, %User{} = authed} =
               Accounts.authenticate_by_email_and_password(user.email, "correct_password")

      assert authed.id == user.id
    end

    test "with wrong password" do
      user = user_fixture(%{password: "correct_password"})

      assert {:error, :invalid_credentials} =
               Accounts.authenticate_by_email_and_password(user.email, "wrong")
    end

    test "with non-existent email" do
      assert {:error, :invalid_credentials} =
               Accounts.authenticate_by_email_and_password("nope@example.com", "any")
    end
  end

  describe "update_user/2" do
    test "updates name and avatar" do
      user = user_fixture()

      assert {:ok, updated} =
               Accounts.update_user(user, %{
                 name: "New Name",
                 avatar_url: "https://img.com/new.png"
               })

      assert updated.name == "New Name"
      assert updated.avatar_url == "https://img.com/new.png"
    end
  end

  describe "update_last_sign_in/1" do
    test "updates timestamp" do
      user = user_fixture()
      assert user.last_sign_in_at == nil
      assert {:ok, updated} = Accounts.update_last_sign_in(user)
      assert updated.last_sign_in_at != nil
    end
  end
end

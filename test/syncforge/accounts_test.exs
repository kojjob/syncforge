defmodule Syncforge.AccountsTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Accounts
  alias Syncforge.Accounts.User

  import Ecto.Changeset, only: [get_change: 2]
  import Syncforge.AccountsFixtures

  describe "change_user_registration/2" do
    test "does not hash password during validation (performance)" do
      attrs = %{email: "test@example.com", password: "valid_password123", name: "Test User"}
      changeset = Accounts.change_user_registration(%User{}, attrs)

      # Password should be validated but NOT hashed during form validation
      assert changeset.valid?
      assert get_change(changeset, :password) == "valid_password123"
      refute get_change(changeset, :password_hash)
    end

    test "returns a changeset with validations" do
      changeset = Accounts.change_user_registration(%User{})
      assert %Ecto.Changeset{} = changeset
    end
  end

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

  describe "request_password_reset/1" do
    test "with existing email sends email and sets token" do
      user = user_fixture()
      assert :ok = Accounts.request_password_reset(user.email)

      updated = Accounts.get_user(user.id)
      assert updated.reset_password_token_hash != nil
      assert updated.reset_password_sent_at != nil

      assert_email_sent(fn email ->
        assert email.to == [{user.name, user.email}]
        assert email.subject == "Reset your password"
      end)
    end

    test "with non-existent email returns :ok (no leak)" do
      assert :ok = Accounts.request_password_reset("nope@example.com")
    end
  end

  describe "reset_password/2" do
    test "with valid token resets password" do
      user = user_fixture()
      token = set_password_reset_token(user)

      assert {:ok, updated} = Accounts.reset_password(token, %{"password" => "new_password123"})
      assert User.valid_password?(updated, "new_password123")
    end

    test "with expired token returns error" do
      user = user_fixture()
      token = set_password_reset_token(user, hours_ago: 2)

      assert {:error, :invalid_or_expired_token} =
               Accounts.reset_password(token, %{"password" => "new_password123"})
    end

    test "with invalid token returns error" do
      assert {:error, :invalid_or_expired_token} =
               Accounts.reset_password("bogus_token", %{"password" => "new_password123"})
    end

    test "clears the token after use" do
      user = user_fixture()
      token = set_password_reset_token(user)

      assert {:ok, _updated} = Accounts.reset_password(token, %{"password" => "new_password123"})

      cleared = Accounts.get_user(user.id)
      assert cleared.reset_password_token_hash == nil
      assert cleared.reset_password_sent_at == nil
    end

    test "with short password returns changeset error" do
      user = user_fixture()
      token = set_password_reset_token(user)

      assert {:error, changeset} = Accounts.reset_password(token, %{"password" => "short"})
      assert %{password: [_msg]} = errors_on(changeset)
    end
  end

  describe "deliver_confirmation_email/1" do
    test "sends email and sets token" do
      user = user_fixture()
      assert {:ok, updated} = Accounts.deliver_confirmation_email(user)
      assert updated.confirmation_token_hash != nil
      assert updated.confirmation_sent_at != nil

      assert_email_sent(fn email ->
        assert email.to == [{user.name, user.email}]
        assert email.subject == "Confirm your email address"
      end)
    end

    test "for already-confirmed user returns error" do
      user = user_fixture()
      {:ok, confirmed} = confirm_user(user)

      assert {:error, :already_confirmed} = Accounts.deliver_confirmation_email(confirmed)
    end
  end

  describe "confirm_email/1" do
    test "with valid token confirms user" do
      user = user_fixture()
      token = set_confirmation_token(user)

      assert {:ok, confirmed} = Accounts.confirm_email(token)
      assert confirmed.confirmed_at != nil
    end

    test "with expired token returns error" do
      user = user_fixture()
      token = set_confirmation_token(user, days_ago: 8)

      assert {:error, :invalid_or_expired_token} = Accounts.confirm_email(token)
    end

    test "with invalid token returns error" do
      assert {:error, :invalid_or_expired_token} = Accounts.confirm_email("bogus_token")
    end

    test "clears the token after use" do
      user = user_fixture()
      token = set_confirmation_token(user)

      assert {:ok, _confirmed} = Accounts.confirm_email(token)

      cleared = Accounts.get_user(user.id)
      assert cleared.confirmation_token_hash == nil
      assert cleared.confirmation_sent_at == nil
    end
  end

  describe "resend_confirmation_email/1" do
    test "sends new email" do
      user = user_fixture()
      assert {:ok, updated} = Accounts.resend_confirmation_email(user)
      assert updated.confirmation_token_hash != nil

      assert_email_sent(fn email ->
        assert email.subject == "Confirm your email address"
      end)
    end

    test "for already-confirmed user returns error" do
      user = user_fixture()
      {:ok, confirmed} = confirm_user(user)

      assert {:error, :already_confirmed} = Accounts.resend_confirmation_email(confirmed)
    end
  end

  # ── Test Helpers ──

  defp assert_email_sent(fun) do
    assert_received {:email, email}
    fun.(email)
  end

  defp set_password_reset_token(user, opts \\ []) do
    token = Accounts.generate_token()
    hash = Accounts.hash_token(token)

    sent_at =
      case Keyword.get(opts, :hours_ago) do
        nil -> DateTime.utc_now()
        hours -> DateTime.add(DateTime.utc_now(), -hours * 3600, :second)
      end

    user
    |> Ecto.Changeset.change(%{
      reset_password_token_hash: hash,
      reset_password_sent_at: sent_at
    })
    |> Syncforge.Repo.update!()

    token
  end

  defp set_confirmation_token(user, opts \\ []) do
    token = Accounts.generate_token()
    hash = Accounts.hash_token(token)

    sent_at =
      case Keyword.get(opts, :days_ago) do
        nil -> DateTime.utc_now()
        days -> DateTime.add(DateTime.utc_now(), -days * 86400, :second)
      end

    user
    |> Ecto.Changeset.change(%{
      confirmation_token_hash: hash,
      confirmation_sent_at: sent_at
    })
    |> Syncforge.Repo.update!()

    token
  end

  defp confirm_user(user) do
    user
    |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now()})
    |> Syncforge.Repo.update()
  end
end

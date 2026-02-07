defmodule Syncforge.MarketingTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Marketing
  alias Syncforge.Marketing.WaitlistSignup
  alias Syncforge.Repo

  describe "create_waitlist_signup/1" do
    test "creates a waitlist signup with normalized email" do
      raw_email = "  Person.#{System.unique_integer([:positive])}@Example.COM  "

      assert {:ok, signup} =
               Marketing.create_waitlist_signup(%{
                 email: raw_email,
                 source: "landing_page",
                 metadata: %{"campaign" => "hero_cta"}
               })

      assert signup.email == String.downcase(String.trim(raw_email))
      assert signup.source == "landing_page"
      assert signup.metadata == %{"campaign" => "hero_cta"}
    end

    test "returns error changeset for invalid email" do
      assert {:error, changeset} = Marketing.create_waitlist_signup(%{email: "invalid-email"})
      assert %{email: ["has invalid format"]} = errors_on(changeset)
    end

    test "enforces case-insensitive uniqueness on email" do
      email = "repeat-#{System.unique_integer([:positive])}@example.com"

      assert {:ok, _signup} = Marketing.create_waitlist_signup(%{email: email})

      assert {:error, changeset} =
               Marketing.create_waitlist_signup(%{email: String.upcase(email)})

      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_waitlist_signup_by_email/1" do
    test "finds signup with case-insensitive email lookup" do
      email = "lookup-#{System.unique_integer([:positive])}@example.com"
      assert {:ok, created} = Marketing.create_waitlist_signup(%{email: String.upcase(email)})

      assert fetched = Marketing.get_waitlist_signup_by_email(email)
      assert fetched.id == created.id
    end

    test "returns nil for unknown email" do
      assert Marketing.get_waitlist_signup_by_email("missing@example.com") == nil
    end
  end

  describe "list_waitlist_signups/0" do
    test "returns signups sorted from newest to oldest" do
      assert {:ok, older} =
               Marketing.create_waitlist_signup(%{
                 email: "older-#{System.unique_integer([:positive])}@example.com"
               })

      assert {:ok, newer} =
               Marketing.create_waitlist_signup(%{
                 email: "newer-#{System.unique_integer([:positive])}@example.com"
               })

      Repo.update_all(
        from(w in WaitlistSignup, where: w.id == ^older.id),
        set: [inserted_at: ~U[2024-01-01 00:00:00.000000Z]]
      )

      Repo.update_all(
        from(w in WaitlistSignup, where: w.id == ^newer.id),
        set: [inserted_at: ~U[2024-01-02 00:00:00.000000Z]]
      )

      [first, second | _] = Marketing.list_waitlist_signups()
      assert first.id == newer.id
      assert second.id == older.id
    end
  end
end

defmodule Syncforge.AccountsFixtures do
  @moduledoc """
  Test helpers for creating Accounts entities.
  """

  def unique_user_email, do: "user#{System.unique_integer([:positive])}@example.com"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: "valid_password123",
      name: "Test User"
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Syncforge.Accounts.register_user()

    user
  end
end

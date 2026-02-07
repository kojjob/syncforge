defmodule Syncforge.Marketing do
  @moduledoc """
  Marketing-facing context for waitlist and public lead capture.
  """

  import Ecto.Query, warn: false

  alias Syncforge.Marketing.WaitlistSignup
  alias Syncforge.Repo

  @doc """
  Creates a waitlist signup entry.
  """
  def create_waitlist_signup(attrs \\ %{}) do
    %WaitlistSignup{}
    |> WaitlistSignup.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns a signup by email (case-insensitive).
  """
  def get_waitlist_signup_by_email(email) when is_binary(email) do
    normalized =
      email
      |> String.trim()
      |> String.downcase()

    Repo.get_by(WaitlistSignup, email: normalized)
  end

  @doc """
  Lists waitlist signups from newest to oldest.
  """
  def list_waitlist_signups do
    WaitlistSignup
    |> order_by([w], desc: w.inserted_at)
    |> Repo.all()
  end
end

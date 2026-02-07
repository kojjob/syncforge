defmodule Syncforge.Marketing.WaitlistSignup do
  @moduledoc """
  Captures interest for the product launch waitlist.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "waitlist_signups" do
    field :email, :string
    field :source, :string, default: "landing_page"
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Builds a changeset for a waitlist signup.
  """
  def changeset(signup, attrs) do
    signup
    |> cast(attrs, [:email, :source, :metadata])
    |> validate_required([:email])
    |> update_change(:email, &normalize_email/1)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "has invalid format")
    |> validate_length(:email, max: 320)
    |> validate_length(:source, max: 100)
    |> unique_constraint(:email)
  end

  defp normalize_email(email) do
    email
    |> String.trim()
    |> String.downcase()
  end
end

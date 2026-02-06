defmodule Syncforge.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :name, :string
    field :avatar_url, :string
    field :role, :string, default: "member"
    field :last_sign_in_at, :utc_datetime_usec
    field :confirmed_at, :utc_datetime_usec
    field :reset_password_token_hash, :string
    field :reset_password_sent_at, :utc_datetime_usec
    field :confirmation_token_hash, :string
    field :confirmation_sent_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  A changeset for user registration.
  Validates email format, password length, hashes password, and downcases email.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :name, :avatar_url])
    |> validate_required([:email, :password, :name])
    |> validate_email()
    |> validate_password()
    |> maybe_hash_password(opts)
  end

  @doc """
  A changeset for updating user profile fields (name, avatar).
  """
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :avatar_url])
    |> validate_required([:name])
  end

  @doc """
  A changeset for resetting a user's password.
  Validates length and hashes the new password.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 8)
    |> maybe_hash_password(opts)
  end

  @doc """
  A changeset for confirming a user's email.
  Sets confirmed_at if not already set.
  """
  def confirm_changeset(user) do
    if user.confirmed_at do
      change(user)
    else
      change(user, confirmed_at: DateTime.utc_now())
    end
  end

  @doc """
  Verifies a password against the stored hash.
  Uses timing-safe comparison and handles nil hash gracefully.
  """
  def valid_password?(%__MODULE__{password_hash: password_hash}, password)
      when is_binary(password_hash) and is_binary(password) do
    Bcrypt.verify_pass(password, password_hash)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "has invalid format")
    |> update_change(:email, &String.downcase(String.trim(&1)))
    |> unique_constraint(:email)
  end

  defp validate_password(changeset) do
    validate_length(changeset, :password, min: 8)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)

    if hash_password? && changeset.valid? do
      case get_change(changeset, :password) do
        nil -> changeset
        password -> put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
      end
    else
      changeset
    end
  end
end

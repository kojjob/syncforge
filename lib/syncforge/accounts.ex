defmodule Syncforge.Accounts do
  @moduledoc """
  The Accounts context — user registration, authentication, and profile management.
  """

  alias Syncforge.Repo
  alias Syncforge.Accounts.User

  @doc """
  Registers a new user with the given attributes.
  Returns `{:ok, user}` with the password field cleared, or `{:error, changeset}`.
  """
  def register_user(attrs) do
    result =
      %User{}
      |> User.registration_changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, user} -> {:ok, %{user | password: nil}}
      error -> error
    end
  end

  @doc """
  Gets a user by ID. Returns `nil` if not found.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a user by ID. Raises `Ecto.NoResultsError` if not found.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a user by email (case-insensitive). Returns `nil` if not found.
  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Authenticates a user by email and password.
  Returns `{:ok, user}` or `{:error, :invalid_credentials}`.
  """
  def authenticate_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(email)

    if User.valid_password?(user, password) do
      {:ok, user}
    else
      {:error, :invalid_credentials}
    end
  end

  @doc """
  Updates a user's profile (name, avatar_url).
  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates the user's last_sign_in_at timestamp.
  """
  def update_last_sign_in(%User{} = user) do
    user
    |> Ecto.Changeset.change(last_sign_in_at: DateTime.utc_now())
    |> Repo.update()
  end

  @doc """
  Returns a registration changeset for use in forms or validation.
  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end
end

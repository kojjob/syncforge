defmodule Syncforge.Accounts do
  @moduledoc """
  The Accounts context — user registration, authentication, and profile management.
  """

  alias Syncforge.Repo
  alias Syncforge.Accounts.User
  alias Syncforge.Accounts.UserEmail
  alias Syncforge.Mailer

  @password_reset_max_age 3600
  @confirmation_max_age 7 * 86400

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

  # ── Password Reset ──

  @doc """
  Initiates a password reset for the given email.
  Always returns `:ok` to prevent email enumeration.
  """
  def request_password_reset(email) when is_binary(email) do
    normalized = email |> String.trim() |> String.downcase()

    case get_user_by_email(normalized) do
      nil ->
        :ok

      user ->
        token = generate_token()
        hash = hash_token(token)

        case user
             |> Ecto.Changeset.change(%{
               reset_password_token_hash: hash,
               reset_password_sent_at: DateTime.utc_now()
             })
             |> Repo.update() do
          {:ok, _updated} ->
            reset_url = "#{SyncforgeWeb.Endpoint.url()}/reset-password?token=#{token}"
            email_struct = UserEmail.password_reset_email(user, reset_url)
            Mailer.deliver(email_struct)
            maybe_send_test_email(email_struct)

          {:error, _changeset} ->
            :ok
        end

        :ok
    end
  end

  @doc """
  Resets a user's password using a raw token.
  Returns `{:ok, user}` or `{:error, reason}`.
  """
  def reset_password(raw_token, %{"password" => _} = attrs) do
    hash = hash_token(raw_token)

    case Repo.get_by(User, reset_password_token_hash: hash) do
      nil ->
        {:error, :invalid_or_expired_token}

      user ->
        if token_expired?(user.reset_password_sent_at, @password_reset_max_age) do
          {:error, :invalid_or_expired_token}
        else
          changeset =
            user
            |> User.password_changeset(attrs)
            |> Ecto.Changeset.change(%{
              reset_password_token_hash: nil,
              reset_password_sent_at: nil
            })

          case Repo.update(changeset) do
            {:ok, updated} -> {:ok, updated}
            {:error, changeset} -> {:error, changeset}
          end
        end
    end
  end

  # ── Email Confirmation ──

  @doc """
  Sends a confirmation email for the given user.
  Returns `{:ok, user}` or `{:error, :already_confirmed}`.
  """
  def deliver_confirmation_email(%User{} = user) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      token = generate_token()
      hash = hash_token(token)

      case user
           |> Ecto.Changeset.change(%{
             confirmation_token_hash: hash,
             confirmation_sent_at: DateTime.utc_now()
           })
           |> Repo.update() do
        {:ok, updated} ->
          confirm_url = "#{SyncforgeWeb.Endpoint.url()}/confirm-email?token=#{token}"
          email_struct = UserEmail.confirmation_email(updated, confirm_url)
          Mailer.deliver(email_struct)
          maybe_send_test_email(email_struct)

          {:ok, updated}

        {:error, _changeset} ->
          {:error, :update_failed}
      end
    end
  end

  @doc """
  Confirms a user's email using a raw token.
  Returns `{:ok, user}` or `{:error, :invalid_or_expired_token}`.
  """
  def confirm_email(raw_token) do
    hash = hash_token(raw_token)

    case Repo.get_by(User, confirmation_token_hash: hash) do
      nil ->
        {:error, :invalid_or_expired_token}

      user ->
        if token_expired?(user.confirmation_sent_at, @confirmation_max_age) do
          {:error, :invalid_or_expired_token}
        else
          user
          |> User.confirm_changeset()
          |> Ecto.Changeset.change(%{
            confirmation_token_hash: nil,
            confirmation_sent_at: nil
          })
          |> Repo.update()
        end
    end
  end

  @doc """
  Resends a confirmation email for the given user.
  Returns `{:ok, user}` or `{:error, :already_confirmed}`.
  """
  def resend_confirmation_email(%User{} = user) do
    deliver_confirmation_email(user)
  end

  # ── Token Helpers ──

  @doc false
  def generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  @doc false
  def hash_token(token) do
    :crypto.hash(:sha256, token) |> Base.encode64()
  end

  defp token_expired?(nil, _max_age), do: true

  defp token_expired?(sent_at, max_age) do
    DateTime.diff(DateTime.utc_now(), sent_at, :second) > max_age
  end

  defp maybe_send_test_email(email_struct) do
    if Application.get_env(:syncforge, :env) == :test do
      send(self(), {:email, email_struct})
    end
  end
end

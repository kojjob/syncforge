defmodule SyncforgeWeb.AuthController do
  use SyncforgeWeb, :controller

  alias Syncforge.Accounts

  def register(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        token = generate_token(user)

        conn
        |> put_status(:created)
        |> put_view(SyncforgeWeb.AuthJSON)
        |> render("user_with_token.json", user: user, token: token)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(SyncforgeWeb.AuthJSON)
        |> render("error.json", changeset: changeset)
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_by_email_and_password(email, password) do
      {:ok, user} ->
        Accounts.update_last_sign_in(user)
        token = generate_token(user)

        conn
        |> put_view(SyncforgeWeb.AuthJSON)
        |> render("user_with_token.json", user: user, token: token)

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
  end

  def me(conn, _params) do
    user = conn.assigns.current_user

    conn
    |> put_view(SyncforgeWeb.AuthJSON)
    |> render("user.json", user: user)
  end

  def forgot_password(conn, %{"email" => email}) do
    Accounts.request_password_reset(email)

    conn
    |> put_view(SyncforgeWeb.AuthJSON)
    |> render("message.json",
      message: "If an account exists with that email, you will receive reset instructions."
    )
  end

  def forgot_password(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Email is required"})
  end

  def reset_password(conn, %{"token" => token, "password" => password}) do
    case Accounts.reset_password(token, %{"password" => password}) do
      {:ok, _user} ->
        conn
        |> put_view(SyncforgeWeb.AuthJSON)
        |> render("message.json", message: "Password reset successfully.")

      {:error, :invalid_or_expired_token} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid or expired token"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(SyncforgeWeb.AuthJSON)
        |> render("error.json", changeset: changeset)
    end
  end

  def reset_password(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Token and password are required"})
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.confirm_email(token) do
      {:ok, user} ->
        conn
        |> put_view(SyncforgeWeb.AuthJSON)
        |> render("user.json", user: user)

      {:error, :invalid_or_expired_token} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid or expired token"})
    end
  end

  def confirm_email(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Token is required"})
  end

  def resend_confirmation(conn, _params) do
    user = conn.assigns.current_user

    case Accounts.resend_confirmation_email(user) do
      {:ok, _user} ->
        conn
        |> put_view(SyncforgeWeb.AuthJSON)
        |> render("message.json", message: "Confirmation email sent.")

      {:error, :already_confirmed} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Email already confirmed"})
    end
  end

  # Generate a Phoenix.Token with the same shape UserSocket expects:
  # %{id: binary_id, name: string, avatar_url: string | nil}
  defp generate_token(user) do
    Phoenix.Token.sign(SyncforgeWeb.Endpoint, "user socket", %{
      id: user.id,
      name: user.name,
      avatar_url: user.avatar_url
    })
  end
end

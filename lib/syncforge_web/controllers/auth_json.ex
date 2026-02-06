defmodule SyncforgeWeb.AuthJSON do
  alias Syncforge.Accounts.User

  def render("user_with_token.json", %{user: user, token: token}) do
    %{
      user: user_data(user),
      token: token
    }
  end

  def render("user.json", %{user: user}) do
    %{user: user_data(user)}
  end

  def render("message.json", %{message: message}) do
    %{message: message}
  end

  def render("error.json", %{changeset: changeset}) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    %{errors: errors}
  end

  defp user_data(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      name: user.name,
      avatar_url: user.avatar_url,
      role: user.role,
      inserted_at: user.inserted_at
    }
  end
end

defmodule Syncforge.Reactions do
  @moduledoc """
  The Reactions context.

  Handles adding, removing, and toggling emoji reactions on comments.
  Provides functions for listing and counting reactions.
  """

  import Ecto.Query, warn: false

  alias Syncforge.Repo
  alias Syncforge.Reactions.Reaction

  @doc """
  Adds a new reaction to a comment.

  Returns `{:ok, reaction}` on success, or `{:error, changeset}` on failure.
  """
  def add_reaction(attrs) do
    %Reaction{}
    |> Reaction.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Removes a reaction.

  Returns `{:ok, reaction}` on success, or `{:error, changeset}` on failure.
  """
  def remove_reaction(%Reaction{} = reaction) do
    Repo.delete(reaction)
  end

  @doc """
  Removes a reaction by comment_id, user_id, and emoji.

  Returns `{:ok, reaction}` if found and deleted, or `{:error, :not_found}` if not found.
  """
  def remove_reaction(comment_id, user_id, emoji) do
    case get_user_reaction(comment_id, user_id, emoji) do
      nil -> {:error, :not_found}
      reaction -> Repo.delete(reaction)
    end
  end

  @doc """
  Toggles a reaction - adds it if it doesn't exist, removes it if it does.

  Returns `{:ok, :added, reaction}` when adding, or `{:ok, :removed, reaction}` when removing.
  Returns `{:error, changeset}` on failure.
  """
  def toggle_reaction(attrs) do
    comment_id = attrs[:comment_id] || attrs["comment_id"]
    user_id = attrs[:user_id] || attrs["user_id"]
    emoji = attrs[:emoji] || attrs["emoji"]

    case get_user_reaction(comment_id, user_id, emoji) do
      nil ->
        case add_reaction(attrs) do
          {:ok, reaction} -> {:ok, :added, reaction}
          {:error, changeset} -> {:error, changeset}
        end

      reaction ->
        case Repo.delete(reaction) do
          {:ok, deleted_reaction} -> {:ok, :removed, deleted_reaction}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @doc """
  Gets a reaction by its ID.

  Returns the reaction or nil if not found.
  """
  def get_reaction(id) do
    Repo.get(Reaction, id)
  end

  @doc """
  Gets a user's specific reaction on a comment.

  Returns the reaction or nil if not found.
  """
  def get_user_reaction(comment_id, user_id, emoji) do
    Reaction
    |> where([r], r.comment_id == ^comment_id and r.user_id == ^user_id and r.emoji == ^emoji)
    |> Repo.one()
  end

  @doc """
  Lists all reactions for a comment.

  Returns a list of reactions.
  """
  def list_reactions(comment_id) do
    Reaction
    |> where([r], r.comment_id == ^comment_id)
    |> order_by([r], asc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists all reactions by a user on a specific comment.

  Returns a list of reactions.
  """
  def list_user_reactions(comment_id, user_id) do
    Reaction
    |> where([r], r.comment_id == ^comment_id and r.user_id == ^user_id)
    |> order_by([r], asc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Counts reactions for a comment, grouped by emoji.

  Returns a map like `%{"thumbs_up" => 5, "heart" => 3}`.
  """
  def count_reactions(comment_id) do
    Reaction
    |> where([r], r.comment_id == ^comment_id)
    |> group_by([r], r.emoji)
    |> select([r], {r.emoji, count(r.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Counts reactions for multiple comments in a single query (batch).

  Returns a map of comment_id => %{emoji => count}.

  ## Example

      iex> count_reactions_for_comments(["comment-1", "comment-2"])
      %{
        "comment-1" => %{"👍" => 5, "❤️" => 2},
        "comment-2" => %{"👍" => 1}
      }

  """
  def count_reactions_for_comments([]), do: %{}

  def count_reactions_for_comments(comment_ids) when is_list(comment_ids) do
    Reaction
    |> where([r], r.comment_id in ^comment_ids)
    |> group_by([r], [r.comment_id, r.emoji])
    |> select([r], {r.comment_id, r.emoji, count(r.id)})
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0), fn {_, emoji, count} -> {emoji, count} end)
    |> Map.new(fn {comment_id, counts} -> {comment_id, Map.new(counts)} end)
  end
end

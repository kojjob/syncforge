defmodule Syncforge.Comments do
  @moduledoc """
  The Comments context manages threaded comments in collaboration rooms.

  Comments can be:
  - Anchored to specific elements via `anchor_id` and `anchor_type`
  - Positioned at specific coordinates via `position`
  - Threaded via `parent_id` for replies
  - Resolved via `resolved_at` timestamp

  ## Examples

      # Create a new comment
      {:ok, comment} = Comments.create_comment(%{
        body: "Great work!",
        room_id: room_id,
        user_id: user_id
      })

      # Create a reply
      {:ok, reply} = Comments.create_comment(%{
        body: "Thanks!",
        room_id: room_id,
        user_id: user_id,
        parent_id: comment.id
      })

      # Resolve a comment thread
      {:ok, resolved} = Comments.resolve_comment(comment)

  """

  import Ecto.Query, warn: false

  alias Syncforge.Repo
  alias Syncforge.Comments.Comment

  @doc """
  Returns the list of comments for a room.

  ## Options

  - `:include_replies` - Include threaded replies (default: true)
  - `:include_resolved` - Include resolved comments (default: true)
  - `:limit` - Maximum number of comments to return (default: no limit)
  - `:offset` - Number of comments to skip (default: 0)

  ## Examples

      iex> list_comments(room_id)
      [%Comment{}, ...]

      iex> list_comments(room_id, limit: 10, offset: 20)
      [%Comment{}, ...]

  """
  def list_comments(room_id, opts \\ []) do
    include_resolved = Keyword.get(opts, :include_resolved, true)
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    Comment
    |> where([c], c.room_id == ^room_id)
    |> maybe_exclude_resolved(include_resolved)
    |> order_by([c], asc: c.inserted_at, asc: c.id)
    |> maybe_offset(offset)
    |> maybe_limit(limit)
    |> Repo.all()
  end

  defp maybe_exclude_resolved(query, true), do: query
  defp maybe_exclude_resolved(query, false), do: where(query, [c], is_nil(c.resolved_at))

  defp maybe_limit(query, nil), do: query
  defp maybe_limit(query, limit) when is_integer(limit) and limit > 0, do: limit(query, ^limit)
  defp maybe_limit(query, _limit), do: query

  defp maybe_offset(query, 0), do: query

  defp maybe_offset(query, offset) when is_integer(offset) and offset > 0,
    do: offset(query, ^offset)

  defp maybe_offset(query, _offset), do: query

  @doc """
  Returns top-level comments (no parent) for a room.

  ## Examples

      iex> list_top_level_comments(room_id)
      [%Comment{parent_id: nil}, ...]

  """
  def list_top_level_comments(room_id) do
    Comment
    |> where([c], c.room_id == ^room_id and is_nil(c.parent_id))
    |> order_by([c], asc: c.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns replies for a specific comment.

  ## Examples

      iex> list_replies(parent_id)
      [%Comment{parent_id: ^parent_id}, ...]

  """
  def list_replies(parent_id) do
    Comment
    |> where([c], c.parent_id == ^parent_id)
    |> order_by([c], asc: c.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single comment by ID.

  Returns nil if the comment does not exist.

  ## Examples

      iex> get_comment("7488a646-e31f-11e4-aace-600308960662")
      %Comment{}

      iex> get_comment("invalid-id")
      nil

  """
  def get_comment(id), do: Repo.get(Comment, id)

  @doc """
  Gets a single comment by ID.

  Raises `Ecto.NoResultsError` if the Comment does not exist.

  ## Examples

      iex> get_comment!("7488a646-e31f-11e4-aace-600308960662")
      %Comment{}

      iex> get_comment!("invalid-id")
      ** (Ecto.NoResultsError)

  """
  def get_comment!(id), do: Repo.get!(Comment, id)

  @doc """
  Creates a comment.

  ## Examples

      iex> create_comment(%{body: "Great work!", room_id: room_id, user_id: user_id})
      {:ok, %Comment{}}

      iex> create_comment(%{body: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_comment(attrs \\ %{}) do
    %Comment{}
    |> Comment.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a comment.

  Note: Only body, anchor_id, anchor_type, and position can be updated.
  Room and user cannot be changed after creation.

  ## Examples

      iex> update_comment(comment, %{body: "Updated text"})
      {:ok, %Comment{}}

      iex> update_comment(comment, %{body: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_comment(%Comment{} = comment, attrs) do
    comment
    |> Comment.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a comment.

  Note: This will also delete all replies due to the cascade delete constraint.

  ## Examples

      iex> delete_comment(comment)
      {:ok, %Comment{}}

  """
  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  @doc """
  Resolves a comment by setting the resolved_at timestamp.

  ## Examples

      iex> resolve_comment(comment)
      {:ok, %Comment{resolved_at: ~U[2024-01-15 10:30:00Z]}}

  """
  def resolve_comment(%Comment{} = comment) do
    comment
    |> Comment.resolve_changeset(DateTime.utc_now())
    |> Repo.update()
  end

  @doc """
  Unresolves a comment by clearing the resolved_at timestamp.

  ## Examples

      iex> unresolve_comment(comment)
      {:ok, %Comment{resolved_at: nil}}

  """
  def unresolve_comment(%Comment{} = comment) do
    comment
    |> Comment.resolve_changeset(nil)
    |> Repo.update()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking comment changes.

  ## Examples

      iex> change_comment(comment)
      %Ecto.Changeset{data: %Comment{}}

  """
  def change_comment(%Comment{} = comment, attrs \\ %{}) do
    Comment.update_changeset(comment, attrs)
  end

  @doc """
  Checks if a comment exists by ID.

  ## Examples

      iex> comment_exists?("7488a646-e31f-11e4-aace-600308960662")
      true

      iex> comment_exists?("non-existent")
      false

  """
  def comment_exists?(id) do
    Comment
    |> where([c], c.id == ^id)
    |> Repo.exists?()
  end

  @doc """
  Returns the count of comments in a room.

  ## Examples

      iex> count_comments(room_id)
      42

  """
  def count_comments(room_id) do
    Comment
    |> where([c], c.room_id == ^room_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns the count of unresolved comments in a room.

  ## Examples

      iex> count_unresolved_comments(room_id)
      5

  """
  def count_unresolved_comments(room_id) do
    Comment
    |> where([c], c.room_id == ^room_id and is_nil(c.resolved_at))
    |> Repo.aggregate(:count)
  end
end

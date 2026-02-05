defmodule Syncforge.Notifications do
  @moduledoc """
  Context for managing user notifications.

  Provides functions for creating, querying, and managing notifications
  for user activity such as mentions, replies, reactions, and room events.
  """

  import Ecto.Query, warn: false

  alias Syncforge.Repo
  alias Syncforge.Notifications.Notification

  @doc """
  Creates a notification with the given attributes.

  ## Examples

      iex> create_notification(%{type: "comment_mention", user_id: "uuid", actor_id: "uuid"})
      {:ok, %Notification{}}

      iex> create_notification(%{type: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a notification by ID.

  Returns `nil` if the notification does not exist.

  ## Examples

      iex> get_notification("valid-uuid")
      %Notification{}

      iex> get_notification("invalid-uuid")
      nil
  """
  def get_notification(id) do
    Repo.get(Notification, id)
  end

  @doc """
  Lists all notifications for a user, ordered by newest first.

  ## Options

    * `:limit` - Maximum number of notifications to return
    * `:offset` - Number of notifications to skip

  ## Examples

      iex> list_notifications(user_id)
      [%Notification{}, ...]

      iex> list_notifications(user_id, limit: 10, offset: 0)
      [%Notification{}, ...]
  """
  def list_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from n in Notification,
        where: n.user_id == ^user_id,
        order_by: [desc: n.inserted_at, desc: n.id]

    query =
      if limit do
        query
        |> limit(^limit)
        |> offset(^offset)
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Lists all unread notifications for a user, ordered by newest first.

  ## Examples

      iex> list_unread_notifications(user_id)
      [%Notification{read_at: nil}, ...]
  """
  def list_unread_notifications(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at),
      order_by: [desc: n.inserted_at, desc: n.id]
    )
    |> Repo.all()
  end

  @doc """
  Marks a notification as read.

  If the notification is already read, it remains unchanged (idempotent).

  ## Examples

      iex> mark_as_read(notification)
      {:ok, %Notification{read_at: ~U[2024-01-01 12:00:00Z]}}
  """
  def mark_as_read(%Notification{read_at: nil} = notification) do
    notification
    |> Notification.changeset(%{read_at: DateTime.utc_now()})
    |> Repo.update()
  end

  def mark_as_read(%Notification{} = notification) do
    # Already read, return unchanged (idempotent)
    {:ok, notification}
  end

  @doc """
  Marks all notifications for a user as read.

  Returns `{count, nil}` where count is the number of notifications updated.

  ## Examples

      iex> mark_all_as_read(user_id)
      {5, nil}
  """
  def mark_all_as_read(user_id) do
    now = DateTime.utc_now()

    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at)
    )
    |> Repo.update_all(set: [read_at: now])
  end

  @doc """
  Returns the count of unread notifications for a user.

  ## Examples

      iex> count_unread(user_id)
      5
  """
  def count_unread(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at),
      select: count(n.id)
    )
    |> Repo.one()
  end

  @doc """
  Deletes a notification.

  ## Examples

      iex> delete_notification(notification)
      {:ok, %Notification{}}
  """
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  @doc """
  Deletes notifications older than the specified number of days.

  Returns `{count, nil}` where count is the number of notifications deleted.

  ## Examples

      iex> delete_old_notifications(30)
      {100, nil}
  """
  def delete_old_notifications(days) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -days, :day)

    from(n in Notification,
      where: n.inserted_at < ^cutoff_date
    )
    |> Repo.delete_all()
  end
end

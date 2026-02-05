defmodule Syncforge.Notifications do
  @moduledoc """
  Context for managing user notifications.

  Provides functions for creating, querying, and managing notifications
  for user activity such as mentions, replies, reactions, and room events.
  """

  import Ecto.Query, warn: false

  alias Syncforge.Repo
  alias Syncforge.Notifications.Notification
  alias Syncforge.Notifications.NotificationPreference

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
  Creates a notification and broadcasts it to the user's notification channel.

  This is the preferred method for creating notifications as it ensures
  the user receives the notification in real-time.

  ## Examples

      iex> create_and_broadcast_notification(%{type: "comment_mention", user_id: "uuid", actor_id: "uuid"})
      {:ok, %Notification{}}

      iex> create_and_broadcast_notification(%{type: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def create_and_broadcast_notification(attrs) do
    case create_notification(attrs) do
      {:ok, notification} ->
        # Broadcast to the user's notification channel
        SyncforgeWeb.NotificationChannel.broadcast_notification(notification)
        {:ok, notification}

      {:error, changeset} ->
        {:error, changeset}
    end
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

  # ============================================
  # Notification Preferences
  # ============================================

  @doc """
  Gets notification preferences for a user.

  Returns `nil` if the user has no preferences set.

  ## Examples

      iex> get_preferences("valid-user-id")
      %NotificationPreference{}

      iex> get_preferences("non-existent-user-id")
      nil
  """
  def get_preferences(user_id) do
    Repo.get_by(NotificationPreference, user_id: user_id)
  end

  @doc """
  Gets or creates notification preferences for a user.

  If the user has no preferences, creates default preferences with all
  notification types enabled.

  ## Examples

      iex> get_or_create_preferences("user-id")
      {:ok, %NotificationPreference{}}
  """
  def get_or_create_preferences(user_id) do
    case get_preferences(user_id) do
      nil ->
        %NotificationPreference{}
        |> NotificationPreference.changeset(%{user_id: user_id})
        |> Repo.insert()

      preferences ->
        {:ok, preferences}
    end
  end

  @doc """
  Updates notification preferences.

  ## Examples

      iex> update_preferences(preference, %{comment_mention: false})
      {:ok, %NotificationPreference{comment_mention: false}}
  """
  def update_preferences(%NotificationPreference{} = preference, attrs) do
    preference
    |> NotificationPreference.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Checks if a user should receive a notification of the given type.

  Returns `true` if:
  - The user has no preferences (defaults to enabled)
  - The preference for this notification type is enabled
  - The notification type is unknown (fail-open)

  Returns `false` if the user has explicitly disabled notifications
  of this type.

  ## Examples

      iex> should_notify?("user-id", "comment_mention")
      true

      iex> should_notify?("user-id", "comment_mention") # after disabling
      false
  """
  def should_notify?(user_id, notification_type) do
    case get_preferences(user_id) do
      nil ->
        # No preferences = all enabled (defaults)
        true

      preferences ->
        field = NotificationPreference.type_to_field(notification_type)

        if field do
          Map.get(preferences, field, true)
        else
          # Unknown notification type, fail-open
          true
        end
    end
  end

  @doc """
  Creates a notification only if the user's preferences allow it.

  Returns `{:ok, notification}` if created successfully.
  Returns `{:skipped, :preference_disabled}` if the user has disabled
  notifications of this type.
  Returns `{:error, changeset}` if validation fails.

  ## Examples

      iex> create_notification_with_preferences(%{type: "comment_mention", user_id: "uuid"})
      {:ok, %Notification{}}

      iex> create_notification_with_preferences(%{type: "comment_mention", user_id: "uuid"})
      {:skipped, :preference_disabled}  # if user disabled this type
  """
  def create_notification_with_preferences(attrs) do
    user_id = attrs[:user_id] || attrs["user_id"]
    notification_type = attrs[:type] || attrs["type"]

    if should_notify?(user_id, notification_type) do
      create_notification(attrs)
    else
      {:skipped, :preference_disabled}
    end
  end
end

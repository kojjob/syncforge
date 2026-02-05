defmodule Syncforge.Activity do
  @moduledoc """
  Context for managing room activity feeds.

  Provides functions for creating, querying, and managing activity entries
  that track collaboration events within rooms. Activities form a shared
  chronological history visible to all room members.

  ## Key Differences from Notifications

  - **Room-centric**: Activities belong to rooms, not individual users
  - **Shared history**: All room members see the same activity feed
  - **No read tracking**: Activities don't have read/unread status
  - **No preferences**: Activities are always created regardless of user preferences

  ## Activity Types

  - `user_joined` - User joined the room
  - `user_left` - User left the room
  - `comment_created` - New comment posted
  - `comment_resolved` - Comment thread resolved
  - `comment_deleted` - Comment removed
  - `reaction_added` - Emoji reaction added
  - `reaction_removed` - Emoji reaction removed
  """

  import Ecto.Query, warn: false

  alias Syncforge.Repo
  alias Syncforge.Activity.Activity

  @doc """
  Creates an activity with the given attributes.

  ## Examples

      iex> create_activity(%{type: "user_joined", room_id: "uuid", actor_id: "uuid"})
      {:ok, %Activity{}}

      iex> create_activity(%{type: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def create_activity(attrs) do
    %Activity{}
    |> Activity.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates an activity and broadcasts it to the room's activity channel.

  This is the preferred method for creating activities as it ensures
  all room members receive the activity in real-time.

  ## Examples

      iex> create_and_broadcast_activity(%{type: "comment_created", room_id: "uuid", actor_id: "uuid"})
      {:ok, %Activity{}}

      iex> create_and_broadcast_activity(%{type: "invalid"})
      {:error, %Ecto.Changeset{}}
  """
  def create_and_broadcast_activity(attrs) do
    case create_activity(attrs) do
      {:ok, activity} ->
        # Broadcast to the room's activity topic
        broadcast_activity(activity)
        {:ok, activity}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets an activity by ID.

  Returns `nil` if the activity does not exist.

  ## Examples

      iex> get_activity("valid-uuid")
      %Activity{}

      iex> get_activity("invalid-uuid")
      nil
  """
  def get_activity(id) do
    Repo.get(Activity, id)
  end

  @doc """
  Lists all activities for a room, ordered by newest first.

  ## Options

    * `:limit` - Maximum number of activities to return
    * `:offset` - Number of activities to skip

  ## Examples

      iex> list_room_activities(room_id)
      [%Activity{}, ...]

      iex> list_room_activities(room_id, limit: 10, offset: 0)
      [%Activity{}, ...]
  """
  def list_room_activities(room_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from a in Activity,
        where: a.room_id == ^room_id,
        order_by: [desc: a.inserted_at, desc: a.id]

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
  Deletes activities older than the specified number of days.

  Returns `{count, nil}` where count is the number of activities deleted.

  ## Examples

      iex> delete_old_activities(30)
      {100, nil}
  """
  def delete_old_activities(days) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -days, :day)

    from(a in Activity,
      where: a.inserted_at < ^cutoff_date
    )
    |> Repo.delete_all()
  end

  @doc """
  Serializes an activity for channel/API responses.

  ## Examples

      iex> serialize_activity(activity)
      %{id: "uuid", type: "user_joined", ...}
  """
  def serialize_activity(%Activity{} = activity) do
    %{
      id: activity.id,
      type: activity.type,
      room_id: activity.room_id,
      actor_id: activity.actor_id,
      subject_id: activity.subject_id,
      subject_type: activity.subject_type,
      payload: activity.payload,
      inserted_at: activity.inserted_at
    }
  end

  # Private functions

  defp broadcast_activity(activity) do
    Phoenix.PubSub.broadcast(
      Syncforge.PubSub,
      "room:#{activity.room_id}",
      {:activity_created, serialize_activity(activity)}
    )
  end
end

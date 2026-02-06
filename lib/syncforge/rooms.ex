defmodule Syncforge.Rooms do
  @moduledoc """
  The Rooms context manages collaboration rooms.

  Rooms are the primary container for real-time collaboration, containing:
  - User presence tracking
  - Live cursor positions
  - Document state (via CRDT sync)
  - Threaded comments

  ## Examples

      # Create a new room
      {:ok, room} = Rooms.create_room(%{name: "Design Review"})

      # Get room by slug (for URL routing)
      room = Rooms.get_room_by_slug("design-review")

      # List public rooms
      rooms = Rooms.list_public_rooms()

  """

  import Ecto.Query, warn: false

  alias Syncforge.Repo
  alias Syncforge.Rooms.Room

  @doc """
  Returns the list of all rooms.

  ## Examples

      iex> list_rooms()
      [%Room{}, ...]

  """
  def list_rooms do
    Repo.all(Room)
  end

  @doc """
  Returns the list of public rooms.

  ## Examples

      iex> list_public_rooms()
      [%Room{is_public: true}, ...]

  """
  def list_public_rooms do
    Room
    |> where([r], r.is_public == true)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of rooms of a specific type.

  ## Examples

      iex> list_rooms_by_type(:document)
      [%Room{type: :document}, ...]

  """
  def list_rooms_by_type(type) when is_atom(type) do
    Room
    |> where([r], r.type == ^type)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single room by ID.

  Raises `Ecto.NoResultsError` if the Room does not exist.

  ## Examples

      iex> get_room!("7488a646-e31f-11e4-aace-600308960662")
      %Room{}

      iex> get_room!("invalid-id")
      ** (Ecto.NoResultsError)

  """
  def get_room!(id), do: Repo.get!(Room, id)

  @doc """
  Gets a single room by ID, returning nil if not found.

  ## Examples

      iex> get_room("7488a646-e31f-11e4-aace-600308960662")
      %Room{}

      iex> get_room("invalid-id")
      nil

  """
  def get_room(id), do: Repo.get(Room, id)

  @doc """
  Gets a single room by slug.

  ## Examples

      iex> get_room_by_slug("design-review")
      %Room{slug: "design-review"}

      iex> get_room_by_slug("non-existent")
      nil

  """
  def get_room_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Room, slug: slug)
  end

  @doc """
  Creates a room.

  ## Examples

      iex> create_room(%{name: "Design Review"})
      {:ok, %Room{}}

      iex> create_room(%{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_room(attrs \\ %{}) do
    %Room{}
    |> Room.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a room.

  ## Examples

      iex> update_room(room, %{name: "New Name"})
      {:ok, %Room{}}

      iex> update_room(room, %{name: nil})
      {:error, %Ecto.Changeset{}}

  """
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a room.

  ## Examples

      iex> delete_room(room)
      {:ok, %Room{}}

      iex> delete_room(room)
      {:error, %Ecto.Changeset{}}

  """
  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes.

  ## Examples

      iex> change_room(room)
      %Ecto.Changeset{data: %Room{}}

  """
  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.update_changeset(room, attrs)
  end

  @doc """
  Checks if a room exists by ID.

  ## Examples

      iex> room_exists?("7488a646-e31f-11e4-aace-600308960662")
      true

      iex> room_exists?("non-existent")
      false

  """
  def room_exists?(id) do
    Room
    |> where([r], r.id == ^id)
    |> Repo.exists?()
  end

  @doc """
  Checks if a room exists by slug.

  ## Examples

      iex> room_slug_exists?("design-review")
      true

      iex> room_slug_exists?("non-existent")
      false

  """
  def room_slug_exists?(slug) do
    Room
    |> where([r], r.slug == ^slug)
    |> Repo.exists?()
  end

  @doc """
  Authorizes a user to join a room.

  Checks:
  - Room exists
  - Room has available capacity
  - User has access (public rooms allow anyone, private rooms require membership)

  ## Options

  - `:current_participant_count` - Override participant count (useful for testing)

  ## Examples

      iex> authorize_join("room-id", user)
      {:ok, %Room{}}

      iex> authorize_join("non-existent", user)
      {:error, :room_not_found}

      iex> authorize_join("full-room-id", user)
      {:error, :room_full}

      iex> authorize_join("private-room-id", unauthorized_user)
      {:error, :unauthorized}

  """
  def authorize_join(room_id, user, opts \\ []) do
    with {:ok, room} <- fetch_room(room_id),
         :ok <- check_capacity(room, opts),
         {:ok, role} <- check_access(room, user) do
      {:ok, room, role}
    end
  end

  # Private authorization helpers

  defp fetch_room(room_id) do
    case get_room(room_id) do
      nil -> {:error, :room_not_found}
      room -> {:ok, room}
    end
  end

  defp check_capacity(room, opts) do
    current_count = Keyword.get(opts, :current_participant_count, get_participant_count(room.id))

    if current_count < room.max_participants do
      :ok
    else
      {:error, :room_full}
    end
  end

  defp check_access(room, user) do
    cond do
      is_nil(room.organization_id) ->
        if room.is_public, do: {:ok, nil}, else: {:error, :unauthorized}

      room.is_public ->
        {:ok, lookup_membership_role(room.organization_id, user)}

      true ->
        case lookup_membership_role(room.organization_id, user) do
          nil -> {:error, :unauthorized}
          role -> {:ok, role}
        end
    end
  end

  defp lookup_membership_role(_org_id, nil), do: nil

  defp lookup_membership_role(org_id, user) when is_map(user) do
    case Map.get(user, :id) || Map.get(user, "id") do
      nil ->
        nil

      user_id ->
        case Syncforge.Organizations.get_membership(org_id, user_id) do
          %{status: "active", role: role} -> role
          _ -> nil
        end
    end
  end

  defp lookup_membership_role(_org_id, _user), do: nil

  # --- Dashboard Helpers ---

  @doc """
  Lists rooms belonging to an organization, ordered by most recent.
  """
  def list_rooms_for_organization(org_id) do
    Room
    |> where([r], r.organization_id == ^org_id)
    |> order_by([r], desc: r.inserted_at)
    |> Repo.all()
  end

  @doc """
  Counts rooms belonging to an organization.
  """
  def count_rooms_for_organization(org_id) do
    Room
    |> where([r], r.organization_id == ^org_id)
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns the current state of a room for syncing to joining users.

  Includes:
  - Room metadata (id, name, config, etc.)
  - Current comments with embedded reactions
  - Recent activities (last 50)

  For ad-hoc rooms (room_id not in database), returns a minimal state.

  ## Examples

      iex> get_state(room_id)
      %{room: %{id: "...", name: "...", ...}, comments: [...], activities: [...]}

  """
  def get_state(room_id) do
    case get_room(room_id) do
      nil ->
        # Ad-hoc room - return minimal state
        %{
          room: %{
            id: room_id,
            name: nil,
            slug: nil,
            type: nil,
            is_public: true,
            max_participants: nil,
            metadata: nil,
            config: nil
          },
          comments: [],
          activities: []
        }

      room ->
        comments = Syncforge.Comments.list_comments(room_id)

        # Batch query for all reactions in one query (fixes N+1 problem)
        comment_ids = Enum.map(comments, & &1.id)
        reactions_by_comment = Syncforge.Reactions.count_reactions_for_comments(comment_ids)

        # Embed reactions in each comment
        comments_with_reactions =
          Enum.map(comments, fn comment ->
            reactions = Map.get(reactions_by_comment, comment.id, %{})
            serialize_comment(comment, reactions)
          end)

        # Get recent activities (last 50)
        activities =
          Syncforge.Activity.list_room_activities(room_id, limit: 50)
          |> Enum.map(&Syncforge.Activity.serialize_activity/1)

        %{
          room: serialize_room(room),
          comments: comments_with_reactions,
          activities: activities
        }
    end
  end

  # Serialize room struct for JSON response
  defp serialize_room(room) do
    %{
      id: room.id,
      name: room.name,
      slug: room.slug,
      type: room.type,
      is_public: room.is_public,
      max_participants: room.max_participants,
      metadata: room.metadata,
      config: room.config
    }
  end

  # Serialize comment struct for JSON response (with embedded reactions)
  defp serialize_comment(comment, reactions) do
    %{
      id: comment.id,
      body: comment.body,
      anchor_id: comment.anchor_id,
      anchor_type: comment.anchor_type,
      position: comment.position,
      resolved_at: comment.resolved_at,
      user_id: comment.user_id,
      room_id: comment.room_id,
      parent_id: comment.parent_id,
      inserted_at: comment.inserted_at,
      updated_at: comment.updated_at,
      reactions: reactions
    }
  end

  @doc """
  Returns the current participant count for a room.

  Uses Phoenix Presence to get the accurate real-time count.
  """
  def get_participant_count(room_id) do
    # Use the Presence helper function which handles all edge cases
    SyncforgeWeb.Presence.room_user_count(room_id)
  rescue
    # Only rescue ArgumentError, which occurs when the Presence ETS table
    # doesn't exist (e.g., Presence tracker not started in test environment).
    # Other exceptions (RuntimeError, etc.) should propagate normally.
    ArgumentError -> 0
  end
end

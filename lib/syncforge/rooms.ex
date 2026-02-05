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
  Returns room configuration for channel authorization.

  Used by RoomChannel to validate join requests and get room settings.

  ## Examples

      iex> authorize_join("room-id", user)
      {:ok, %Room{}}

      iex> authorize_join("non-existent", user)
      {:error, :room_not_found}

  """
  def authorize_join(room_id, _user) do
    case get_room(room_id) do
      nil ->
        {:error, :room_not_found}

      room ->
        # TODO: Add actual authorization logic
        # - Check if room is public or user has access
        # - Check if room is at capacity
        # - Check if user is banned
        {:ok, room}
    end
  end
end

defmodule SyncforgeWeb.Presence do
  @moduledoc """
  Phoenix Presence for tracking users across rooms.

  Provides real-time presence tracking with automatic conflict resolution
  using CRDTs. Tracks user metadata like name, avatar, status, and
  custom fields.

  ## Usage

      # Track a user in a room
      Presence.track(socket, user_id, %{
        name: "John Doe",
        avatar_url: "https://...",
        status: "active",
        joined_at: DateTime.utc_now()
      })

      # Update user metadata
      Presence.update(socket, user_id, fn meta ->
        Map.put(meta, :status, "typing")
      end)

      # List all users in a room
      Presence.list("room:abc123")
  """

  use Phoenix.Presence,
    otp_app: :syncforge,
    pubsub_server: Syncforge.PubSub

  @doc """
  Track a user's presence in a room with metadata.

  Called when a user joins a room channel.
  """
  def track_user(socket, user, metadata \\ %{}) do
    track(socket, user.id, %{
      user_id: user.id,
      name: user.name,
      avatar_url: Map.get(user, :avatar_url),
      status: Map.get(metadata, :status, "active"),
      joined_at: DateTime.utc_now(),
      metadata: Map.drop(metadata, [:status])
    })
  end

  @doc """
  Update a user's presence metadata.

  Use for status changes, cursor positions, or any dynamic metadata.
  """
  def update_user(socket, user_id, updates) when is_map(updates) do
    update(socket, user_id, fn existing ->
      Map.merge(existing, updates)
    end)
  end

  @doc """
  Get all users present in a specific room.

  Returns a list of user metadata maps.
  """
  def list_room_users(room_id) do
    "room:#{room_id}"
    |> list()
    |> Enum.map(fn {_user_id, %{metas: [meta | _]}} -> meta end)
  end

  @doc """
  Get the count of users in a room.
  """
  def room_user_count(room_id) do
    "room:#{room_id}"
    |> list()
    |> map_size()
  end

  @doc """
  Check if a specific user is present in a room.
  """
  def user_in_room?(room_id, user_id) do
    "room:#{room_id}"
    |> list()
    |> Map.has_key?(user_id)
  end

  @doc """
  Format presence data for client consumption.

  Transforms the raw presence map into a client-friendly format.
  """
  def format_presence(presence) do
    Enum.map(presence, fn {user_id, %{metas: metas}} ->
      # Take the most recent meta (in case of multiple connections)
      meta = List.first(metas)

      %{
        user_id: user_id,
        name: meta.name,
        avatar_url: meta.avatar_url,
        status: meta.status,
        joined_at: meta.joined_at,
        online: true
      }
    end)
  end
end

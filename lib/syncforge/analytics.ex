defmodule Syncforge.Analytics do
  @moduledoc """
  Context for recording and querying connection analytics.

  Provides functions to:
  - Record join/leave events
  - Query connections over time
  - Calculate peak concurrent users
  - Break down usage by room
  - Count daily active users
  """

  import Ecto.Query

  alias Syncforge.Repo
  alias Syncforge.Analytics.ConnectionEvent

  # --- Recording ---

  @doc """
  Records a connection event (join or leave).
  """
  def record_event(attrs) do
    %ConnectionEvent{}
    |> ConnectionEvent.changeset(attrs)
    |> Repo.insert()
  end

  # --- Querying ---

  @doc """
  Returns total connection events for an org within a time period.
  """
  def total_connections(org_id, since) do
    ConnectionEvent
    |> where([e], e.organization_id == ^org_id)
    |> where([e], e.event_type == "join")
    |> where([e], e.inserted_at >= ^since)
    |> Repo.aggregate(:count)
  end

  @doc """
  Returns unique users who joined any room in the org within a time period.
  """
  def unique_users(org_id, since) do
    ConnectionEvent
    |> where([e], e.organization_id == ^org_id)
    |> where([e], e.event_type == "join")
    |> where([e], e.inserted_at >= ^since)
    |> where([e], not is_nil(e.user_id))
    |> select([e], count(e.user_id, :distinct))
    |> Repo.one()
  end

  @doc """
  Returns the number of distinct rooms used in the org within a time period.
  """
  def active_rooms(org_id, since) do
    ConnectionEvent
    |> where([e], e.organization_id == ^org_id)
    |> where([e], e.event_type == "join")
    |> where([e], e.inserted_at >= ^since)
    |> where([e], not is_nil(e.room_id))
    |> select([e], count(e.room_id, :distinct))
    |> Repo.one()
  end

  @doc """
  Returns room usage breakdown: list of `{room_id, join_count}` sorted descending.
  """
  def room_usage_breakdown(org_id, since, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)

    ConnectionEvent
    |> where([e], e.organization_id == ^org_id)
    |> where([e], e.event_type == "join")
    |> where([e], e.inserted_at >= ^since)
    |> where([e], not is_nil(e.room_id))
    |> group_by([e], e.room_id)
    |> select([e], {e.room_id, count(e.id)})
    |> order_by([e], desc: count(e.id))
    |> limit(^limit)
    |> Repo.all()
  end

  @doc """
  Lists recent connection events for an org, newest first.
  """
  def list_recent_events(org_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    ConnectionEvent
    |> where([e], e.organization_id == ^org_id)
    |> order_by([e], desc: e.inserted_at)
    |> limit(^limit)
    |> preload([:user, :room])
    |> Repo.all()
  end

  # --- Period Helpers ---

  @doc """
  Returns a `DateTime` for the start of a given period relative to now.
  """
  def period_start("24h"), do: DateTime.add(DateTime.utc_now(), -24, :hour)
  def period_start("7d"), do: DateTime.add(DateTime.utc_now(), -7, :day)
  def period_start("30d"), do: DateTime.add(DateTime.utc_now(), -30, :day)
  def period_start(_), do: period_start("24h")
end

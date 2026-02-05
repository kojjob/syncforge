defmodule Syncforge.Notifications.NotificationPreference do
  @moduledoc """
  Schema for user notification preferences.

  Controls which notification types a user wants to receive and
  through which channels (email, push).

  ## Preference Types

  - `comment_mention` - When someone mentions you in a comment
  - `comment_reply` - When someone replies to your comment
  - `comment_resolved` - When your comment is marked resolved
  - `reaction_added` - When someone reacts to your comment
  - `room_invite` - When you're invited to a room
  - `user_joined` - When a new user joins a room you're in

  ## Delivery Channels

  - `email_enabled` - Receive email notifications
  - `push_enabled` - Receive push notifications (future)
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notification_preferences" do
    field :user_id, :binary_id

    # Per-type preferences
    field :comment_mention, :boolean, default: true
    field :comment_reply, :boolean, default: true
    field :comment_resolved, :boolean, default: true
    field :reaction_added, :boolean, default: true
    field :room_invite, :boolean, default: true
    field :user_joined, :boolean, default: true

    # Delivery channel preferences
    field :email_enabled, :boolean, default: true
    field :push_enabled, :boolean, default: true

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for creating notification preferences.
  """
  def changeset(preference, attrs) do
    preference
    |> cast(attrs, [
      :user_id,
      :comment_mention,
      :comment_reply,
      :comment_resolved,
      :reaction_added,
      :room_invite,
      :user_joined,
      :email_enabled,
      :push_enabled
    ])
    |> validate_required([:user_id])
    |> unique_constraint(:user_id)
  end

  @doc """
  Map notification type strings to their corresponding preference field.
  """
  def type_to_field(type) do
    case type do
      "comment_mention" -> :comment_mention
      "comment_reply" -> :comment_reply
      "comment_resolved" -> :comment_resolved
      "reaction_added" -> :reaction_added
      "room_invite" -> :room_invite
      "user_joined" -> :user_joined
      _ -> nil
    end
  end
end

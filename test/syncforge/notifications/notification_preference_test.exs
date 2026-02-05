defmodule Syncforge.Notifications.NotificationPreferenceTest do
  @moduledoc """
  Tests for notification preferences management.
  """

  use Syncforge.DataCase, async: true

  alias Syncforge.Notifications
  alias Syncforge.Notifications.NotificationPreference

  describe "notification_preferences" do
    setup do
      user_id = Ecto.UUID.generate()
      %{user_id: user_id}
    end

    test "get_or_create_preferences/1 creates default preferences for new user", %{
      user_id: user_id
    } do
      assert {:ok, %NotificationPreference{} = prefs} =
               Notifications.get_or_create_preferences(user_id)

      # All preferences should be enabled by default
      assert prefs.user_id == user_id
      assert prefs.comment_mention == true
      assert prefs.comment_reply == true
      assert prefs.comment_resolved == true
      assert prefs.reaction_added == true
      assert prefs.room_invite == true
      assert prefs.user_joined == true
      assert prefs.email_enabled == true
      assert prefs.push_enabled == true
    end

    test "get_or_create_preferences/1 returns existing preferences", %{user_id: user_id} do
      # Create preferences first
      {:ok, original} = Notifications.get_or_create_preferences(user_id)

      # Update a preference
      {:ok, _updated} =
        Notifications.update_preferences(original, %{comment_mention: false})

      # Get preferences again
      {:ok, fetched} = Notifications.get_or_create_preferences(user_id)

      # Should return existing preferences with our update
      assert fetched.id == original.id
      assert fetched.comment_mention == false
    end

    test "update_preferences/2 updates specific preferences", %{user_id: user_id} do
      {:ok, prefs} = Notifications.get_or_create_preferences(user_id)

      assert {:ok, updated} =
               Notifications.update_preferences(prefs, %{
                 comment_mention: false,
                 reaction_added: false,
                 email_enabled: false
               })

      assert updated.comment_mention == false
      assert updated.reaction_added == false
      assert updated.email_enabled == false
      # Others should remain true
      assert updated.comment_reply == true
      assert updated.push_enabled == true
    end

    test "should_notify?/2 returns true when preference is enabled", %{user_id: user_id} do
      {:ok, _prefs} = Notifications.get_or_create_preferences(user_id)

      assert Notifications.should_notify?(user_id, "comment_mention") == true
      assert Notifications.should_notify?(user_id, "comment_reply") == true
      assert Notifications.should_notify?(user_id, "reaction_added") == true
    end

    test "should_notify?/2 returns false when preference is disabled", %{user_id: user_id} do
      {:ok, prefs} = Notifications.get_or_create_preferences(user_id)

      {:ok, _updated} =
        Notifications.update_preferences(prefs, %{
          comment_mention: false,
          reaction_added: false
        })

      assert Notifications.should_notify?(user_id, "comment_mention") == false
      assert Notifications.should_notify?(user_id, "reaction_added") == false
      # Other types should still be true
      assert Notifications.should_notify?(user_id, "comment_reply") == true
    end

    test "should_notify?/2 returns true for unknown types (fail-open)", %{user_id: user_id} do
      {:ok, _prefs} = Notifications.get_or_create_preferences(user_id)

      # Unknown type should default to true (fail-open)
      assert Notifications.should_notify?(user_id, "unknown_type") == true
    end

    test "should_notify?/2 returns true when user has no preferences", %{} do
      # User with no preferences should receive all notifications (defaults)
      new_user_id = Ecto.UUID.generate()

      assert Notifications.should_notify?(new_user_id, "comment_mention") == true
      assert Notifications.should_notify?(new_user_id, "comment_reply") == true
    end

    test "get_preferences/1 returns nil for non-existent user" do
      non_existent_id = Ecto.UUID.generate()

      assert Notifications.get_preferences(non_existent_id) == nil
    end

    test "get_preferences/1 returns existing preferences", %{user_id: user_id} do
      {:ok, _prefs} = Notifications.get_or_create_preferences(user_id)

      fetched = Notifications.get_preferences(user_id)
      assert fetched != nil
      assert fetched.user_id == user_id
    end
  end

  describe "create_and_broadcast_notification with preferences" do
    setup do
      user_id = Ecto.UUID.generate()
      actor_id = Ecto.UUID.generate()
      %{user_id: user_id, actor_id: actor_id}
    end

    test "respects user preferences when creating notifications", %{
      user_id: user_id,
      actor_id: actor_id
    } do
      # Disable comment_mention notifications
      {:ok, prefs} = Notifications.get_or_create_preferences(user_id)

      {:ok, _updated} =
        Notifications.update_preferences(prefs, %{comment_mention: false})

      # Attempt to create a comment_mention notification
      result =
        Notifications.create_notification_with_preferences(%{
          type: "comment_mention",
          user_id: user_id,
          actor_id: actor_id,
          payload: %{"message" => "mentioned you"}
        })

      # Should be skipped due to preferences
      assert result == {:skipped, :preference_disabled}
    end

    test "creates notification when preference is enabled", %{
      user_id: user_id,
      actor_id: actor_id
    } do
      # Ensure preferences exist with defaults
      {:ok, _prefs} = Notifications.get_or_create_preferences(user_id)

      # Create notification with enabled preference
      {:ok, notification} =
        Notifications.create_notification_with_preferences(%{
          type: "comment_mention",
          user_id: user_id,
          actor_id: actor_id,
          payload: %{"message" => "mentioned you"}
        })

      assert notification.type == "comment_mention"
      assert notification.user_id == user_id
    end

    test "creates notification for user without preferences (defaults)", %{actor_id: actor_id} do
      # New user with no preferences record
      new_user_id = Ecto.UUID.generate()

      {:ok, notification} =
        Notifications.create_notification_with_preferences(%{
          type: "comment_reply",
          user_id: new_user_id,
          actor_id: actor_id,
          payload: %{"message" => "replied to your comment"}
        })

      assert notification.type == "comment_reply"
      assert notification.user_id == new_user_id
    end
  end
end

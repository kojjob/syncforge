defmodule Syncforge.ReactionsTest do
  @moduledoc """
  Tests for the Reactions context.
  """

  use Syncforge.DataCase, async: true

  alias Syncforge.Reactions
  alias Syncforge.Reactions.Reaction
  alias Syncforge.Comments
  alias Syncforge.Rooms

  describe "reactions" do
    setup do
      # Create a room first
      {:ok, room} =
        Rooms.create_room(%{
          name: "Test Room",
          type: "general"
        })

      user_id = Ecto.UUID.generate()

      # Create a comment to react to
      {:ok, comment} =
        Comments.create_comment(%{
          body: "Test comment for reactions",
          room_id: room.id,
          user_id: user_id
        })

      %{room: room, comment: comment, user_id: user_id}
    end

    test "add_reaction/1 creates a reaction with valid data", %{
      comment: comment,
      user_id: user_id
    } do
      attrs = %{
        emoji: "👍",
        comment_id: comment.id,
        user_id: user_id
      }

      assert {:ok, %Reaction{} = reaction} = Reactions.add_reaction(attrs)
      assert reaction.emoji == "👍"
      assert reaction.comment_id == comment.id
      assert reaction.user_id == user_id
    end

    test "add_reaction/1 returns error with missing emoji", %{comment: comment, user_id: user_id} do
      attrs = %{
        comment_id: comment.id,
        user_id: user_id
      }

      assert {:error, changeset} = Reactions.add_reaction(attrs)
      assert %{emoji: ["can't be blank"]} = errors_on(changeset)
    end

    test "add_reaction/1 returns error with missing comment_id", %{user_id: user_id} do
      attrs = %{
        emoji: "👍",
        user_id: user_id
      }

      assert {:error, changeset} = Reactions.add_reaction(attrs)
      assert %{comment_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "add_reaction/1 returns error with missing user_id", %{comment: comment} do
      attrs = %{
        emoji: "👍",
        comment_id: comment.id
      }

      assert {:error, changeset} = Reactions.add_reaction(attrs)
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "add_reaction/1 prevents duplicate reactions (same user, comment, emoji)", %{
      comment: comment,
      user_id: user_id
    } do
      attrs = %{
        emoji: "👍",
        comment_id: comment.id,
        user_id: user_id
      }

      assert {:ok, _reaction} = Reactions.add_reaction(attrs)
      assert {:error, changeset} = Reactions.add_reaction(attrs)
      assert %{comment_id: ["you already reacted with this emoji"]} = errors_on(changeset)
    end

    test "add_reaction/1 allows same user to add different emojis", %{
      comment: comment,
      user_id: user_id
    } do
      assert {:ok, reaction1} =
               Reactions.add_reaction(%{
                 emoji: "👍",
                 comment_id: comment.id,
                 user_id: user_id
               })

      assert {:ok, reaction2} =
               Reactions.add_reaction(%{
                 emoji: "❤️",
                 comment_id: comment.id,
                 user_id: user_id
               })

      assert reaction1.emoji == "👍"
      assert reaction2.emoji == "❤️"
    end

    test "add_reaction/1 allows different users to add same emoji", %{comment: comment} do
      user1_id = Ecto.UUID.generate()
      user2_id = Ecto.UUID.generate()

      assert {:ok, reaction1} =
               Reactions.add_reaction(%{
                 emoji: "👍",
                 comment_id: comment.id,
                 user_id: user1_id
               })

      assert {:ok, reaction2} =
               Reactions.add_reaction(%{
                 emoji: "👍",
                 comment_id: comment.id,
                 user_id: user2_id
               })

      assert reaction1.user_id == user1_id
      assert reaction2.user_id == user2_id
    end

    test "remove_reaction/1 deletes a reaction", %{comment: comment, user_id: user_id} do
      {:ok, reaction} =
        Reactions.add_reaction(%{
          emoji: "👍",
          comment_id: comment.id,
          user_id: user_id
        })

      assert {:ok, %Reaction{}} = Reactions.remove_reaction(reaction)
      assert Reactions.get_reaction(reaction.id) == nil
    end

    test "remove_reaction/3 removes by comment_id, user_id, and emoji", %{
      comment: comment,
      user_id: user_id
    } do
      {:ok, _reaction} =
        Reactions.add_reaction(%{
          emoji: "👍",
          comment_id: comment.id,
          user_id: user_id
        })

      assert {:ok, %Reaction{}} = Reactions.remove_reaction(comment.id, user_id, "👍")
      assert Reactions.list_reactions(comment.id) == []
    end

    test "remove_reaction/3 returns error when reaction doesn't exist", %{
      comment: comment,
      user_id: user_id
    } do
      assert {:error, :not_found} = Reactions.remove_reaction(comment.id, user_id, "👍")
    end

    test "toggle_reaction/1 adds reaction if it doesn't exist", %{
      comment: comment,
      user_id: user_id
    } do
      attrs = %{
        emoji: "👍",
        comment_id: comment.id,
        user_id: user_id
      }

      assert {:ok, :added, %Reaction{} = reaction} = Reactions.toggle_reaction(attrs)
      assert reaction.emoji == "👍"
    end

    test "toggle_reaction/1 removes reaction if it exists", %{comment: comment, user_id: user_id} do
      attrs = %{
        emoji: "👍",
        comment_id: comment.id,
        user_id: user_id
      }

      {:ok, :added, _reaction} = Reactions.toggle_reaction(attrs)
      assert {:ok, :removed, %Reaction{}} = Reactions.toggle_reaction(attrs)
      assert Reactions.list_reactions(comment.id) == []
    end

    test "list_reactions/1 returns all reactions for a comment", %{comment: comment} do
      user1_id = Ecto.UUID.generate()
      user2_id = Ecto.UUID.generate()

      {:ok, _} =
        Reactions.add_reaction(%{emoji: "👍", comment_id: comment.id, user_id: user1_id})

      {:ok, _} =
        Reactions.add_reaction(%{emoji: "❤️", comment_id: comment.id, user_id: user2_id})

      reactions = Reactions.list_reactions(comment.id)
      assert length(reactions) == 2
    end

    test "list_reactions/1 returns empty list when no reactions", %{comment: comment} do
      assert Reactions.list_reactions(comment.id) == []
    end

    test "count_reactions/1 returns reaction counts grouped by emoji", %{comment: comment} do
      user1_id = Ecto.UUID.generate()
      user2_id = Ecto.UUID.generate()
      user3_id = Ecto.UUID.generate()

      {:ok, _} =
        Reactions.add_reaction(%{emoji: "👍", comment_id: comment.id, user_id: user1_id})

      {:ok, _} =
        Reactions.add_reaction(%{emoji: "👍", comment_id: comment.id, user_id: user2_id})

      {:ok, _} =
        Reactions.add_reaction(%{emoji: "❤️", comment_id: comment.id, user_id: user3_id})

      counts = Reactions.count_reactions(comment.id)
      assert counts["👍"] == 2
      assert counts["❤️"] == 1
    end

    test "count_reactions/1 returns empty map when no reactions", %{comment: comment} do
      assert Reactions.count_reactions(comment.id) == %{}
    end

    test "get_reaction/1 returns reaction by id", %{comment: comment, user_id: user_id} do
      {:ok, reaction} =
        Reactions.add_reaction(%{emoji: "👍", comment_id: comment.id, user_id: user_id})

      assert Reactions.get_reaction(reaction.id) == reaction
    end

    test "get_reaction/1 returns nil for non-existent id", %{} do
      assert Reactions.get_reaction(Ecto.UUID.generate()) == nil
    end

    test "get_user_reaction/3 returns user's reaction for specific emoji", %{
      comment: comment,
      user_id: user_id
    } do
      {:ok, reaction} =
        Reactions.add_reaction(%{emoji: "👍", comment_id: comment.id, user_id: user_id})

      assert Reactions.get_user_reaction(comment.id, user_id, "👍") == reaction
    end

    test "get_user_reaction/3 returns nil when user hasn't reacted", %{
      comment: comment,
      user_id: user_id
    } do
      assert Reactions.get_user_reaction(comment.id, user_id, "👍") == nil
    end

    test "list_user_reactions/2 returns all reactions by a user on a comment", %{
      comment: comment,
      user_id: user_id
    } do
      {:ok, _} =
        Reactions.add_reaction(%{emoji: "👍", comment_id: comment.id, user_id: user_id})

      {:ok, _} =
        Reactions.add_reaction(%{emoji: "❤️", comment_id: comment.id, user_id: user_id})

      reactions = Reactions.list_user_reactions(comment.id, user_id)
      assert length(reactions) == 2
      assert Enum.map(reactions, & &1.emoji) |> Enum.sort() == ["❤️", "👍"]
    end

    test "reactions are deleted when comment is deleted", %{
      comment: comment,
      user_id: user_id
    } do
      {:ok, reaction} =
        Reactions.add_reaction(%{emoji: "👍", comment_id: comment.id, user_id: user_id})

      {:ok, _} = Comments.delete_comment(comment)

      assert Reactions.get_reaction(reaction.id) == nil
    end

    test "count_reactions_for_comments/1 returns empty map for empty list" do
      assert Reactions.count_reactions_for_comments([]) == %{}
    end

    test "count_reactions_for_comments/1 returns reactions grouped by comment_id", %{room: room} do
      user1_id = Ecto.UUID.generate()
      user2_id = Ecto.UUID.generate()
      user3_id = Ecto.UUID.generate()

      # Create two comments
      {:ok, comment1} =
        Comments.create_comment(%{
          body: "First comment",
          room_id: room.id,
          user_id: user1_id
        })

      {:ok, comment2} =
        Comments.create_comment(%{
          body: "Second comment",
          room_id: room.id,
          user_id: user1_id
        })

      # Add reactions to first comment
      {:ok, _} = Reactions.add_reaction(%{emoji: "👍", comment_id: comment1.id, user_id: user1_id})
      {:ok, _} = Reactions.add_reaction(%{emoji: "👍", comment_id: comment1.id, user_id: user2_id})
      {:ok, _} = Reactions.add_reaction(%{emoji: "❤️", comment_id: comment1.id, user_id: user3_id})

      # Add reactions to second comment
      {:ok, _} = Reactions.add_reaction(%{emoji: "🎉", comment_id: comment2.id, user_id: user1_id})

      # Batch query
      result = Reactions.count_reactions_for_comments([comment1.id, comment2.id])

      assert result[comment1.id]["👍"] == 2
      assert result[comment1.id]["❤️"] == 1
      assert result[comment2.id]["🎉"] == 1
    end

    test "count_reactions_for_comments/1 handles comments without reactions", %{room: room} do
      user_id = Ecto.UUID.generate()

      {:ok, comment_with_reactions} =
        Comments.create_comment(%{
          body: "Has reactions",
          room_id: room.id,
          user_id: user_id
        })

      {:ok, comment_without_reactions} =
        Comments.create_comment(%{
          body: "No reactions",
          room_id: room.id,
          user_id: user_id
        })

      {:ok, _} =
        Reactions.add_reaction(%{
          emoji: "👍",
          comment_id: comment_with_reactions.id,
          user_id: user_id
        })

      result =
        Reactions.count_reactions_for_comments([
          comment_with_reactions.id,
          comment_without_reactions.id
        ])

      # Comment with reactions is included
      assert result[comment_with_reactions.id]["👍"] == 1

      # Comment without reactions is not in the map (or returns nil)
      assert Map.get(result, comment_without_reactions.id) == nil
    end
  end
end

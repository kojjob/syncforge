defmodule Syncforge.CommentsTest do
  use Syncforge.DataCase, async: true

  alias Syncforge.Comments

  describe "list_comments/2 pagination" do
    setup do
      {:ok, room} = Syncforge.Rooms.create_room(%{name: "Pagination Test Room", is_public: true})
      user_id = Ecto.UUID.generate()

      # Create 5 comments
      comments =
        for i <- 1..5 do
          {:ok, comment} =
            Comments.create_comment(%{
              body: "Comment #{i}",
              room_id: room.id,
              user_id: user_id
            })

          comment
        end

      # Sort comments the same way the query does: inserted_at asc, id asc
      # This ensures our expected order matches the database ordering
      sorted_comments =
        Enum.sort_by(comments, fn c -> {c.inserted_at, c.id} end)

      %{room: room, comments: sorted_comments, user_id: user_id}
    end

    test "returns all comments when no limit or offset is given", %{
      room: room,
      comments: comments
    } do
      result = Comments.list_comments(room.id)
      assert length(result) == 5
      assert Enum.map(result, & &1.id) == Enum.map(comments, & &1.id)
    end

    test "respects :limit option", %{room: room, comments: comments} do
      result = Comments.list_comments(room.id, limit: 3)
      assert length(result) == 3

      # Should return the first 3 comments (ordered by inserted_at asc, id asc)
      expected_ids = comments |> Enum.take(3) |> Enum.map(& &1.id)
      assert Enum.map(result, & &1.id) == expected_ids
    end

    test "respects :offset option", %{room: room, comments: comments} do
      result = Comments.list_comments(room.id, offset: 2)
      # Should skip first 2, return remaining 3
      assert length(result) == 3

      expected_ids = comments |> Enum.drop(2) |> Enum.map(& &1.id)
      assert Enum.map(result, & &1.id) == expected_ids
    end

    test "respects both :limit and :offset options together", %{room: room, comments: comments} do
      result = Comments.list_comments(room.id, limit: 2, offset: 1)
      assert length(result) == 2

      # Skip 1, take 2 -> comments at index 1 and 2
      expected_ids = comments |> Enum.slice(1, 2) |> Enum.map(& &1.id)
      assert Enum.map(result, & &1.id) == expected_ids
    end

    test ":offset defaults to 0 when only :limit is given", %{room: room, comments: comments} do
      result = Comments.list_comments(room.id, limit: 2)
      assert length(result) == 2

      expected_ids = comments |> Enum.take(2) |> Enum.map(& &1.id)
      assert Enum.map(result, & &1.id) == expected_ids
    end

    test "returns empty list when offset exceeds total comments", %{room: room} do
      result = Comments.list_comments(room.id, offset: 100)
      assert result == []
    end

    test "limit greater than total comments returns all comments", %{
      room: room,
      comments: comments
    } do
      result = Comments.list_comments(room.id, limit: 100)
      assert length(result) == 5
      assert Enum.map(result, & &1.id) == Enum.map(comments, & &1.id)
    end

    test "pagination works with :include_resolved option", %{room: room, comments: comments} do
      # Resolve the first 2 comments (in sorted order)
      {:ok, _} = Comments.resolve_comment(Enum.at(comments, 0))
      {:ok, _} = Comments.resolve_comment(Enum.at(comments, 1))

      # Without resolved, we have 3 unresolved comments (indices 2, 3, 4 from sorted)
      result = Comments.list_comments(room.id, include_resolved: false, limit: 2)
      assert length(result) == 2

      # The first 2 unresolved comments should be at sorted indices 2 and 3
      expected_ids = comments |> Enum.slice(2, 2) |> Enum.map(& &1.id)
      assert Enum.map(result, & &1.id) == expected_ids
    end
  end
end

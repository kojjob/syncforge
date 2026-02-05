defmodule Syncforge.Reactions.Reaction do
  @moduledoc """
  Represents a reaction (emoji) on a comment.

  Reactions allow users to quickly respond to comments with emoji.
  Each user can add multiple different emojis to a comment, but
  only one reaction per emoji type per user per comment is allowed.

  ## Constraints

  - A user cannot react with the same emoji twice on the same comment
  - Reactions are deleted when the parent comment is deleted (cascade)
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Syncforge.Comments.Comment

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "reactions" do
    field :emoji, :string
    field :user_id, :binary_id

    belongs_to :comment, Comment

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a changeset for creating a new reaction.
  """
  def create_changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:emoji, :comment_id, :user_id])
    |> validate_required([:emoji, :comment_id, :user_id])
    |> validate_length(:emoji, min: 1, max: 10)
    |> foreign_key_constraint(:comment_id)
    |> unique_constraint([:comment_id, :user_id, :emoji],
      name: :reactions_comment_id_user_id_emoji_index,
      message: "you already reacted with this emoji"
    )
  end
end

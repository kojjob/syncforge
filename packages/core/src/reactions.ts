/**
 * ReactionManager — typed API for emoji reactions on comments.
 *
 * Wraps the reaction:* channel events.
 */

import type { Reaction, RoomEventMap } from "./types.js";
import type { Room } from "./room.js";

export class ReactionManager {
  private _room: Room;

  constructor(room: Room) {
    this._room = room;
  }

  /** Add an emoji reaction to a comment. */
  async add(commentId: string, emoji: string): Promise<Reaction> {
    const resp = (await this._room.push("reaction:add", {
      comment_id: commentId,
      emoji,
    })) as { reaction: Reaction };
    return resp.reaction;
  }

  /** Remove an emoji reaction from a comment. */
  async remove(commentId: string, emoji: string): Promise<void> {
    await this._room.push("reaction:remove", {
      comment_id: commentId,
      emoji,
    });
  }

  /** Toggle a reaction — adds if not present, removes if already present. */
  async toggle(
    commentId: string,
    emoji: string
  ): Promise<{ action: "added" | "removed"; reaction?: Reaction }> {
    const resp = (await this._room.push("reaction:toggle", {
      comment_id: commentId,
      emoji,
    })) as { action: "added" | "removed"; reaction?: Reaction };
    return resp;
  }

  /** Subscribe to reaction added events. */
  onAdded(cb: (reaction: Reaction) => void): () => void {
    return this._room.on("reaction:added", ({ reaction }) => cb(reaction));
  }

  /** Subscribe to reaction removed events. */
  onRemoved(
    cb: (data: RoomEventMap["reaction:removed"]) => void
  ): () => void {
    return this._room.on("reaction:removed", (data) => cb(data));
  }
}

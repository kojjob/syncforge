/**
 * CommentManager — typed API for comment CRUD and real-time sync.
 *
 * Wraps the comment:* channel events with Promise-based responses.
 */

import type { Comment } from "./types.js";
import type { Room } from "./room.js";

export interface CreateCommentParams {
  body: string;
  anchor_id?: string;
  anchor_type?: "element" | "selection" | "point";
  position?: Record<string, unknown>;
  parent_id?: string;
}

export interface UpdateCommentParams {
  id: string;
  body?: string;
  anchor_id?: string;
  anchor_type?: "element" | "selection" | "point";
  position?: Record<string, unknown>;
}

export class CommentManager {
  private _room: Room;

  constructor(room: Room) {
    this._room = room;
  }

  /** Get current comments (hydrated from room_state and real-time updates). */
  get comments(): Comment[] {
    return this._room.comments;
  }

  /** Create a new comment in the room. */
  async create(params: CreateCommentParams): Promise<Comment> {
    const resp = (await this._room.push("comment:create", params as unknown as Record<string, unknown>)) as {
      comment: Comment;
    };
    return resp.comment;
  }

  /** Update an existing comment (only the comment owner can update). */
  async update(params: UpdateCommentParams): Promise<Comment> {
    const resp = (await this._room.push("comment:update", params as unknown as Record<string, unknown>)) as {
      comment: Comment;
    };
    return resp.comment;
  }

  /** Delete a comment (only the comment owner can delete). */
  async delete(commentId: string): Promise<void> {
    await this._room.push("comment:delete", { id: commentId });
  }

  /** Resolve a comment thread. */
  async resolve(commentId: string): Promise<Comment> {
    const resp = (await this._room.push("comment:resolve", {
      id: commentId,
      resolved: true,
    })) as { comment: Comment };
    return resp.comment;
  }

  /** Unresolve a comment thread. */
  async unresolve(commentId: string): Promise<Comment> {
    const resp = (await this._room.push("comment:resolve", {
      id: commentId,
      resolved: false,
    })) as { comment: Comment };
    return resp.comment;
  }

  /** Subscribe to comment events. Delegates to Room event emitter. */
  onCreated(cb: (comment: Comment) => void): () => void {
    return this._room.on("comment:created", ({ comment }) => cb(comment));
  }

  onUpdated(cb: (comment: Comment) => void): () => void {
    return this._room.on("comment:updated", ({ comment }) => cb(comment));
  }

  onDeleted(cb: (commentId: string) => void): () => void {
    return this._room.on("comment:deleted", ({ comment_id }) =>
      cb(comment_id)
    );
  }

  onResolved(cb: (comment: Comment) => void): () => void {
    return this._room.on("comment:resolved", ({ comment }) => cb(comment));
  }
}

/**
 * Room — wraps a Phoenix Channel for a collaboration room.
 *
 * Provides typed event subscription and manages the room lifecycle.
 * Feature managers (presence, cursors, comments, etc.) compose onto this.
 */

import type { Channel, Push } from "phoenix";
import { TypedEventEmitter } from "./events.js";
import type { Comment, RoomEventMap, RoomState } from "./types.js";

export class Room extends TypedEventEmitter<RoomEventMap> {
  readonly roomId: string;
  private _channel: Channel;
  private _joined = false;
  private _comments: Comment[] = [];

  constructor(channel: Channel, roomId: string) {
    super();
    this._channel = channel;
    this.roomId = roomId;
    this._setupListeners();
  }

  /** The underlying Phoenix Channel */
  get channel(): Channel {
    return this._channel;
  }

  /** Whether the room has been successfully joined */
  get joined(): boolean {
    return this._joined;
  }

  /** Current comments loaded from room state */
  get comments(): Comment[] {
    return this._comments;
  }

  /**
   * Join the room channel.
   * Resolves with the join response, rejects on error/timeout.
   */
  join(): Promise<Record<string, unknown>> {
    return new Promise((resolve, reject) => {
      this._channel
        .join()
        .receive("ok", (response: unknown) => {
          this._joined = true;
          this.emit("joined", {
            response: response as Record<string, unknown>,
          });
          resolve(response as Record<string, unknown>);
        })
        .receive("error", (response: unknown) => {
          const resp = response as Record<string, unknown>;
          this.emit("error", {
            reason: (resp.reason as string) ?? "join_failed",
          });
          reject(resp);
        })
        .receive("timeout", () => {
          this.emit("error", { reason: "timeout" });
          reject(new Error("Join timed out"));
        });
    });
  }

  /** Leave the room channel and clean up. */
  leave(): void {
    this._channel.leave();
    this._joined = false;
    this._comments = [];
    this.emit("left");
    this.removeAllListeners();
  }

  /**
   * Push an event to the server channel.
   * Returns a promise that resolves with the server response.
   */
  push(event: string, payload: Record<string, unknown> = {}): Promise<unknown> {
    return new Promise((resolve, reject) => {
      this._channel
        .push(event, payload)
        .receive("ok", (resp: unknown) => resolve(resp))
        .receive("error", (resp: unknown) => reject(resp))
        .receive("timeout", () => reject(new Error("Push timed out")));
    });
  }

  /**
   * Send typing:start indicator.
   */
  startTyping(): void {
    this._channel.push("typing:start", {});
  }

  /**
   * Send typing:stop indicator.
   */
  stopTyping(): void {
    this._channel.push("typing:stop", {});
  }

  private _setupListeners(): void {
    // Room state hydration on join
    this._channel.on("room_state", (payload: unknown) => {
      const state = payload as RoomState;
      this._comments = state.comments ?? [];
      this.emit("room:state", state);
    });

    // Cursor updates from other users
    this._channel.on("cursor:update", (payload: unknown) => {
      this.emit("cursor:update", payload as RoomEventMap["cursor:update"]);
    });

    // Selection updates
    this._channel.on("selection:update", (payload: unknown) => {
      this.emit(
        "selection:update",
        payload as RoomEventMap["selection:update"]
      );
    });

    // Typing indicators
    this._channel.on("typing:start", (payload: unknown) => {
      this.emit("typing:start", payload as RoomEventMap["typing:start"]);
    });
    this._channel.on("typing:stop", (payload: unknown) => {
      this.emit("typing:stop", payload as RoomEventMap["typing:stop"]);
    });

    // Comment events
    this._channel.on("comment:created", (payload: unknown) => {
      const data = payload as RoomEventMap["comment:created"];
      this._comments.push(data.comment);
      this.emit("comment:created", data);
    });
    this._channel.on("comment:updated", (payload: unknown) => {
      const data = payload as RoomEventMap["comment:updated"];
      const idx = this._comments.findIndex((c) => c.id === data.comment.id);
      if (idx !== -1) this._comments[idx] = data.comment;
      this.emit("comment:updated", data);
    });
    this._channel.on("comment:deleted", (payload: unknown) => {
      const data = payload as RoomEventMap["comment:deleted"];
      this._comments = this._comments.filter(
        (c) => c.id !== data.comment_id
      );
      this.emit("comment:deleted", data);
    });
    this._channel.on("comment:resolved", (payload: unknown) => {
      const data = payload as RoomEventMap["comment:resolved"];
      const idx = this._comments.findIndex((c) => c.id === data.comment.id);
      if (idx !== -1) this._comments[idx] = data.comment;
      this.emit("comment:resolved", data);
    });

    // Reaction events
    this._channel.on("reaction:added", (payload: unknown) => {
      this.emit("reaction:added", payload as RoomEventMap["reaction:added"]);
    });
    this._channel.on("reaction:removed", (payload: unknown) => {
      this.emit(
        "reaction:removed",
        payload as RoomEventMap["reaction:removed"]
      );
    });

    // Activity events
    this._channel.on("activity:created", (payload: unknown) => {
      this.emit(
        "activity:created",
        payload as RoomEventMap["activity:created"]
      );
    });
  }
}

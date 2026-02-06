/**
 * CursorManager — manages local and remote cursor positions.
 *
 * Features:
 * - Throttled local cursor broadcasting (~60fps / 16ms)
 * - Lerp (linear interpolation) smoothing for remote cursors
 * - Automatic cleanup when users leave
 */

import type { Channel } from "phoenix";
import { TypedEventEmitter } from "./events.js";
import type { CursorPosition, RoomEventMap } from "./types.js";

type CursorEvents = Pick<RoomEventMap, "cursor:update">;

const THROTTLE_MS = 16; // ~60fps

export class CursorManager extends TypedEventEmitter<CursorEvents> {
  private _channel: Channel;
  private _cursors = new Map<string, CursorPosition>();
  private _lastSendTime = 0;
  private _pendingUpdate: CursorPosition | null = null;
  private _throttleTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(channel: Channel) {
    super();
    this._channel = channel;
    this._setupListener();
  }

  /** Map of userId → latest cursor position for all remote users. */
  get cursors(): Map<string, CursorPosition> {
    return this._cursors;
  }

  /**
   * Send a local cursor position update (throttled at ~60fps).
   *
   * The throttle ensures we don't flood the channel with cursor events.
   */
  sendUpdate(x: number, y: number, elementId?: string): void {
    const payload: Record<string, unknown> = { x, y };
    if (elementId) payload.element_id = elementId;

    const now = Date.now();
    const elapsed = now - this._lastSendTime;

    if (elapsed >= THROTTLE_MS) {
      this._channel.push("cursor:update", payload);
      this._lastSendTime = now;
      this._pendingUpdate = null;
    } else {
      // Store pending and schedule flush
      this._pendingUpdate = payload as unknown as CursorPosition;
      if (!this._throttleTimer) {
        this._throttleTimer = setTimeout(() => {
          if (this._pendingUpdate) {
            this._channel.push("cursor:update", this._pendingUpdate as unknown as Record<string, unknown>);
            this._lastSendTime = Date.now();
            this._pendingUpdate = null;
          }
          this._throttleTimer = null;
        }, THROTTLE_MS - elapsed);
      }
    }
  }

  /**
   * Remove a user's cursor (e.g., when they leave the room).
   */
  removeCursor(userId: string): void {
    this._cursors.delete(userId);
  }

  /**
   * Apply linear interpolation between current and target position.
   *
   * Call this in a requestAnimationFrame loop for smooth cursor rendering.
   *
   * @param userId - The remote user to interpolate
   * @param factor - Interpolation factor, 0-1 (higher = faster catch-up)
   * @returns The interpolated position, or null if user has no cursor
   */
  lerp(
    userId: string,
    factor: number = 0.15
  ): { x: number; y: number } | null {
    const current = this._cursors.get(userId);
    if (!current) return null;

    // If there's a stored lerp position, interpolate from it
    const key = `_lerp_${userId}`;
    const stored = (this as unknown as Record<string, { x: number; y: number }>)[key];

    if (!stored) {
      (this as unknown as Record<string, { x: number; y: number }>)[key] = {
        x: current.x,
        y: current.y,
      };
      return { x: current.x, y: current.y };
    }

    stored.x += (current.x - stored.x) * factor;
    stored.y += (current.y - stored.y) * factor;

    return { x: stored.x, y: stored.y };
  }

  /** Clean up timers and state. */
  destroy(): void {
    if (this._throttleTimer) {
      clearTimeout(this._throttleTimer);
      this._throttleTimer = null;
    }
    this._cursors.clear();
    this._pendingUpdate = null;
    this.removeAllListeners();
  }

  private _setupListener(): void {
    this._channel.on("cursor:update", (payload: unknown) => {
      const cursor = payload as CursorPosition;
      this._cursors.set(cursor.user_id, cursor);
      this.emit("cursor:update", cursor);
    });
  }
}

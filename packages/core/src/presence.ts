/**
 * PresenceManager — wraps Phoenix Presence for a room channel.
 *
 * Tracks who is in the room and emits typed events for joins/leaves/syncs.
 */

import type { Channel, Presence as PhoenixPresence } from "phoenix";
import { TypedEventEmitter } from "./events.js";
import type { PresenceUser, RoomEventMap } from "./types.js";

type PresenceEvents = Pick<
  RoomEventMap,
  "presence:sync" | "presence:join" | "presence:leave"
>;

export class PresenceManager extends TypedEventEmitter<PresenceEvents> {
  private _presence: PhoenixPresence | null = null;
  private _users: PresenceUser[] = [];

  /** Current list of present users */
  get users(): PresenceUser[] {
    return this._users;
  }

  /**
   * Initialize presence tracking on a channel.
   *
   * Dynamically imports `phoenix` to access the Presence class.
   */
  async attach(channel: Channel): Promise<void> {
    const { Presence } = await import("phoenix");
    this._presence = new Presence(channel);

    this._presence.onSync(() => {
      this._users = this._presence!.list(
        (_id: string, presence: { metas: Record<string, unknown>[] }) =>
          presence.metas[0] as unknown as PresenceUser
      );
      this.emit("presence:sync", { users: this._users });
    });

    this._presence.onJoin(
      (
        _id: string,
        _current: { metas: Record<string, unknown>[] } | undefined,
        newPres: { metas: Record<string, unknown>[] }
      ) => {
        const user = newPres.metas[0] as unknown as PresenceUser;
        this.emit("presence:join", { user });
      }
    );

    this._presence.onLeave(
      (
        _id: string,
        _current: { metas: Record<string, unknown>[] } | undefined,
        leftPres: { metas: Record<string, unknown>[] }
      ) => {
        const user = leftPres.metas[0] as unknown as PresenceUser;
        this.emit("presence:leave", { user });
      }
    );
  }

  /** Detach presence tracking and clean up. */
  detach(): void {
    this._presence = null;
    this._users = [];
    this.removeAllListeners();
  }

  /** Update local presence metadata (e.g., status, cursor_visible). */
  updatePresence(
    channel: Channel,
    updates: Record<string, unknown>
  ): void {
    channel.push("presence:update", updates);
  }
}

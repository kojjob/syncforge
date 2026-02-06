/**
 * ActivityManager — typed API for room activity feed.
 *
 * Wraps the activity:list and activity:created channel events.
 */

import type { Activity } from "./types.js";
import type { Room } from "./room.js";

export interface ListActivitiesOptions {
  limit?: number;
  offset?: number;
}

export class ActivityManager {
  private _room: Room;

  constructor(room: Room) {
    this._room = room;
  }

  /** Fetch paginated activity list from the server. */
  async list(options: ListActivitiesOptions = {}): Promise<Activity[]> {
    const resp = (await this._room.push("activity:list", {
      limit: options.limit ?? 50,
      offset: options.offset ?? 0,
    })) as { activities: Activity[] };
    return resp.activities;
  }

  /** Subscribe to new activity events (real-time). */
  onCreated(cb: (activity: Activity) => void): () => void {
    return this._room.on("activity:created", ({ activity }) => cb(activity));
  }
}

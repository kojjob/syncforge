/**
 * SelectionManager — manages local and remote selection state.
 *
 * Selections are text/element selections that other users can see,
 * enabling collaborative editing awareness.
 */

import type { Channel } from "phoenix";
import { TypedEventEmitter } from "./events.js";
import type { RoomEventMap, Selection } from "./types.js";

type SelectionEvents = Pick<RoomEventMap, "selection:update">;

export class SelectionManager extends TypedEventEmitter<SelectionEvents> {
  private _channel: Channel;
  private _selections = new Map<string, Selection>();
  private _listenerRef: number = 0;

  constructor(channel: Channel) {
    super();
    this._channel = channel;
    this._setupListener();
  }

  /** Map of userId → current selection for all remote users. */
  get selections(): Map<string, Selection> {
    return this._selections;
  }

  /**
   * Broadcast the local user's current selection.
   */
  sendUpdate(selection: unknown, elementId?: string): void {
    const payload: Record<string, unknown> = { selection };
    if (elementId) payload.element_id = elementId;
    this._channel.push("selection:update", payload);
  }

  /**
   * Clear the local user's selection (broadcast empty).
   */
  clearSelection(): void {
    this._channel.push("selection:update", { selection: null });
  }

  /**
   * Remove a user's selection (e.g., when they leave).
   */
  removeSelection(userId: string): void {
    this._selections.delete(userId);
  }

  /** Clean up state and channel listeners. */
  destroy(): void {
    this._channel.off("selection:update", this._listenerRef);
    this._selections.clear();
    this.removeAllListeners();
  }

  private _setupListener(): void {
    this._listenerRef = this._channel.on("selection:update", (payload: unknown) => {
      const sel = payload as Selection;
      if (sel.selection === null) {
        this._selections.delete(sel.user_id);
      } else {
        this._selections.set(sel.user_id, sel);
      }
      this.emit("selection:update", sel);
    });
  }
}

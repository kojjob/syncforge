/**
 * NotificationManager — manages the user's notification channel.
 *
 * Uses a separate Phoenix Channel ("notification:{userId}") from the room channel.
 */

import type { Channel } from "phoenix";
import { TypedEventEmitter } from "./events.js";
import type { Notification, NotificationEventMap } from "./types.js";

export class NotificationManager extends TypedEventEmitter<NotificationEventMap> {
  private _channel: Channel;
  private _joined = false;
  private _unreadCount = 0;

  constructor(channel: Channel) {
    super();
    this._channel = channel;
    this._setupListeners();
  }

  /** Current unread notification count */
  get unreadCount(): number {
    return this._unreadCount;
  }

  /** Whether the notification channel has been joined */
  get joined(): boolean {
    return this._joined;
  }

  /**
   * Join the notification channel.
   * Resolves with the initial unread count.
   */
  join(): Promise<{ unread_count: number }> {
    return new Promise((resolve, reject) => {
      this._channel
        .join()
        .receive("ok", (response: unknown) => {
          const resp = response as { unread_count: number };
          this._joined = true;
          this._unreadCount = resp.unread_count;
          resolve(resp);
        })
        .receive("error", (response: unknown) => {
          reject(response);
        })
        .receive("timeout", () => {
          reject(new Error("Notification channel join timed out"));
        });
    });
  }

  /** Leave the notification channel. */
  leave(): void {
    this._channel.leave();
    this._joined = false;
    this._unreadCount = 0;
    this.removeAllListeners();
  }

  /** Fetch paginated list of notifications. */
  list(
    options: { limit?: number; offset?: number } = {}
  ): Promise<{ notifications: Notification[]; total_unread: number }> {
    return new Promise((resolve, reject) => {
      this._channel
        .push("notification:list", {
          limit: options.limit ?? 20,
          offset: options.offset ?? 0,
        })
        .receive("ok", (response: unknown) => {
          const resp = response as {
            notifications: Notification[];
            total_unread: number;
          };
          this._unreadCount = resp.total_unread;
          resolve(resp);
        })
        .receive("error", (resp: unknown) => reject(resp));
    });
  }

  /** Mark a specific notification as read. */
  markRead(notificationId: string): Promise<Notification> {
    return new Promise((resolve, reject) => {
      this._channel
        .push("notification:mark_read", { id: notificationId })
        .receive("ok", (response: unknown) => {
          const resp = response as { notification: Notification };
          resolve(resp.notification);
        })
        .receive("error", (resp: unknown) => reject(resp));
    });
  }

  /** Mark all notifications as read. */
  markAllRead(): Promise<{ count: number }> {
    return new Promise((resolve, reject) => {
      this._channel
        .push("notification:mark_all_read", {})
        .receive("ok", (response: unknown) => {
          const resp = response as { count: number };
          this._unreadCount = 0;
          resolve(resp);
        })
        .receive("error", (resp: unknown) => reject(resp));
    });
  }

  private _setupListeners(): void {
    this._channel.on("notification:new", (payload: unknown) => {
      const notification = payload as Notification;
      this._unreadCount++;
      this.emit("notification:new", notification);
    });

    this._channel.on("notification:unread_count", (payload: unknown) => {
      const data = payload as { count: number };
      this._unreadCount = data.count;
      this.emit("notification:unread_count", data);
    });
  }
}

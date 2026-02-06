// @syncforge/core — public API

export { SyncForgeClient } from "./client.js";
export type { JoinRoomResult, JoinNotificationResult } from "./client.js";

export { TypedEventEmitter } from "./events.js";

export type {
  User,
  PresenceUser,
  Comment,
  Reaction,
  Notification,
  Activity,
  CursorPosition,
  Selection,
  TypingEvent,
  RoomState,
  ConnectionState,
  ClientOptions,
  JoinRoomOptions,
  ClientEventMap,
  RoomEventMap,
  NotificationEventMap,
} from "./types.js";

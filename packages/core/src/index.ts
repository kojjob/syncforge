// @syncforge/core — public API

export { SyncForgeClient } from "./client.js";
export type { JoinRoomResult, JoinNotificationResult } from "./client.js";

export { TypedEventEmitter } from "./events.js";

export { Room } from "./room.js";
export { PresenceManager } from "./presence.js";
export { CursorManager } from "./cursors.js";
export { SelectionManager } from "./selections.js";
export { CommentManager } from "./comments.js";
export type { CreateCommentParams, UpdateCommentParams } from "./comments.js";
export { ReactionManager } from "./reactions.js";
export { ActivityManager } from "./activity.js";
export type { ListActivitiesOptions } from "./activity.js";
export { NotificationManager } from "./notifications.js";

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

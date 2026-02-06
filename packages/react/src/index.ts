// @syncforge/react — public API

export { SyncForgeProvider, useSyncForge } from "./provider.js";
export type { SyncForgeProviderProps } from "./provider.js";

export { useRoom } from "./hooks/useRoom.js";
export { usePresence } from "./hooks/usePresence.js";
export { useCursors } from "./hooks/useCursors.js";
export { useComments } from "./hooks/useComments.js";
export { useNotifications } from "./hooks/useNotifications.js";

export { PresenceAvatars } from "./components/PresenceAvatars.js";
export type { PresenceAvatarsProps } from "./components/PresenceAvatars.js";

export { CursorOverlay } from "./components/CursorOverlay.js";
export type { CursorOverlayProps } from "./components/CursorOverlay.js";

export { CommentPanel } from "./components/CommentPanel.js";
export type { CommentPanelProps } from "./components/CommentPanel.js";

export { NotificationToast } from "./components/NotificationToast.js";
export type { NotificationToastProps } from "./components/NotificationToast.js";

// Re-export commonly used types from core for convenience
export type {
  User,
  PresenceUser,
  Comment,
  Reaction,
  Notification,
  Activity,
  CursorPosition,
  Selection,
  ConnectionState,
  ClientOptions,
} from "@syncforge/core";

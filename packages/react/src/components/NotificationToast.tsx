/**
 * NotificationToast -- Stacked toast notifications in a fixed corner.
 *
 * Notifications auto-dismiss after a configurable timeout, can be clicked
 * to trigger a callback, and fade in with a CSS animation. Position is
 * configurable to any of the four corners of the viewport.
 */

import {
  forwardRef,
  useCallback,
  useEffect,
  useRef,
  useState,
} from "react";
import type { Notification } from "@syncforge/core";

export interface NotificationToastProps {
  /** Notifications to display. New items appear at the top. */
  notifications: Notification[];
  /** Time in ms before a toast auto-dismisses. Default 5000. 0 = no auto-dismiss. */
  autoDismiss?: number;
  /** Corner of the viewport to anchor the toast stack. Default "top-right". */
  position?: "top-right" | "top-left" | "bottom-right" | "bottom-left";
  /** Called when a toast is dismissed (manually or by timeout). */
  onDismiss?: (id: string) => void;
  /** Called when a toast is clicked. */
  onClick?: (notification: Notification) => void;
  /** Additional CSS class name on the root container. */
  className?: string;
  /** Inline styles merged onto the root container. */
  style?: React.CSSProperties;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const NOTIFICATION_ICONS: Record<string, string> = {
  comment_mention: "@",
  comment_reply: "\u21A9", // hook arrow
  comment_resolved: "\u2713", // check
  reaction_added: "\u2764", // heart
  room_invite: "\u2709", // envelope
  user_joined: "\u2795", // plus
};

function iconForType(type: string): string {
  return NOTIFICATION_ICONS[type] ?? "\u2022"; // bullet fallback
}

function positionStyles(
  pos: NonNullable<NotificationToastProps["position"]>,
): React.CSSProperties {
  const base: React.CSSProperties = {
    position: "fixed",
    zIndex: 10000,
    display: "flex",
    flexDirection: "column",
    gap: 8,
    padding: 16,
    pointerEvents: "none",
    maxWidth: 380,
    boxSizing: "border-box",
  };

  switch (pos) {
    case "top-right":
      return { ...base, top: 0, right: 0 };
    case "top-left":
      return { ...base, top: 0, left: 0 };
    case "bottom-right":
      return { ...base, bottom: 0, right: 0 };
    case "bottom-left":
      return { ...base, bottom: 0, left: 0 };
  }
}

// ---------------------------------------------------------------------------
// Single toast
// ---------------------------------------------------------------------------

interface ToastItemProps {
  notification: Notification;
  onDismiss?: () => void;
  onClick?: () => void;
}

function ToastItem({ notification, onDismiss, onClick }: ToastItemProps) {
  const [visible, setVisible] = useState(false);

  // Trigger fade-in on mount
  useEffect(() => {
    const raf = requestAnimationFrame(() => setVisible(true));
    return () => cancelAnimationFrame(raf);
  }, []);

  const toastStyle: React.CSSProperties = {
    display: "flex",
    alignItems: "flex-start",
    gap: 10,
    padding: "12px 14px",
    backgroundColor: "#fff",
    borderRadius: 8,
    boxShadow:
      "0 4px 12px rgba(0,0,0,0.12), 0 1px 3px rgba(0,0,0,0.08)",
    cursor: onClick ? "pointer" : "default",
    pointerEvents: "auto",
    opacity: visible ? 1 : 0,
    transform: visible ? "translateY(0)" : "translateY(-8px)",
    transition: "opacity 200ms ease, transform 200ms ease",
    fontFamily:
      '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    fontSize: 14,
    color: "#1f2937",
    maxWidth: "100%",
    boxSizing: "border-box",
  };

  const iconStyle: React.CSSProperties = {
    width: 28,
    height: 28,
    borderRadius: "50%",
    backgroundColor: "#eef2ff",
    color: "#6366f1",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    fontWeight: 700,
    fontSize: 14,
    flexShrink: 0,
  };

  const contentStyle: React.CSSProperties = {
    flex: 1,
    minWidth: 0,
  };

  const typeStyle: React.CSSProperties = {
    fontWeight: 600,
    fontSize: 13,
    textTransform: "capitalize",
    marginBottom: 2,
  };

  const messageStyle: React.CSSProperties = {
    fontSize: 13,
    color: "#6b7280",
    whiteSpace: "nowrap",
    overflow: "hidden",
    textOverflow: "ellipsis",
  };

  const closeBtnStyle: React.CSSProperties = {
    background: "none",
    border: "none",
    fontSize: 16,
    color: "#9ca3af",
    cursor: "pointer",
    padding: "0 2px",
    lineHeight: 1,
    flexShrink: 0,
  };

  const displayType = notification.type.replace(/_/g, " ");
  const message =
    typeof notification.payload?.message === "string"
      ? notification.payload.message
      : displayType;

  return (
    <div
      role="alert"
      aria-live="polite"
      style={toastStyle}
      onClick={onClick}
      onKeyDown={
        onClick
          ? (e) => {
              if (e.key === "Enter" || e.key === " ") {
                e.preventDefault();
                onClick();
              }
            }
          : undefined
      }
      tabIndex={onClick ? 0 : undefined}
    >
      <div style={iconStyle} aria-hidden="true">
        {iconForType(notification.type)}
      </div>
      <div style={contentStyle}>
        <div style={typeStyle}>{displayType}</div>
        <div style={messageStyle}>{message}</div>
      </div>
      {onDismiss && (
        <button
          type="button"
          style={closeBtnStyle}
          onClick={(e) => {
            e.stopPropagation();
            onDismiss();
          }}
          aria-label="Dismiss notification"
        >
          &times;
        </button>
      )}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Main component
// ---------------------------------------------------------------------------

export const NotificationToast = forwardRef<
  HTMLDivElement,
  NotificationToastProps
>(function NotificationToast(
  {
    notifications,
    autoDismiss = 5000,
    position = "top-right",
    onDismiss,
    onClick,
    className,
    style,
  },
  ref,
) {
  // Track which notification IDs have been dismissed so we can hide them
  // locally even if the parent hasn't removed them from the array yet.
  const [dismissed, setDismissed] = useState<Set<string>>(new Set());
  const timersRef = useRef<Map<string, ReturnType<typeof setTimeout>>>(
    new Map(),
  );

  const handleDismiss = useCallback(
    (id: string) => {
      setDismissed((prev) => {
        const next = new Set(prev);
        next.add(id);
        return next;
      });
      onDismiss?.(id);

      const timer = timersRef.current.get(id);
      if (timer) {
        clearTimeout(timer);
        timersRef.current.delete(id);
      }
    },
    [onDismiss],
  );

  // Set up auto-dismiss timers
  useEffect(() => {
    if (autoDismiss <= 0) return;

    const timers = timersRef.current;

    for (const n of notifications) {
      if (dismissed.has(n.id) || timers.has(n.id)) continue;

      const timer = setTimeout(() => {
        handleDismiss(n.id);
      }, autoDismiss);

      timers.set(n.id, timer);
    }

    return () => {
      // Clean up timers for notifications that were removed from array
      const currentIds = new Set(notifications.map((n) => n.id));
      for (const [id, timer] of timers) {
        if (!currentIds.has(id)) {
          clearTimeout(timer);
          timers.delete(id);
        }
      }
    };
  }, [notifications, autoDismiss, dismissed, handleDismiss]);

  // Reset dismissed set when notifications change (remove stale IDs)
  useEffect(() => {
    const currentIds = new Set(notifications.map((n) => n.id));
    setDismissed((prev) => {
      const next = new Set<string>();
      for (const id of prev) {
        if (currentIds.has(id)) next.add(id);
      }
      // Only update if something changed
      return next.size === prev.size ? prev : next;
    });
  }, [notifications]);

  const visible = notifications.filter((n) => !dismissed.has(n.id));
  const posStyle = positionStyles(position);

  return (
    <div
      ref={ref}
      className={className}
      style={{ ...posStyle, ...style }}
      aria-label="Notifications"
      role="region"
    >
      {visible.map((n) => (
        <ToastItem
          key={n.id}
          notification={n}
          onDismiss={onDismiss ? () => handleDismiss(n.id) : undefined}
          onClick={onClick ? () => onClick(n) : undefined}
        />
      ))}
    </div>
  );
});

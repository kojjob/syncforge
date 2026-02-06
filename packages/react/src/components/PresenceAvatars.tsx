/**
 * PresenceAvatars -- Stacked avatar circles showing online users.
 *
 * Renders overlapping avatars with initials fallback, an overflow "+N"
 * indicator, and a green online-status dot. Fully accessible with
 * title-based tooltips and keyboard-navigable click targets.
 */

import { forwardRef, useMemo } from "react";
import type { PresenceUser } from "@syncforge/core";

export interface PresenceAvatarsProps {
  /** List of currently present users. */
  users: PresenceUser[];
  /** Maximum number of avatars before showing "+N" overflow. Default 5. */
  maxDisplay?: number;
  /** Avatar diameter in pixels. Default 32. */
  size?: number;
  /** Additional CSS class name applied to the root container. */
  className?: string;
  /** Inline styles merged onto the root container. */
  style?: React.CSSProperties;
  /** Callback when a user avatar is clicked. */
  onUserClick?: (user: PresenceUser) => void;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const COLORS = [
  "#6366f1", // indigo
  "#8b5cf6", // violet
  "#ec4899", // pink
  "#f43f5e", // rose
  "#f97316", // orange
  "#14b8a6", // teal
  "#06b6d4", // cyan
  "#3b82f6", // blue
  "#10b981", // emerald
  "#a855f7", // purple
];

function colorForUser(userId: string): string {
  let hash = 0;
  for (let i = 0; i < userId.length; i++) {
    hash = (hash * 31 + userId.charCodeAt(i)) | 0;
  }
  return COLORS[Math.abs(hash) % COLORS.length];
}

function initials(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length >= 2) {
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
  return (name.slice(0, 2) || "?").toUpperCase();
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export const PresenceAvatars = forwardRef<HTMLDivElement, PresenceAvatarsProps>(
  function PresenceAvatars(
    { users, maxDisplay = 5, size = 32, className, style, onUserClick },
    ref,
  ) {
    const visible = useMemo(() => users.slice(0, maxDisplay), [users, maxDisplay]);
    const overflow = users.length - maxDisplay;
    const fontSize = Math.round(size * 0.38);
    const overlap = Math.round(size * 0.25);
    const dotSize = Math.max(8, Math.round(size * 0.3));

    const containerStyle: React.CSSProperties = {
      display: "inline-flex",
      alignItems: "center",
      flexDirection: "row-reverse",
      ...style,
    };

    const avatarBaseStyle: React.CSSProperties = {
      width: size,
      height: size,
      borderRadius: "50%",
      border: "2px solid #fff",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontSize,
      fontWeight: 600,
      color: "#fff",
      position: "relative",
      cursor: onUserClick ? "pointer" : "default",
      backgroundSize: "cover",
      backgroundPosition: "center",
      flexShrink: 0,
      boxSizing: "border-box",
      userSelect: "none",
    };

    const dotStyle: React.CSSProperties = {
      position: "absolute",
      bottom: -1,
      right: -1,
      width: dotSize,
      height: dotSize,
      borderRadius: "50%",
      backgroundColor: "#22c55e",
      border: "2px solid #fff",
      boxSizing: "border-box",
    };

    const overflowStyle: React.CSSProperties = {
      ...avatarBaseStyle,
      backgroundColor: "#94a3b8",
      cursor: "default",
    };

    // Render in reverse order so the first user visually sits on top
    // (flex-direction: row-reverse takes care of stacking order).
    return (
      <div
        ref={ref}
        className={className}
        style={containerStyle}
        role="group"
        aria-label={`${users.length} user${users.length !== 1 ? "s" : ""} online`}
      >
        {/* Overflow indicator (rendered first = visually last due to row-reverse) */}
        {overflow > 0 && (
          <div
            style={{ ...overflowStyle, marginLeft: -overlap }}
            aria-label={`${overflow} more user${overflow !== 1 ? "s" : ""}`}
            title={`${overflow} more user${overflow !== 1 ? "s" : ""}`}
          >
            +{overflow}
          </div>
        )}

        {[...visible].reverse().map((user, idx) => {
          const bg = colorForUser(user.id);
          const isFirst = idx === visible.length - 1;
          const ml = isFirst ? 0 : -overlap;

          return (
            <div
              key={user.id}
              role={onUserClick ? "button" : undefined}
              tabIndex={onUserClick ? 0 : undefined}
              title={user.name}
              aria-label={`${user.name} (${user.status})`}
              onClick={onUserClick ? () => onUserClick(user) : undefined}
              onKeyDown={
                onUserClick
                  ? (e) => {
                      if (e.key === "Enter" || e.key === " ") {
                        e.preventDefault();
                        onUserClick(user);
                      }
                    }
                  : undefined
              }
              style={{
                ...avatarBaseStyle,
                marginLeft: ml,
                backgroundColor: user.avatar_url ? "transparent" : bg,
                backgroundImage: user.avatar_url
                  ? `url(${user.avatar_url})`
                  : undefined,
              }}
            >
              {/* Initials fallback (hidden when avatar image present) */}
              {!user.avatar_url && initials(user.name)}

              {/* Online status dot */}
              <span style={dotStyle} aria-hidden="true" />
            </div>
          );
        })}
      </div>
    );
  },
);

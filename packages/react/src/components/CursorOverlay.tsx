/**
 * CursorOverlay -- Fixed-position overlay that renders live cursors.
 *
 * Each cursor is an SVG arrow with the user's colour plus a name label.
 * Positions animate with CSS transitions for smooth movement. The overlay
 * is pointer-events: none so it never interferes with the page beneath.
 *
 * Wrapped with React.memo to avoid unnecessary re-renders on every
 * cursor position tick.
 */

import { forwardRef, memo } from "react";
import type { CursorPosition } from "@syncforge/core";

export interface CursorOverlayProps {
  /** Map of user_id -> CursorPosition (use Map for O(1) look-ups). */
  cursors: Map<string, CursorPosition>;
  /** Additional CSS class name on the root overlay element. */
  className?: string;
  /** Inline styles merged onto the root overlay element. */
  style?: React.CSSProperties;
  /** Optional custom renderer; receives cursor data, returns ReactNode. */
  renderCursor?: (cursor: CursorPosition) => React.ReactNode;
}

// ---------------------------------------------------------------------------
// Default cursor renderer
// ---------------------------------------------------------------------------

const LABEL_FONT_SIZE = 12;
const LABEL_PAD_X = 6;
const LABEL_PAD_Y = 3;
const ARROW_SIZE = 20;

function DefaultCursor({ cursor }: { cursor: CursorPosition }) {
  const { color, name } = cursor;

  const wrapperStyle: React.CSSProperties = {
    position: "absolute",
    top: 0,
    left: 0,
    pointerEvents: "none",
  };

  const labelStyle: React.CSSProperties = {
    position: "absolute",
    top: ARROW_SIZE - 4,
    left: ARROW_SIZE / 2,
    backgroundColor: color,
    color: "#fff",
    fontSize: LABEL_FONT_SIZE,
    lineHeight: 1,
    fontFamily:
      '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
    fontWeight: 500,
    padding: `${LABEL_PAD_Y}px ${LABEL_PAD_X}px`,
    borderRadius: 4,
    whiteSpace: "nowrap",
    userSelect: "none",
  };

  return (
    <div style={wrapperStyle} aria-hidden="true">
      {/* SVG arrow cursor */}
      <svg
        width={ARROW_SIZE}
        height={ARROW_SIZE}
        viewBox="0 0 20 20"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        style={{ display: "block" }}
      >
        <path
          d="M3 2L3 17L7.5 12.5L12.5 18L15 16L10 10L16 10L3 2Z"
          fill={color}
          stroke="#fff"
          strokeWidth={1.5}
          strokeLinejoin="round"
        />
      </svg>

      {/* Name label */}
      <span style={labelStyle}>{name}</span>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Overlay component
// ---------------------------------------------------------------------------

export const CursorOverlay = memo(
  forwardRef<HTMLDivElement, CursorOverlayProps>(function CursorOverlay(
    { cursors, className, style, renderCursor },
    ref,
  ) {
    const overlayStyle: React.CSSProperties = {
      position: "fixed",
      inset: 0,
      pointerEvents: "none",
      zIndex: 9999,
      overflow: "hidden",
      ...style,
    };

    const entries = Array.from(cursors.values());

    return (
      <div
        ref={ref}
        className={className}
        style={overlayStyle}
        role="presentation"
        aria-hidden="true"
      >
        {entries.map((cursor) => (
          <div
            key={cursor.user_id}
            style={{
              position: "absolute",
              top: 0,
              left: 0,
              transform: `translate(${cursor.x}px, ${cursor.y}px)`,
              transition: "transform 80ms linear",
              willChange: "transform",
              pointerEvents: "none",
            }}
          >
            {renderCursor ? (
              renderCursor(cursor)
            ) : (
              <DefaultCursor cursor={cursor} />
            )}
          </div>
        ))}
      </div>
    );
  }),
);

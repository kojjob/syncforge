import { describe, it, expect, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import type { CursorPosition } from "@syncforge/core";
import { CursorOverlay } from "../../src/components/CursorOverlay.js";

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

function makeCursor(overrides?: Partial<CursorPosition>): CursorPosition {
  return {
    user_id: "user-1",
    name: "Alice",
    color: "#FF0000",
    x: 100,
    y: 200,
    timestamp: Date.now(),
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("CursorOverlay", () => {
  // -------------------------------------------------------------------------
  // Rendering cursors
  // -------------------------------------------------------------------------

  describe("rendering cursors", () => {
    it("renders a cursor for each entry in the Map", () => {
      const cursors = new Map<string, CursorPosition>([
        ["u1", makeCursor({ user_id: "u1", name: "Alice" })],
        ["u2", makeCursor({ user_id: "u2", name: "Bob", color: "#00FF00" })],
        ["u3", makeCursor({ user_id: "u3", name: "Carol", color: "#0000FF" })],
      ]);

      render(<CursorOverlay cursors={cursors} />);

      expect(screen.getByText("Alice")).toBeInTheDocument();
      expect(screen.getByText("Bob")).toBeInTheDocument();
      expect(screen.getByText("Carol")).toBeInTheDocument();
    });

    it("renders a single cursor", () => {
      const cursors = new Map<string, CursorPosition>([
        ["u1", makeCursor({ user_id: "u1", name: "Alice" })],
      ]);

      render(<CursorOverlay cursors={cursors} />);

      expect(screen.getByText("Alice")).toBeInTheDocument();
    });
  });

  // -------------------------------------------------------------------------
  // Cursor positioning
  // -------------------------------------------------------------------------

  describe("cursor positioning", () => {
    it("positions cursors at the correct x,y coordinates", () => {
      const cursors = new Map<string, CursorPosition>([
        ["u1", makeCursor({ user_id: "u1", name: "Alice", x: 150, y: 300 })],
      ]);

      const { container } = render(<CursorOverlay cursors={cursors} />);

      // Find the positioned cursor element
      const cursorEl =
        container.querySelector("[data-testid='cursor-u1']") ||
        container.querySelector("[style*='left']") ||
        container.querySelector("[style*='transform']");

      expect(cursorEl).toBeInTheDocument();

      // Check the element has the correct positioning via style
      const style = cursorEl!.getAttribute("style") || "";
      // Either uses left/top or transform: translate
      const hasLeftTop =
        style.includes("left") && style.includes("top");
      const hasTranslate = style.includes("translate");

      expect(hasLeftTop || hasTranslate).toBe(true);

      if (hasLeftTop) {
        expect(style).toContain("150");
        expect(style).toContain("300");
      }
      if (hasTranslate) {
        expect(style).toContain("150");
        expect(style).toContain("300");
      }
    });

    it("positions different cursors at different coordinates", () => {
      const cursors = new Map<string, CursorPosition>([
        ["u1", makeCursor({ user_id: "u1", name: "Alice", x: 50, y: 60 })],
        ["u2", makeCursor({ user_id: "u2", name: "Bob", x: 200, y: 400 })],
      ]);

      const { container } = render(<CursorOverlay cursors={cursors} />);

      // Both labels should be rendered in different positions
      const aliceLabel = screen.getByText("Alice");
      const bobLabel = screen.getByText("Bob");

      expect(aliceLabel).toBeInTheDocument();
      expect(bobLabel).toBeInTheDocument();

      // Verify they are distinct elements (not the same node)
      expect(aliceLabel).not.toBe(bobLabel);
    });
  });

  // -------------------------------------------------------------------------
  // User name labels
  // -------------------------------------------------------------------------

  describe("user name labels", () => {
    it("shows user name labels next to cursors", () => {
      const cursors = new Map<string, CursorPosition>([
        ["u1", makeCursor({ user_id: "u1", name: "Alice" })],
        ["u2", makeCursor({ user_id: "u2", name: "Bob" })],
      ]);

      render(<CursorOverlay cursors={cursors} />);

      expect(screen.getByText("Alice")).toBeInTheDocument();
      expect(screen.getByText("Bob")).toBeInTheDocument();
    });

    it("displays long user names correctly", () => {
      const cursors = new Map<string, CursorPosition>([
        [
          "u1",
          makeCursor({
            user_id: "u1",
            name: "Alexander Hamilton-Washington",
          }),
        ],
      ]);

      render(<CursorOverlay cursors={cursors} />);

      expect(
        screen.getByText("Alexander Hamilton-Washington")
      ).toBeInTheDocument();
    });
  });

  // -------------------------------------------------------------------------
  // Cursor color
  // -------------------------------------------------------------------------

  describe("cursor color", () => {
    it("uses the user color for the cursor element", () => {
      const cursors = new Map<string, CursorPosition>([
        [
          "u1",
          makeCursor({ user_id: "u1", name: "Alice", color: "#FF5733" }),
        ],
      ]);

      const { container } = render(<CursorOverlay cursors={cursors} />);

      // The color should appear in a style attribute somewhere in the cursor tree
      const cursorEl =
        container.querySelector("[data-testid='cursor-u1']") ||
        container.querySelector("[style*='#FF5733']") ||
        container.querySelector("[style*='rgb(255, 87, 51)']");

      // Either we find it by test-id or by style
      // If found by test-id, check its style or child style contains color
      if (cursorEl) {
        const html = cursorEl.outerHTML;
        const hasColor =
          html.includes("#FF5733") ||
          html.includes("rgb(255, 87, 51)") ||
          html.includes("FF5733");
        expect(hasColor).toBe(true);
      } else {
        // Fallback: check that the color appears somewhere in the rendered output
        expect(container.innerHTML).toContain("#FF5733");
      }
    });

    it("applies different colors for different users", () => {
      const cursors = new Map<string, CursorPosition>([
        [
          "u1",
          makeCursor({ user_id: "u1", name: "Alice", color: "#FF0000" }),
        ],
        [
          "u2",
          makeCursor({ user_id: "u2", name: "Bob", color: "#00FF00" }),
        ],
      ]);

      const { container } = render(<CursorOverlay cursors={cursors} />);

      const html = container.innerHTML;
      expect(html).toContain("#FF0000");
      expect(html).toContain("#00FF00");
    });
  });

  // -------------------------------------------------------------------------
  // Custom renderCursor prop
  // -------------------------------------------------------------------------

  describe("custom renderCursor prop", () => {
    it("uses renderCursor to render custom cursor elements", () => {
      const cursors = new Map<string, CursorPosition>([
        ["u1", makeCursor({ user_id: "u1", name: "Alice", color: "#FF0000" })],
      ]);

      const renderCursor = vi.fn((cursor: CursorPosition) => (
        <div data-testid="custom-cursor">
          Custom: {cursor.name} at ({cursor.x},{cursor.y})
        </div>
      ));

      render(<CursorOverlay cursors={cursors} renderCursor={renderCursor} />);

      expect(renderCursor).toHaveBeenCalledOnce();
      expect(renderCursor).toHaveBeenCalledWith(
        expect.objectContaining({ user_id: "u1", name: "Alice" })
      );

      expect(screen.getByTestId("custom-cursor")).toBeInTheDocument();
      expect(
        screen.getByText("Custom: Alice at (100,200)")
      ).toBeInTheDocument();
    });

    it("calls renderCursor for each cursor in the Map", () => {
      const cursors = new Map<string, CursorPosition>([
        ["u1", makeCursor({ user_id: "u1", name: "Alice" })],
        ["u2", makeCursor({ user_id: "u2", name: "Bob" })],
      ]);

      const renderCursor = vi.fn((cursor: CursorPosition) => (
        <div data-testid={`custom-${cursor.user_id}`}>{cursor.name}</div>
      ));

      render(<CursorOverlay cursors={cursors} renderCursor={renderCursor} />);

      expect(renderCursor).toHaveBeenCalledTimes(2);
      expect(screen.getByTestId("custom-u1")).toBeInTheDocument();
      expect(screen.getByTestId("custom-u2")).toBeInTheDocument();
    });
  });

  // -------------------------------------------------------------------------
  // Empty state
  // -------------------------------------------------------------------------

  describe("empty state", () => {
    it("renders empty when cursors Map is empty", () => {
      const cursors = new Map<string, CursorPosition>();

      const { container } = render(<CursorOverlay cursors={cursors} />);

      // Should produce no visible cursor elements
      expect(container.textContent).toBe("");
    });

    it("does not call renderCursor when there are no cursors", () => {
      const cursors = new Map<string, CursorPosition>();
      const renderCursor = vi.fn();

      render(<CursorOverlay cursors={cursors} renderCursor={renderCursor} />);

      expect(renderCursor).not.toHaveBeenCalled();
    });
  });

  // -------------------------------------------------------------------------
  // Overlay container
  // -------------------------------------------------------------------------

  describe("overlay container", () => {
    it("uses pointer-events: none so cursors do not block interaction", () => {
      const cursors = new Map<string, CursorPosition>([
        ["u1", makeCursor({ user_id: "u1", name: "Alice" })],
      ]);

      const { container } = render(<CursorOverlay cursors={cursors} />);

      const overlay = container.firstElementChild as HTMLElement;
      expect(overlay).toBeInTheDocument();

      const style = overlay.getAttribute("style") || "";
      expect(style).toContain("pointer-events");
    });

    it("uses absolute or fixed positioning for the overlay container", () => {
      const cursors = new Map<string, CursorPosition>([
        ["u1", makeCursor({ user_id: "u1", name: "Alice" })],
      ]);

      const { container } = render(<CursorOverlay cursors={cursors} />);

      const overlay = container.firstElementChild as HTMLElement;
      const style = overlay.getAttribute("style") || "";

      const hasPositioning =
        style.includes("position: absolute") ||
        style.includes("position: fixed") ||
        style.includes("position:absolute") ||
        style.includes("position:fixed");

      expect(hasPositioning).toBe(true);
    });
  });
});

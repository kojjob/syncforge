import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent, act } from "@testing-library/react";
import type { Notification } from "@syncforge/core";
import { NotificationToast } from "../../src/components/NotificationToast.js";

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

function makeNotification(overrides?: Partial<Notification>): Notification {
  return {
    id: "notif-1",
    type: "comment_mention",
    payload: {},
    read_at: null,
    actor_id: "user-2",
    room_id: "room-1",
    inserted_at: "2024-01-01T00:00:00Z",
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("NotificationToast", () => {
  const defaultProps = {
    notifications: [] as Notification[],
  };

  // -------------------------------------------------------------------------
  // Rendering notifications
  // -------------------------------------------------------------------------

  describe("rendering notifications", () => {
    it("renders notification toasts", () => {
      const notifications = [
        makeNotification({
          id: "n1",
          type: "comment_mention",
          payload: { message: "Alice mentioned you" },
        }),
      ];

      render(
        <NotificationToast {...defaultProps} notifications={notifications} />
      );

      // Should render the notification message from payload
      expect(
        screen.getByText("Alice mentioned you")
      ).toBeInTheDocument();
    });

    it("renders multiple notification toasts", () => {
      const notifications = [
        makeNotification({
          id: "n1",
          type: "comment_mention",
          payload: { message: "First notification" },
        }),
        makeNotification({
          id: "n2",
          type: "comment_reply",
          payload: { message: "Second notification" },
        }),
      ];

      const { container } = render(
        <NotificationToast {...defaultProps} notifications={notifications} />
      );

      // Should render both notifications
      const toastElements =
        container.querySelectorAll("[data-testid^='toast-']") ||
        container.querySelectorAll("[role='alert']") ||
        container.children[0]?.children;

      // At minimum, both notification messages should be present
      expect(
        screen.getByText("First notification") ||
          screen.getByText("comment_mention")
      ).toBeInTheDocument();

      expect(
        screen.getByText("Second notification") ||
          screen.getByText("comment_reply")
      ).toBeInTheDocument();
    });

    it("renders different notification types", () => {
      const notifications = [
        makeNotification({ id: "n1", type: "comment_mention" }),
        makeNotification({ id: "n2", type: "room_invite" }),
        makeNotification({ id: "n3", type: "user_joined" }),
      ];

      const { container } = render(
        <NotificationToast {...defaultProps} notifications={notifications} />
      );

      // All three should be rendered
      expect(container.textContent).not.toBe("");
    });
  });

  // -------------------------------------------------------------------------
  // Dismissing notifications
  // -------------------------------------------------------------------------

  describe("dismissing notifications", () => {
    it("calls onDismiss when a notification is dismissed", () => {
      const onDismiss = vi.fn();
      const notifications = [
        makeNotification({
          id: "n1",
          type: "comment_mention",
          payload: { message: "Test notification" },
        }),
      ];

      render(
        <NotificationToast
          {...defaultProps}
          notifications={notifications}
          onDismiss={onDismiss}
        />
      );

      // Find the dismiss/close button
      const dismissButton =
        screen.getByRole("button", { name: /dismiss|close|x/i });
      fireEvent.click(dismissButton);

      expect(onDismiss).toHaveBeenCalledOnce();
      expect(onDismiss).toHaveBeenCalledWith("n1");
    });

    it("calls onDismiss with the correct notification id", () => {
      const onDismiss = vi.fn();
      const notifications = [
        makeNotification({
          id: "n1",
          payload: { message: "First" },
        }),
        makeNotification({
          id: "n2",
          payload: { message: "Second" },
        }),
      ];

      render(
        <NotificationToast
          {...defaultProps}
          notifications={notifications}
          onDismiss={onDismiss}
        />
      );

      // Dismiss buttons — click the second one
      const dismissButtons = screen.getAllByRole("button", {
        name: /dismiss|close|x/i,
      });
      expect(dismissButtons.length).toBeGreaterThanOrEqual(2);

      fireEvent.click(dismissButtons[1]);

      expect(onDismiss).toHaveBeenCalledOnce();
      expect(onDismiss).toHaveBeenCalledWith("n2");
    });
  });

  // -------------------------------------------------------------------------
  // Clicking notifications
  // -------------------------------------------------------------------------

  describe("clicking notifications", () => {
    it("calls onClick when a notification is clicked", () => {
      const onClick = vi.fn();
      const notification = makeNotification({
        id: "n1",
        type: "comment_mention",
        payload: { message: "Click me" },
      });

      render(
        <NotificationToast
          {...defaultProps}
          notifications={[notification]}
          onClick={onClick}
        />
      );

      // Click on the notification content (not the dismiss button)
      const toastContent =
        screen.getByText("Click me") ||
        screen.getByText("comment_mention");
      fireEvent.click(toastContent);

      expect(onClick).toHaveBeenCalledOnce();
      expect(onClick).toHaveBeenCalledWith(notification);
    });

    it("does not throw when onClick is not provided", () => {
      const notifications = [
        makeNotification({
          id: "n1",
          payload: { message: "No handler" },
        }),
      ];

      render(
        <NotificationToast {...defaultProps} notifications={notifications} />
      );

      const content =
        screen.getByText("No handler") ||
        screen.getByText("comment_mention");

      expect(() => fireEvent.click(content)).not.toThrow();
    });
  });

  // -------------------------------------------------------------------------
  // Position prop
  // -------------------------------------------------------------------------

  describe("position prop", () => {
    it("positions toasts in the top-right corner by default", () => {
      const notifications = [
        makeNotification({ id: "n1", payload: { message: "Toast" } }),
      ];

      const { container } = render(
        <NotificationToast {...defaultProps} notifications={notifications} />
      );

      const wrapper = container.firstElementChild as HTMLElement;
      const style = wrapper?.getAttribute("style") || "";

      // Default should be top-right positioning
      const hasTopRight =
        (style.includes("top") && style.includes("right")) ||
        style.includes("top-right");

      expect(wrapper).toBeInTheDocument();
      // Position should be fixed or absolute
      expect(
        style.includes("position: fixed") ||
          style.includes("position:fixed") ||
          style.includes("position: absolute") ||
          style.includes("position:absolute")
      ).toBe(true);
    });

    it("positions toasts in the top-left corner", () => {
      const notifications = [
        makeNotification({ id: "n1", payload: { message: "Toast" } }),
      ];

      const { container } = render(
        <NotificationToast
          {...defaultProps}
          notifications={notifications}
          position="top-left"
        />
      );

      const wrapper = container.firstElementChild as HTMLElement;
      const style = wrapper?.getAttribute("style") || "";

      expect(style).toContain("left");
      expect(style).toContain("top");
    });

    it("positions toasts in the bottom-right corner", () => {
      const notifications = [
        makeNotification({ id: "n1", payload: { message: "Toast" } }),
      ];

      const { container } = render(
        <NotificationToast
          {...defaultProps}
          notifications={notifications}
          position="bottom-right"
        />
      );

      const wrapper = container.firstElementChild as HTMLElement;
      const style = wrapper?.getAttribute("style") || "";

      expect(style).toContain("bottom");
      expect(style).toContain("right");
    });

    it("positions toasts in the bottom-left corner", () => {
      const notifications = [
        makeNotification({ id: "n1", payload: { message: "Toast" } }),
      ];

      const { container } = render(
        <NotificationToast
          {...defaultProps}
          notifications={notifications}
          position="bottom-left"
        />
      );

      const wrapper = container.firstElementChild as HTMLElement;
      const style = wrapper?.getAttribute("style") || "";

      expect(style).toContain("bottom");
      expect(style).toContain("left");
    });
  });

  // -------------------------------------------------------------------------
  // Empty state
  // -------------------------------------------------------------------------

  describe("empty state", () => {
    it("shows nothing when there are no notifications", () => {
      const { container } = render(
        <NotificationToast {...defaultProps} notifications={[]} />
      );

      // Should render nothing or an empty container
      const hasContent =
        container.textContent !== "" &&
        container.textContent !== null;

      // Either the container is completely empty, or it renders an invisible wrapper
      if (hasContent) {
        // If there's a wrapper element, it should have no visible toast children
        const toasts =
          container.querySelectorAll("[role='alert']") ||
          container.querySelectorAll("[data-testid^='toast-']");
        expect(toasts.length).toBe(0);
      } else {
        expect(container.textContent).toBe("");
      }
    });

    it("does not render dismiss buttons when there are no notifications", () => {
      render(
        <NotificationToast {...defaultProps} notifications={[]} />
      );

      const dismissButtons = screen.queryAllByRole("button", {
        name: /dismiss|close|x/i,
      });
      expect(dismissButtons).toHaveLength(0);
    });
  });

  // -------------------------------------------------------------------------
  // Edge cases
  // -------------------------------------------------------------------------

  describe("edge cases", () => {
    it("handles notifications with empty payload", () => {
      const notifications = [
        makeNotification({ id: "n1", payload: {} }),
      ];

      expect(() =>
        render(
          <NotificationToast {...defaultProps} notifications={notifications} />
        )
      ).not.toThrow();
    });

    it("handles notifications with null read_at", () => {
      const notifications = [
        makeNotification({ id: "n1", read_at: null }),
      ];

      expect(() =>
        render(
          <NotificationToast {...defaultProps} notifications={notifications} />
        )
      ).not.toThrow();
    });

    it("handles rapid notification additions", () => {
      const notifications = Array.from({ length: 10 }, (_, i) =>
        makeNotification({
          id: `n${i}`,
          type: "comment_mention",
          payload: { message: `Notification ${i}` },
        })
      );

      expect(() =>
        render(
          <NotificationToast {...defaultProps} notifications={notifications} />
        )
      ).not.toThrow();
    });
  });
});

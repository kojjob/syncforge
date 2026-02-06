import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent } from "@testing-library/react";
import type { PresenceUser } from "@syncforge/core";
import { PresenceAvatars } from "../../src/components/PresenceAvatars.js";

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

function makeUser(overrides?: Partial<PresenceUser>): PresenceUser {
  return {
    id: "user-1",
    name: "Alice",
    avatar_url: null,
    status: "online",
    joined_at: "2024-01-01T00:00:00Z",
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("PresenceAvatars", () => {
  // -------------------------------------------------------------------------
  // Rendering avatars
  // -------------------------------------------------------------------------

  describe("rendering avatars", () => {
    it("renders an avatar for each user", () => {
      const users = [
        makeUser({ id: "u1", name: "Alice" }),
        makeUser({ id: "u2", name: "Bob" }),
        makeUser({ id: "u3", name: "Carol" }),
      ];

      render(<PresenceAvatars users={users} />);

      // Each user should have a visible representation (2-letter initials)
      expect(screen.getByText("AL")).toBeInTheDocument();
      expect(screen.getByText("BO")).toBeInTheDocument();
      expect(screen.getByText("CA")).toBeInTheDocument();
    });

    it("renders an image when avatar_url is provided", () => {
      const users = [
        makeUser({
          id: "u1",
          name: "Alice",
          avatar_url: "https://example.com/alice.png",
        }),
      ];

      const { container } = render(<PresenceAvatars users={users} />);

      // Component uses CSS backgroundImage instead of <img> tags
      const avatar = container.querySelector("[title='Alice']") as HTMLElement;
      expect(avatar).toBeInTheDocument();
      expect(avatar.style.backgroundImage).toContain(
        "https://example.com/alice.png"
      );
      // No initials text when avatar_url is present
      expect(screen.queryByText("AL")).not.toBeInTheDocument();
    });

    it("shows initials when no avatar_url is provided", () => {
      const users = [
        makeUser({ id: "u1", name: "Alice", avatar_url: null }),
      ];

      render(<PresenceAvatars users={users} />);

      // Should display 2-letter initials
      expect(screen.getByText("AL")).toBeInTheDocument();
    });

    it("shows initials when avatar_url is undefined", () => {
      const users = [
        makeUser({ id: "u1", name: "Diana", avatar_url: undefined }),
      ];

      render(<PresenceAvatars users={users} />);

      expect(screen.getByText("DI")).toBeInTheDocument();
    });
  });

  // -------------------------------------------------------------------------
  // maxDisplay prop
  // -------------------------------------------------------------------------

  describe("maxDisplay prop", () => {
    it("limits the number of displayed avatars", () => {
      const users = [
        makeUser({ id: "u1", name: "Alice" }),
        makeUser({ id: "u2", name: "Bob" }),
        makeUser({ id: "u3", name: "Carol" }),
        makeUser({ id: "u4", name: "Diana" }),
        makeUser({ id: "u5", name: "Eve" }),
      ];

      render(<PresenceAvatars users={users} maxDisplay={3} />);

      // Only 3 initials should appear (2-letter initials)
      expect(screen.getByText("AL")).toBeInTheDocument();
      expect(screen.getByText("BO")).toBeInTheDocument();
      expect(screen.getByText("CA")).toBeInTheDocument();

      // The remaining 2 should not be rendered as avatars
      expect(screen.queryByText("DI")).not.toBeInTheDocument();
      expect(screen.queryByText("EV")).not.toBeInTheDocument();
    });

    it("shows +N overflow indicator for extra users", () => {
      const users = [
        makeUser({ id: "u1", name: "Alice" }),
        makeUser({ id: "u2", name: "Bob" }),
        makeUser({ id: "u3", name: "Carol" }),
        makeUser({ id: "u4", name: "Diana" }),
        makeUser({ id: "u5", name: "Eve" }),
      ];

      render(<PresenceAvatars users={users} maxDisplay={3} />);

      // Should show +2 for the remaining users
      expect(screen.getByText("+2")).toBeInTheDocument();
    });

    it("does not show overflow indicator when users fit within maxDisplay", () => {
      const users = [
        makeUser({ id: "u1", name: "Alice" }),
        makeUser({ id: "u2", name: "Bob" }),
      ];

      render(<PresenceAvatars users={users} maxDisplay={5} />);

      expect(screen.queryByText(/^\+\d+$/)).not.toBeInTheDocument();
    });

    it("shows all users when maxDisplay is not specified", () => {
      const users = [
        makeUser({ id: "u1", name: "Alice" }),
        makeUser({ id: "u2", name: "Bob" }),
        makeUser({ id: "u3", name: "Carol" }),
      ];

      render(<PresenceAvatars users={users} />);

      expect(screen.getByText("AL")).toBeInTheDocument();
      expect(screen.getByText("BO")).toBeInTheDocument();
      expect(screen.getByText("CA")).toBeInTheDocument();
      expect(screen.queryByText(/^\+\d+$/)).not.toBeInTheDocument();
    });
  });

  // -------------------------------------------------------------------------
  // onUserClick callback
  // -------------------------------------------------------------------------

  describe("onUserClick callback", () => {
    it("calls onUserClick with the user when an avatar is clicked", () => {
      const onUserClick = vi.fn();
      const user = makeUser({ id: "u1", name: "Alice" });

      render(<PresenceAvatars users={[user]} onUserClick={onUserClick} />);

      fireEvent.click(screen.getByText("AL"));

      expect(onUserClick).toHaveBeenCalledOnce();
      expect(onUserClick).toHaveBeenCalledWith(user);
    });

    it("calls onUserClick with the correct user when multiple avatars exist", () => {
      const onUserClick = vi.fn();
      const users = [
        makeUser({ id: "u1", name: "Alice" }),
        makeUser({ id: "u2", name: "Bob" }),
      ];

      render(<PresenceAvatars users={users} onUserClick={onUserClick} />);

      fireEvent.click(screen.getByText("BO"));

      expect(onUserClick).toHaveBeenCalledOnce();
      expect(onUserClick).toHaveBeenCalledWith(
        expect.objectContaining({ id: "u2", name: "Bob" })
      );
    });

    it("does not throw when onUserClick is not provided", () => {
      const users = [makeUser({ id: "u1", name: "Alice" })];

      render(<PresenceAvatars users={users} />);

      expect(() => fireEvent.click(screen.getByText("AL"))).not.toThrow();
    });
  });

  // -------------------------------------------------------------------------
  // size prop
  // -------------------------------------------------------------------------

  describe("size prop", () => {
    it("renders with small size", () => {
      const users = [makeUser({ id: "u1", name: "Alice" })];

      const { container } = render(
        <PresenceAvatars users={users} size={24} />
      );

      const avatar = container.querySelector("[title='Alice']") as HTMLElement;
      expect(avatar).toBeInTheDocument();
      expect(avatar.style.width).toBe("24px");
      expect(avatar.style.height).toBe("24px");
    });

    it("renders with medium size (default)", () => {
      const users = [makeUser({ id: "u1", name: "Alice" })];

      const { container } = render(
        <PresenceAvatars users={users} size={32} />
      );

      const avatar = container.querySelector("[title='Alice']") as HTMLElement;
      expect(avatar).toBeInTheDocument();
      expect(avatar.style.width).toBe("32px");
      expect(avatar.style.height).toBe("32px");
    });

    it("renders with large size", () => {
      const users = [makeUser({ id: "u1", name: "Alice" })];

      const { container } = render(
        <PresenceAvatars users={users} size={48} />
      );

      const avatar = container.querySelector("[title='Alice']") as HTMLElement;
      expect(avatar).toBeInTheDocument();
      expect(avatar.style.width).toBe("48px");
      expect(avatar.style.height).toBe("48px");
    });
  });

  // -------------------------------------------------------------------------
  // Empty state
  // -------------------------------------------------------------------------

  describe("empty state", () => {
    it("renders empty when no users are provided", () => {
      const { container } = render(<PresenceAvatars users={[]} />);

      // Should not render any avatars or overflow indicators
      expect(screen.queryByRole("img")).not.toBeInTheDocument();
      expect(screen.queryByText(/^\+\d+$/)).not.toBeInTheDocument();
      // Container should be empty or contain an empty wrapper
      expect(container.textContent).toBe("");
    });

    it("does not call onUserClick when there are no users", () => {
      const onUserClick = vi.fn();

      render(<PresenceAvatars users={[]} onUserClick={onUserClick} />);

      expect(onUserClick).not.toHaveBeenCalled();
    });
  });
});

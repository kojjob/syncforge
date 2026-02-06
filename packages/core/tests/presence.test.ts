import { describe, it, expect, vi, beforeEach } from "vitest";
import { MockChannel, MockPresence } from "./helpers/mock-socket.js";
import type { PresenceUser } from "../src/types.js";

// Mock the phoenix module so that `await import("phoenix")` inside
// PresenceManager.attach() returns our MockPresence constructor.
let mockPresence: MockPresence;
vi.mock("phoenix", () => ({
  Presence: vi.fn().mockImplementation((channel: unknown) => {
    mockPresence = new MockPresence(channel as MockChannel);
    return mockPresence;
  }),
}));

import { PresenceManager } from "../src/presence.js";

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const user1: PresenceUser = {
  id: "u1",
  name: "Alice",
  avatar_url: null,
  status: "online",
  joined_at: "2024-01-01T00:00:00Z",
};

const user2: PresenceUser = {
  id: "u2",
  name: "Bob",
  avatar_url: "https://example.com/bob.png",
  status: "idle",
  joined_at: "2024-01-01T00:05:00Z",
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("PresenceManager", () => {
  let manager: PresenceManager;
  let channel: MockChannel;

  beforeEach(() => {
    manager = new PresenceManager();
    channel = new MockChannel("room:test-room-1");
  });

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------

  describe("initial state", () => {
    it("has an empty users list", () => {
      expect(manager.users).toEqual([]);
    });

    it("users returns an array", () => {
      expect(Array.isArray(manager.users)).toBe(true);
    });
  });

  // -------------------------------------------------------------------------
  // attach()
  // -------------------------------------------------------------------------

  describe("attach()", () => {
    it("creates a Phoenix Presence instance on the channel", async () => {
      await manager.attach(channel as unknown as import("phoenix").Channel);

      // The mock constructor should have been called with the channel
      expect(mockPresence).toBeDefined();
    });

    it("sets up onSync handler", async () => {
      await manager.attach(channel as unknown as import("phoenix").Channel);

      // Verify the presence object was wired up by triggering a sync
      const syncListener = vi.fn();
      manager.on("presence:sync", syncListener);

      mockPresence.simulateSync({
        u1: { metas: [user1 as unknown as Record<string, unknown>] },
      });

      expect(syncListener).toHaveBeenCalledOnce();
    });

    it("sets up onJoin handler", async () => {
      await manager.attach(channel as unknown as import("phoenix").Channel);

      const joinListener = vi.fn();
      manager.on("presence:join", joinListener);

      mockPresence.simulateJoin(
        "u1",
        undefined,
        { metas: [user1 as unknown as Record<string, unknown>] }
      );

      expect(joinListener).toHaveBeenCalled();
    });

    it("sets up onLeave handler", async () => {
      await manager.attach(channel as unknown as import("phoenix").Channel);

      const leaveListener = vi.fn();
      manager.on("presence:leave", leaveListener);

      mockPresence.simulateLeave(
        "u1",
        undefined,
        { metas: [user1 as unknown as Record<string, unknown>] }
      );

      expect(leaveListener).toHaveBeenCalled();
    });
  });

  // -------------------------------------------------------------------------
  // presence:sync
  // -------------------------------------------------------------------------

  describe("presence:sync", () => {
    beforeEach(async () => {
      await manager.attach(channel as unknown as import("phoenix").Channel);
    });

    it("populates the users list from sync state", () => {
      mockPresence.simulateSync({
        u1: { metas: [user1 as unknown as Record<string, unknown>] },
        u2: { metas: [user2 as unknown as Record<string, unknown>] },
      });

      expect(manager.users).toHaveLength(2);
      expect(manager.users).toEqual(
        expect.arrayContaining([
          expect.objectContaining({ id: "u1", name: "Alice" }),
          expect.objectContaining({ id: "u2", name: "Bob" }),
        ])
      );
    });

    it("emits 'presence:sync' with the users array", () => {
      const syncListener = vi.fn();
      manager.on("presence:sync", syncListener);

      mockPresence.simulateSync({
        u1: { metas: [user1 as unknown as Record<string, unknown>] },
      });

      expect(syncListener).toHaveBeenCalledOnce();
      expect(syncListener).toHaveBeenCalledWith({
        users: expect.arrayContaining([
          expect.objectContaining({ id: "u1", name: "Alice" }),
        ]),
      });
    });

    it("replaces users list on subsequent syncs", () => {
      mockPresence.simulateSync({
        u1: { metas: [user1 as unknown as Record<string, unknown>] },
        u2: { metas: [user2 as unknown as Record<string, unknown>] },
      });
      expect(manager.users).toHaveLength(2);

      // Sync again with only one user
      mockPresence.simulateSync({
        u2: { metas: [user2 as unknown as Record<string, unknown>] },
      });
      expect(manager.users).toHaveLength(1);
      expect(manager.users[0]).toEqual(
        expect.objectContaining({ id: "u2", name: "Bob" })
      );
    });

    it("handles empty sync state", () => {
      const syncListener = vi.fn();
      manager.on("presence:sync", syncListener);

      mockPresence.simulateSync({});

      expect(manager.users).toEqual([]);
      expect(syncListener).toHaveBeenCalledWith({ users: [] });
    });

    it("uses the first meta entry for each user", () => {
      mockPresence.simulateSync({
        u1: {
          metas: [
            user1 as unknown as Record<string, unknown>,
            // Second meta (e.g., a second device) should be ignored
            { ...user1, status: "away" } as unknown as Record<string, unknown>,
          ],
        },
      });

      expect(manager.users).toHaveLength(1);
      expect(manager.users[0]).toEqual(
        expect.objectContaining({ status: "online" })
      );
    });
  });

  // -------------------------------------------------------------------------
  // presence:join
  // -------------------------------------------------------------------------

  describe("presence:join", () => {
    beforeEach(async () => {
      await manager.attach(channel as unknown as import("phoenix").Channel);
    });

    it("emits 'presence:join' with the joining user", () => {
      const joinListener = vi.fn();
      manager.on("presence:join", joinListener);

      mockPresence.simulateJoin(
        "u1",
        undefined,
        { metas: [user1 as unknown as Record<string, unknown>] }
      );

      expect(joinListener).toHaveBeenCalledWith({
        user: expect.objectContaining({ id: "u1", name: "Alice" }),
      });
    });

    it("emits with correct user data from newPres metas", () => {
      const joinListener = vi.fn();
      manager.on("presence:join", joinListener);

      mockPresence.simulateJoin(
        "u2",
        undefined,
        { metas: [user2 as unknown as Record<string, unknown>] }
      );

      expect(joinListener).toHaveBeenCalledWith({
        user: expect.objectContaining({
          id: "u2",
          name: "Bob",
          avatar_url: "https://example.com/bob.png",
          status: "idle",
        }),
      });
    });

    it("triggers a sync after join (users list updated)", () => {
      const syncListener = vi.fn();
      manager.on("presence:sync", syncListener);

      mockPresence.simulateJoin(
        "u1",
        undefined,
        { metas: [user1 as unknown as Record<string, unknown>] }
      );

      // MockPresence.simulateJoin calls _syncCb after _joinCb
      expect(syncListener).toHaveBeenCalled();
      expect(manager.users).toHaveLength(1);
    });
  });

  // -------------------------------------------------------------------------
  // presence:leave
  // -------------------------------------------------------------------------

  describe("presence:leave", () => {
    beforeEach(async () => {
      await manager.attach(channel as unknown as import("phoenix").Channel);
    });

    it("emits 'presence:leave' with the departing user", () => {
      const leaveListener = vi.fn();
      manager.on("presence:leave", leaveListener);

      mockPresence.simulateLeave(
        "u1",
        undefined,
        { metas: [user1 as unknown as Record<string, unknown>] }
      );

      expect(leaveListener).toHaveBeenCalledWith({
        user: expect.objectContaining({ id: "u1", name: "Alice" }),
      });
    });

    it("triggers a sync after leave (users list updated)", () => {
      // First, add a user via join
      mockPresence.simulateJoin(
        "u1",
        undefined,
        { metas: [user1 as unknown as Record<string, unknown>] }
      );
      expect(manager.users).toHaveLength(1);

      // Then leave
      mockPresence.simulateLeave(
        "u1",
        undefined,
        { metas: [user1 as unknown as Record<string, unknown>] }
      );

      // After leave + sync, user should be gone
      expect(manager.users).toHaveLength(0);
    });

    it("removes only the departing user, keeping others", () => {
      // Add two users
      mockPresence.simulateJoin(
        "u1",
        undefined,
        { metas: [user1 as unknown as Record<string, unknown>] }
      );
      mockPresence.simulateJoin(
        "u2",
        undefined,
        { metas: [user2 as unknown as Record<string, unknown>] }
      );
      expect(manager.users).toHaveLength(2);

      // Only u1 leaves
      mockPresence.simulateLeave(
        "u1",
        undefined,
        { metas: [user1 as unknown as Record<string, unknown>] }
      );

      expect(manager.users).toHaveLength(1);
      expect(manager.users[0]).toEqual(
        expect.objectContaining({ id: "u2", name: "Bob" })
      );
    });
  });

  // -------------------------------------------------------------------------
  // detach()
  // -------------------------------------------------------------------------

  describe("detach()", () => {
    beforeEach(async () => {
      await manager.attach(channel as unknown as import("phoenix").Channel);
    });

    it("clears the users list", () => {
      // Populate users first
      mockPresence.simulateSync({
        u1: { metas: [user1 as unknown as Record<string, unknown>] },
        u2: { metas: [user2 as unknown as Record<string, unknown>] },
      });
      expect(manager.users).toHaveLength(2);

      manager.detach();

      expect(manager.users).toEqual([]);
    });

    it("removes all event listeners", () => {
      const syncListener = vi.fn();
      const joinListener = vi.fn();
      const leaveListener = vi.fn();

      manager.on("presence:sync", syncListener);
      manager.on("presence:join", joinListener);
      manager.on("presence:leave", leaveListener);

      manager.detach();

      expect(manager.listenerCount("presence:sync")).toBe(0);
      expect(manager.listenerCount("presence:join")).toBe(0);
      expect(manager.listenerCount("presence:leave")).toBe(0);
    });

    it("is safe to call multiple times", () => {
      manager.detach();
      expect(() => manager.detach()).not.toThrow();
      expect(manager.users).toEqual([]);
    });

    it("does not emit events after detach", async () => {
      const syncListener = vi.fn();
      manager.on("presence:sync", syncListener);

      manager.detach();

      // Re-attach to get a fresh presence object
      await manager.attach(channel as unknown as import("phoenix").Channel);

      // The old listener should have been removed
      mockPresence.simulateSync({
        u1: { metas: [user1 as unknown as Record<string, unknown>] },
      });

      // syncListener was registered before detach and removed by it,
      // so it should not have been called from the new attach
      expect(syncListener).not.toHaveBeenCalled();
    });
  });

  // -------------------------------------------------------------------------
  // updatePresence()
  // -------------------------------------------------------------------------

  describe("updatePresence()", () => {
    it("pushes 'presence:update' event to the channel", () => {
      const updates = { status: "away", cursor_visible: false };

      manager.updatePresence(
        channel as unknown as import("phoenix").Channel,
        updates
      );

      expect(channel.pushLog).toHaveLength(1);
      expect(channel.pushLog[0]).toEqual({
        event: "presence:update",
        payload: { status: "away", cursor_visible: false },
      });
    });

    it("sends arbitrary metadata updates", () => {
      manager.updatePresence(
        channel as unknown as import("phoenix").Channel,
        { custom_field: "hello", typing: true }
      );

      expect(channel.pushLog).toHaveLength(1);
      expect(channel.pushLog[0]).toEqual({
        event: "presence:update",
        payload: { custom_field: "hello", typing: true },
      });
    });

    it("works without needing attach() first", () => {
      // updatePresence operates directly on the channel, not the
      // internal presence object, so it should work standalone
      expect(() =>
        manager.updatePresence(
          channel as unknown as import("phoenix").Channel,
          { status: "online" }
        )
      ).not.toThrow();

      expect(channel.pushLog).toHaveLength(1);
    });

    it("can be called multiple times", () => {
      manager.updatePresence(
        channel as unknown as import("phoenix").Channel,
        { status: "online" }
      );
      manager.updatePresence(
        channel as unknown as import("phoenix").Channel,
        { status: "away" }
      );
      manager.updatePresence(
        channel as unknown as import("phoenix").Channel,
        { status: "dnd" }
      );

      expect(channel.pushLog).toHaveLength(3);
      expect(channel.pushLog.map((p) => p.payload)).toEqual([
        { status: "online" },
        { status: "away" },
        { status: "dnd" },
      ]);
    });
  });

  // -------------------------------------------------------------------------
  // Event emitter integration
  // -------------------------------------------------------------------------

  describe("event emitter integration", () => {
    beforeEach(async () => {
      await manager.attach(channel as unknown as import("phoenix").Channel);
    });

    it("supports unsubscribing from events", () => {
      const syncListener = vi.fn();
      const unsub = manager.on("presence:sync", syncListener);

      unsub();

      mockPresence.simulateSync({
        u1: { metas: [user1 as unknown as Record<string, unknown>] },
      });

      expect(syncListener).not.toHaveBeenCalled();
    });

    it("supports once() for single-fire listeners", () => {
      const joinListener = vi.fn();
      manager.once("presence:join", joinListener);

      mockPresence.simulateJoin(
        "u1",
        undefined,
        { metas: [user1 as unknown as Record<string, unknown>] }
      );
      mockPresence.simulateJoin(
        "u2",
        undefined,
        { metas: [user2 as unknown as Record<string, unknown>] }
      );

      expect(joinListener).toHaveBeenCalledOnce();
      expect(joinListener).toHaveBeenCalledWith({
        user: expect.objectContaining({ id: "u1" }),
      });
    });

    it("supports multiple listeners on the same event", () => {
      const listener1 = vi.fn();
      const listener2 = vi.fn();

      manager.on("presence:sync", listener1);
      manager.on("presence:sync", listener2);

      mockPresence.simulateSync({
        u1: { metas: [user1 as unknown as Record<string, unknown>] },
      });

      expect(listener1).toHaveBeenCalledOnce();
      expect(listener2).toHaveBeenCalledOnce();
    });

    it("off() removes a specific listener", () => {
      const listener1 = vi.fn();
      const listener2 = vi.fn();

      manager.on("presence:leave", listener1);
      manager.on("presence:leave", listener2);
      manager.off("presence:leave", listener1);

      mockPresence.simulateLeave(
        "u1",
        undefined,
        { metas: [user1 as unknown as Record<string, unknown>] }
      );

      expect(listener1).not.toHaveBeenCalled();
      expect(listener2).toHaveBeenCalledOnce();
    });
  });
});

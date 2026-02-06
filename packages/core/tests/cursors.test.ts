import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { MockChannel } from "./helpers/mock-socket.js";
import { CursorManager } from "../src/cursors.js";

function createManager() {
  const channel = new MockChannel("room:test-room");
  const manager = new CursorManager(channel as unknown as import("phoenix").Channel);
  return { channel, manager };
}

function makeCursor(overrides: Partial<import("../src/types.js").CursorPosition> = {}) {
  return {
    user_id: "user-1",
    name: "Alice",
    color: "#ff0000",
    x: 100,
    y: 200,
    timestamp: Date.now(),
    ...overrides,
  };
}

describe("CursorManager", () => {
  let channel: MockChannel;
  let manager: CursorManager;

  beforeEach(() => {
    vi.useFakeTimers();
    ({ channel, manager } = createManager());
  });

  afterEach(() => {
    manager.destroy();
    vi.useRealTimers();
  });

  // ---------- Initial state ----------

  describe("initial state", () => {
    it("has an empty cursors map", () => {
      expect(manager.cursors.size).toBe(0);
    });
  });

  // ---------- Remote cursor updates ----------

  describe("remote cursor update via channel", () => {
    it("stores the cursor in the map when a remote update arrives", () => {
      const cursor = makeCursor({ user_id: "remote-1", x: 50, y: 75 });
      channel.simulateEvent("cursor:update", cursor);

      expect(manager.cursors.size).toBe(1);
      expect(manager.cursors.get("remote-1")).toEqual(cursor);
    });

    it("emits cursor:update event when a remote update arrives", () => {
      const listener = vi.fn();
      manager.on("cursor:update", listener);

      const cursor = makeCursor({ user_id: "remote-2" });
      channel.simulateEvent("cursor:update", cursor);

      expect(listener).toHaveBeenCalledOnce();
      expect(listener).toHaveBeenCalledWith(cursor);
    });

    it("tracks multiple cursors from different users", () => {
      const cursor1 = makeCursor({ user_id: "user-a", x: 10, y: 20 });
      const cursor2 = makeCursor({ user_id: "user-b", x: 30, y: 40 });
      const cursor3 = makeCursor({ user_id: "user-c", x: 50, y: 60 });

      channel.simulateEvent("cursor:update", cursor1);
      channel.simulateEvent("cursor:update", cursor2);
      channel.simulateEvent("cursor:update", cursor3);

      expect(manager.cursors.size).toBe(3);
      expect(manager.cursors.get("user-a")).toEqual(cursor1);
      expect(manager.cursors.get("user-b")).toEqual(cursor2);
      expect(manager.cursors.get("user-c")).toEqual(cursor3);
    });

    it("overwrites previous position when the same user sends an update", () => {
      const first = makeCursor({ user_id: "user-a", x: 0, y: 0 });
      const second = makeCursor({ user_id: "user-a", x: 999, y: 888 });

      channel.simulateEvent("cursor:update", first);
      channel.simulateEvent("cursor:update", second);

      expect(manager.cursors.size).toBe(1);
      expect(manager.cursors.get("user-a")).toEqual(second);
    });
  });

  // ---------- removeCursor ----------

  describe("removeCursor()", () => {
    it("removes the specified user from the cursors map", () => {
      channel.simulateEvent("cursor:update", makeCursor({ user_id: "user-x" }));
      expect(manager.cursors.has("user-x")).toBe(true);

      manager.removeCursor("user-x");
      expect(manager.cursors.has("user-x")).toBe(false);
      expect(manager.cursors.size).toBe(0);
    });

    it("does nothing when removing a non-existent user", () => {
      expect(() => manager.removeCursor("ghost")).not.toThrow();
      expect(manager.cursors.size).toBe(0);
    });
  });

  // ---------- sendUpdate ----------

  describe("sendUpdate()", () => {
    it("pushes to channel immediately when not throttled", () => {
      // Ensure _lastSendTime is far enough in the past
      vi.setSystemTime(1000);

      manager.sendUpdate(100, 200);

      expect(channel.pushLog).toHaveLength(1);
      expect(channel.pushLog[0]).toEqual({
        event: "cursor:update",
        payload: { x: 100, y: 200 },
      });
    });

    it("includes element_id in payload when provided", () => {
      vi.setSystemTime(1000);

      manager.sendUpdate(10, 20, "canvas-1");

      expect(channel.pushLog).toHaveLength(1);
      expect(channel.pushLog[0]).toEqual({
        event: "cursor:update",
        payload: { x: 10, y: 20, element_id: "canvas-1" },
      });
    });

    it("throttles when called rapidly within 16ms", () => {
      vi.setSystemTime(1000);
      manager.sendUpdate(0, 0); // immediate push

      vi.setSystemTime(1005); // only 5ms later
      manager.sendUpdate(50, 50); // should be throttled

      // Only the first call should have pushed immediately
      expect(channel.pushLog).toHaveLength(1);
      expect(channel.pushLog[0].payload).toEqual({ x: 0, y: 0 });
    });

    it("flushes pending update after the throttle period", () => {
      vi.setSystemTime(1000);
      manager.sendUpdate(0, 0); // immediate push

      vi.setSystemTime(1005); // 5ms later
      manager.sendUpdate(50, 50); // throttled, stored as pending

      // The timer should be set for THROTTLE_MS - elapsed = 16 - 5 = 11ms
      vi.advanceTimersByTime(11);

      expect(channel.pushLog).toHaveLength(2);
      expect(channel.pushLog[1].payload).toEqual({ x: 50, y: 50 });
    });

    it("only sends the latest pending update when multiple arrive during throttle", () => {
      vi.setSystemTime(1000);
      manager.sendUpdate(0, 0); // immediate

      vi.setSystemTime(1005);
      manager.sendUpdate(10, 10); // throttled
      vi.setSystemTime(1008);
      manager.sendUpdate(20, 20); // overwrites pending (timer already scheduled)

      vi.advanceTimersByTime(11); // flush at 1000 + 16

      expect(channel.pushLog).toHaveLength(2);
      // The flushed update should be the latest one
      expect(channel.pushLog[1].payload).toEqual({ x: 20, y: 20 });
    });

    it("allows immediate push again after throttle period elapses", () => {
      vi.setSystemTime(1000);
      manager.sendUpdate(0, 0); // immediate

      vi.setSystemTime(1020); // 20ms later (> 16ms)
      manager.sendUpdate(99, 99); // should push immediately

      expect(channel.pushLog).toHaveLength(2);
      expect(channel.pushLog[1].payload).toEqual({ x: 99, y: 99 });
    });
  });

  // ---------- lerp ----------

  describe("lerp()", () => {
    it("returns null for an unknown user", () => {
      expect(manager.lerp("non-existent")).toBeNull();
    });

    it("returns exact position on first call for a user", () => {
      channel.simulateEvent(
        "cursor:update",
        makeCursor({ user_id: "u1", x: 100, y: 200 })
      );

      const result = manager.lerp("u1");
      expect(result).toEqual({ x: 100, y: 200 });
    });

    it("interpolates toward target on subsequent calls", () => {
      channel.simulateEvent(
        "cursor:update",
        makeCursor({ user_id: "u1", x: 100, y: 200 })
      );

      // First call: stores initial position
      manager.lerp("u1");

      // Now move the target far away
      channel.simulateEvent(
        "cursor:update",
        makeCursor({ user_id: "u1", x: 200, y: 400 })
      );

      // Lerp with default factor 0.15
      const result = manager.lerp("u1");

      // stored.x = 100 + (200 - 100) * 0.15 = 115
      // stored.y = 200 + (400 - 200) * 0.15 = 230
      expect(result).not.toBeNull();
      expect(result!.x).toBeCloseTo(115, 5);
      expect(result!.y).toBeCloseTo(230, 5);
    });

    it("converges toward target over multiple calls", () => {
      channel.simulateEvent(
        "cursor:update",
        makeCursor({ user_id: "u1", x: 0, y: 0 })
      );
      manager.lerp("u1"); // initial

      channel.simulateEvent(
        "cursor:update",
        makeCursor({ user_id: "u1", x: 100, y: 100 })
      );

      // Call lerp multiple times to converge
      let result = { x: 0, y: 0 };
      for (let i = 0; i < 50; i++) {
        result = manager.lerp("u1")!;
      }

      // After 50 iterations with factor 0.15, should be very close to 100
      expect(result.x).toBeCloseTo(100, 0);
      expect(result.y).toBeCloseTo(100, 0);
    });

    it("uses custom interpolation factor", () => {
      channel.simulateEvent(
        "cursor:update",
        makeCursor({ user_id: "u1", x: 0, y: 0 })
      );
      manager.lerp("u1", 0.5); // initial

      channel.simulateEvent(
        "cursor:update",
        makeCursor({ user_id: "u1", x: 100, y: 100 })
      );

      const result = manager.lerp("u1", 0.5);

      // stored.x = 0 + (100 - 0) * 0.5 = 50
      // stored.y = 0 + (100 - 0) * 0.5 = 50
      expect(result!.x).toBeCloseTo(50, 5);
      expect(result!.y).toBeCloseTo(50, 5);
    });
  });

  // ---------- destroy ----------

  describe("destroy()", () => {
    it("clears the cursors map", () => {
      channel.simulateEvent("cursor:update", makeCursor({ user_id: "u1" }));
      channel.simulateEvent("cursor:update", makeCursor({ user_id: "u2" }));
      expect(manager.cursors.size).toBe(2);

      manager.destroy();
      expect(manager.cursors.size).toBe(0);
    });

    it("removes all event listeners", () => {
      const listener = vi.fn();
      manager.on("cursor:update", listener);

      manager.destroy();

      // Listeners should be gone; emitting should not call the listener
      // We can verify via listenerCount
      expect(manager.listenerCount("cursor:update")).toBe(0);
    });

    it("clears pending throttle timer", () => {
      vi.setSystemTime(1000);
      manager.sendUpdate(0, 0); // immediate

      vi.setSystemTime(1005);
      manager.sendUpdate(50, 50); // pending with timer

      manager.destroy();

      // Advancing timers should not flush the pending update
      vi.advanceTimersByTime(20);
      expect(channel.pushLog).toHaveLength(1); // only the initial push
    });

    it("can be called safely multiple times", () => {
      expect(() => {
        manager.destroy();
        manager.destroy();
      }).not.toThrow();
    });
  });
});

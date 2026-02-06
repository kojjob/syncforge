import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { MockChannel } from "./helpers/mock-socket.js";
import { SelectionManager } from "../src/selections.js";

function createManager() {
  const channel = new MockChannel("room:test-room");
  const manager = new SelectionManager(channel as unknown as import("phoenix").Channel);
  return { channel, manager };
}

function makeSelection(overrides: Partial<import("../src/types.js").Selection> = {}) {
  return {
    user_id: "user-1",
    name: "Alice",
    color: "#ff0000",
    selection: { start: 0, end: 10 },
    timestamp: Date.now(),
    ...overrides,
  };
}

describe("SelectionManager", () => {
  let channel: MockChannel;
  let manager: SelectionManager;

  beforeEach(() => {
    ({ channel, manager } = createManager());
  });

  afterEach(() => {
    manager.destroy();
  });

  // ---------- Initial state ----------

  describe("initial state", () => {
    it("has an empty selections map", () => {
      expect(manager.selections.size).toBe(0);
    });
  });

  // ---------- Remote selection updates ----------

  describe("remote selection update via channel", () => {
    it("stores the selection in the map when a remote update arrives", () => {
      const sel = makeSelection({ user_id: "remote-1" });
      channel.simulateEvent("selection:update", sel);

      expect(manager.selections.size).toBe(1);
      expect(manager.selections.get("remote-1")).toEqual(sel);
    });

    it("emits selection:update event when a remote update arrives", () => {
      const listener = vi.fn();
      manager.on("selection:update", listener);

      const sel = makeSelection({ user_id: "remote-2" });
      channel.simulateEvent("selection:update", sel);

      expect(listener).toHaveBeenCalledOnce();
      expect(listener).toHaveBeenCalledWith(sel);
    });

    it("removes the selection when a null selection is received", () => {
      // First add a selection
      const sel = makeSelection({ user_id: "user-a" });
      channel.simulateEvent("selection:update", sel);
      expect(manager.selections.has("user-a")).toBe(true);

      // Now receive a null selection for the same user
      const clearPayload = {
        user_id: "user-a",
        name: "Alice",
        color: "#ff0000",
        selection: null,
        timestamp: Date.now(),
      };
      channel.simulateEvent("selection:update", clearPayload);

      expect(manager.selections.has("user-a")).toBe(false);
      expect(manager.selections.size).toBe(0);
    });

    it("still emits selection:update event when null selection is received", () => {
      const listener = vi.fn();
      manager.on("selection:update", listener);

      const clearPayload = {
        user_id: "user-a",
        name: "Alice",
        color: "#ff0000",
        selection: null,
        timestamp: Date.now(),
      };
      channel.simulateEvent("selection:update", clearPayload);

      expect(listener).toHaveBeenCalledOnce();
      expect(listener).toHaveBeenCalledWith(clearPayload);
    });

    it("tracks multiple selections from different users", () => {
      const sel1 = makeSelection({ user_id: "user-a", selection: { start: 0, end: 5 } });
      const sel2 = makeSelection({ user_id: "user-b", selection: { start: 10, end: 20 } });

      channel.simulateEvent("selection:update", sel1);
      channel.simulateEvent("selection:update", sel2);

      expect(manager.selections.size).toBe(2);
      expect(manager.selections.get("user-a")).toEqual(sel1);
      expect(manager.selections.get("user-b")).toEqual(sel2);
    });
  });

  // ---------- sendUpdate ----------

  describe("sendUpdate()", () => {
    it("pushes selection:update to the channel with correct payload", () => {
      const selection = { start: 5, end: 15 };
      manager.sendUpdate(selection);

      expect(channel.pushLog).toHaveLength(1);
      expect(channel.pushLog[0]).toEqual({
        event: "selection:update",
        payload: { selection },
      });
    });

    it("includes element_id in payload when provided", () => {
      const selection = { start: 0, end: 10 };
      manager.sendUpdate(selection, "paragraph-3");

      expect(channel.pushLog).toHaveLength(1);
      expect(channel.pushLog[0]).toEqual({
        event: "selection:update",
        payload: { selection, element_id: "paragraph-3" },
      });
    });

    it("sends arbitrary selection data", () => {
      const complexSelection = {
        ranges: [
          { start: 0, end: 5, path: [0, 0] },
          { start: 10, end: 15, path: [1, 0] },
        ],
      };
      manager.sendUpdate(complexSelection);

      expect(channel.pushLog[0].payload).toEqual({
        selection: complexSelection,
      });
    });
  });

  // ---------- clearSelection ----------

  describe("clearSelection()", () => {
    it("pushes selection:update with null selection", () => {
      manager.clearSelection();

      expect(channel.pushLog).toHaveLength(1);
      expect(channel.pushLog[0]).toEqual({
        event: "selection:update",
        payload: { selection: null },
      });
    });
  });

  // ---------- removeSelection ----------

  describe("removeSelection()", () => {
    it("removes the specified user from the selections map", () => {
      channel.simulateEvent("selection:update", makeSelection({ user_id: "user-x" }));
      expect(manager.selections.has("user-x")).toBe(true);

      manager.removeSelection("user-x");
      expect(manager.selections.has("user-x")).toBe(false);
      expect(manager.selections.size).toBe(0);
    });

    it("does nothing when removing a non-existent user", () => {
      expect(() => manager.removeSelection("ghost")).not.toThrow();
      expect(manager.selections.size).toBe(0);
    });
  });

  // ---------- destroy ----------

  describe("destroy()", () => {
    it("clears the selections map", () => {
      channel.simulateEvent("selection:update", makeSelection({ user_id: "u1" }));
      channel.simulateEvent("selection:update", makeSelection({ user_id: "u2" }));
      expect(manager.selections.size).toBe(2);

      manager.destroy();
      expect(manager.selections.size).toBe(0);
    });

    it("removes all event listeners", () => {
      const listener = vi.fn();
      manager.on("selection:update", listener);

      manager.destroy();

      expect(manager.listenerCount("selection:update")).toBe(0);
    });

    it("can be called safely multiple times", () => {
      expect(() => {
        manager.destroy();
        manager.destroy();
      }).not.toThrow();
    });
  });
});

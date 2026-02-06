import { describe, it, expect, vi, beforeEach } from "vitest";
import { MockChannel, MockPush } from "./helpers/mock-socket.js";
import { Room } from "../src/room.js";
import type { Comment, Activity, Reaction, CursorPosition, Selection, TypingEvent, RoomState } from "../src/types.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeComment(overrides: Partial<Comment> = {}): Comment {
  return {
    id: "comment-1",
    body: "Hello world",
    user_id: "user-1",
    room_id: "room-1",
    inserted_at: "2026-01-01T00:00:00Z",
    updated_at: "2026-01-01T00:00:00Z",
    ...overrides,
  };
}

function makeReaction(overrides: Partial<Reaction> = {}): Reaction {
  return {
    id: "reaction-1",
    emoji: "thumbsup",
    comment_id: "comment-1",
    user_id: "user-1",
    inserted_at: "2026-01-01T00:00:00Z",
    ...overrides,
  };
}

function makeActivity(overrides: Partial<Activity> = {}): Activity {
  return {
    id: "activity-1",
    type: "user_joined",
    payload: {},
    room_id: "room-1",
    inserted_at: "2026-01-01T00:00:00Z",
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("Room", () => {
  let channel: MockChannel;
  let room: Room;

  beforeEach(() => {
    channel = new MockChannel("room:room-1");
    room = new Room(channel as unknown as import("phoenix").Channel, "room-1");
  });

  // -------------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------------

  describe("constructor", () => {
    it("sets roomId from the provided argument", () => {
      expect(room.roomId).toBe("room-1");
    });

    it("initializes joined to false", () => {
      expect(room.joined).toBe(false);
    });

    it("exposes the underlying channel", () => {
      expect(room.channel).toBe(channel);
    });

    it("initializes comments as empty array", () => {
      expect(room.comments).toEqual([]);
    });

    it("registers channel listeners during construction", () => {
      // The constructor calls _setupListeners, which registers handlers via channel.on.
      // Verify a known event has a handler by simulating it and checking for emission.
      const listener = vi.fn();
      room.on("cursor:update", listener);

      const cursor: CursorPosition = {
        user_id: "u1",
        name: "Alice",
        color: "#f00",
        x: 10,
        y: 20,
        timestamp: Date.now(),
      };
      channel.simulateEvent("cursor:update", cursor);

      expect(listener).toHaveBeenCalledWith(cursor);
    });
  });

  // -------------------------------------------------------------------------
  // join()
  // -------------------------------------------------------------------------

  describe("join()", () => {
    it("resolves with the server response on success", async () => {
      const promise = room.join();
      channel.simulateJoinOk({ room_id: "room-1", status: "ok" });
      await expect(promise).resolves.toEqual({ room_id: "room-1", status: "ok" });
    });

    it("sets joined to true on success", async () => {
      expect(room.joined).toBe(false);
      const promise = room.join();
      channel.simulateJoinOk({});
      await promise;
      expect(room.joined).toBe(true);
    });

    it("emits 'joined' event with the response on success", async () => {
      const listener = vi.fn();
      room.on("joined", listener);

      const promise = room.join();
      channel.simulateJoinOk({ room_id: "room-1" });
      await promise;

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith({
        response: { room_id: "room-1" },
      });
    });

    it("rejects with the error response on error", async () => {
      const promise = room.join();
      channel.simulateJoinError({ reason: "unauthorized" });
      await expect(promise).rejects.toEqual({ reason: "unauthorized" });
    });

    it("emits 'error' event on join error", async () => {
      const listener = vi.fn();
      room.on("error", listener);

      const promise = room.join();
      channel.simulateJoinError({ reason: "forbidden" });

      await promise.catch(() => {});

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith({ reason: "forbidden" });
    });

    it("emits 'error' with 'join_failed' when no reason in error response", async () => {
      const listener = vi.fn();
      room.on("error", listener);

      const promise = room.join();
      channel.simulateJoinError({});

      await promise.catch(() => {});

      expect(listener).toHaveBeenCalledWith({ reason: "join_failed" });
    });

    it("rejects with Error on timeout", async () => {
      // We need to access the internal join push to trigger timeout.
      // MockChannel.join() returns the _joinPush, and Room chains .receive("timeout", ...) on it.
      // The _joinPush is private, so we trigger timeout via the stored push.
      // We need to override channel.join to capture the push.
      const joinPush = new MockPush();
      channel.join = vi.fn().mockReturnValue(joinPush);

      // Create a new room so _setupListeners re-registers, and we call join on the new push
      const freshRoom = new Room(channel as unknown as import("phoenix").Channel, "room-1");
      const promise = freshRoom.join();
      joinPush.triggerTimeout();

      await expect(promise).rejects.toThrow("Join timed out");
    });

    it("emits 'error' event with reason 'timeout' on timeout", async () => {
      const joinPush = new MockPush();
      channel.join = vi.fn().mockReturnValue(joinPush);

      const freshRoom = new Room(channel as unknown as import("phoenix").Channel, "room-1");
      const listener = vi.fn();
      freshRoom.on("error", listener);

      const promise = freshRoom.join();
      joinPush.triggerTimeout();

      await promise.catch(() => {});

      expect(listener).toHaveBeenCalledWith({ reason: "timeout" });
    });

    it("does not set joined to true on error", async () => {
      const promise = room.join();
      channel.simulateJoinError({ reason: "unauthorized" });

      await promise.catch(() => {});
      expect(room.joined).toBe(false);
    });
  });

  // -------------------------------------------------------------------------
  // leave()
  // -------------------------------------------------------------------------

  describe("leave()", () => {
    it("calls channel.leave()", () => {
      const leaveSpy = vi.spyOn(channel, "leave");
      room.leave();
      expect(leaveSpy).toHaveBeenCalledTimes(1);
    });

    it("sets joined to false", async () => {
      // First join successfully
      const promise = room.join();
      channel.simulateJoinOk({});
      await promise;
      expect(room.joined).toBe(true);

      room.leave();
      expect(room.joined).toBe(false);
    });

    it("clears the comments array", async () => {
      // Hydrate comments via room_state
      channel.simulateEvent("room_state", {
        comments: [makeComment()],
      });
      expect(room.comments).toHaveLength(1);

      room.leave();
      expect(room.comments).toEqual([]);
    });

    it("emits 'left' event", () => {
      const listener = vi.fn();
      room.on("left", listener);
      room.leave();
      expect(listener).toHaveBeenCalledTimes(1);
    });

    it("removes all listeners after emitting left", () => {
      const leftListener = vi.fn();
      const errorListener = vi.fn();
      room.on("left", leftListener);
      room.on("error", errorListener);

      room.leave();

      // 'left' should have been called before removeAllListeners
      expect(leftListener).toHaveBeenCalledTimes(1);

      // After leave, listeners are gone, so subsequent events should not fire
      expect(room.listenerCount("left")).toBe(0);
      expect(room.listenerCount("error")).toBe(0);
    });
  });

  // -------------------------------------------------------------------------
  // push()
  // -------------------------------------------------------------------------

  describe("push()", () => {
    it("resolves with server response on ok", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const promise = room.push("custom:event", { key: "value" });
      mockPush.triggerOk({ result: "success" });

      await expect(promise).resolves.toEqual({ result: "success" });
    });

    it("passes event and payload to channel.push", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      room.push("my:event", { data: 42 });
      mockPush.triggerOk({});

      expect(channel.push).toHaveBeenCalledWith("my:event", { data: 42 });
    });

    it("defaults payload to empty object when not provided", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      room.push("my:event");
      mockPush.triggerOk({});

      expect(channel.push).toHaveBeenCalledWith("my:event", {});
    });

    it("rejects with error response on error", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const promise = room.push("custom:event", {});
      mockPush.triggerError({ reason: "not_allowed" });

      await expect(promise).rejects.toEqual({ reason: "not_allowed" });
    });

    it("rejects with Error on timeout", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const promise = room.push("custom:event", {});
      mockPush.triggerTimeout();

      await expect(promise).rejects.toThrow("Push timed out");
    });
  });

  // -------------------------------------------------------------------------
  // startTyping() / stopTyping()
  // -------------------------------------------------------------------------

  describe("startTyping()", () => {
    it("pushes typing:start event with empty payload", () => {
      room.startTyping();

      expect(channel.pushLog).toContainEqual({
        event: "typing:start",
        payload: {},
      });
    });
  });

  describe("stopTyping()", () => {
    it("pushes typing:stop event with empty payload", () => {
      room.stopTyping();

      expect(channel.pushLog).toContainEqual({
        event: "typing:stop",
        payload: {},
      });
    });
  });

  // -------------------------------------------------------------------------
  // _setupListeners: room_state
  // -------------------------------------------------------------------------

  describe("room_state event", () => {
    it("hydrates comments from room state", () => {
      const comments = [makeComment({ id: "c1" }), makeComment({ id: "c2" })];
      const state: RoomState = { comments };

      channel.simulateEvent("room_state", state);

      expect(room.comments).toEqual(comments);
      expect(room.comments).toHaveLength(2);
    });

    it("defaults comments to empty array when not provided in state", () => {
      channel.simulateEvent("room_state", {});
      expect(room.comments).toEqual([]);
    });

    it("emits 'room:state' event with the full state", () => {
      const listener = vi.fn();
      room.on("room:state", listener);

      const state: RoomState = {
        comments: [makeComment()],
        metadata: { version: 1 },
      };
      channel.simulateEvent("room_state", state);

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith(state);
    });

    it("replaces previous comments on subsequent room_state events", () => {
      channel.simulateEvent("room_state", {
        comments: [makeComment({ id: "c1" })],
      });
      expect(room.comments).toHaveLength(1);

      channel.simulateEvent("room_state", {
        comments: [makeComment({ id: "c2" }), makeComment({ id: "c3" })],
      });
      expect(room.comments).toHaveLength(2);
      expect(room.comments[0].id).toBe("c2");
    });
  });

  // -------------------------------------------------------------------------
  // _setupListeners: cursor:update
  // -------------------------------------------------------------------------

  describe("cursor:update event", () => {
    it("emits cursor:update with the cursor position payload", () => {
      const listener = vi.fn();
      room.on("cursor:update", listener);

      const cursor: CursorPosition = {
        user_id: "u1",
        name: "Alice",
        color: "#ff0000",
        x: 100,
        y: 200,
        element_id: "el-1",
        timestamp: 1700000000,
      };
      channel.simulateEvent("cursor:update", cursor);

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith(cursor);
    });
  });

  // -------------------------------------------------------------------------
  // _setupListeners: selection:update
  // -------------------------------------------------------------------------

  describe("selection:update event", () => {
    it("emits selection:update with the selection payload", () => {
      const listener = vi.fn();
      room.on("selection:update", listener);

      const selection: Selection = {
        user_id: "u1",
        name: "Bob",
        color: "#00ff00",
        selection: { start: 0, end: 10 },
        element_id: "el-2",
        timestamp: 1700000000,
      };
      channel.simulateEvent("selection:update", selection);

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith(selection);
    });
  });

  // -------------------------------------------------------------------------
  // _setupListeners: typing:start / typing:stop
  // -------------------------------------------------------------------------

  describe("typing:start event from server", () => {
    it("emits typing:start with the typing event payload", () => {
      const listener = vi.fn();
      room.on("typing:start", listener);

      const payload: TypingEvent = { user_id: "u2" };
      channel.simulateEvent("typing:start", payload);

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith(payload);
    });
  });

  describe("typing:stop event from server", () => {
    it("emits typing:stop with the typing event payload", () => {
      const listener = vi.fn();
      room.on("typing:stop", listener);

      const payload: TypingEvent = { user_id: "u2" };
      channel.simulateEvent("typing:stop", payload);

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith(payload);
    });
  });

  // -------------------------------------------------------------------------
  // _setupListeners: comment:created
  // -------------------------------------------------------------------------

  describe("comment:created event", () => {
    it("adds the comment to the comments array", () => {
      const comment = makeComment({ id: "new-comment" });
      channel.simulateEvent("comment:created", { comment });

      expect(room.comments).toHaveLength(1);
      expect(room.comments[0]).toEqual(comment);
    });

    it("appends to existing comments", () => {
      // Hydrate initial comments
      channel.simulateEvent("room_state", {
        comments: [makeComment({ id: "c1" })],
      });

      const newComment = makeComment({ id: "c2", body: "New one" });
      channel.simulateEvent("comment:created", { comment: newComment });

      expect(room.comments).toHaveLength(2);
      expect(room.comments[1]).toEqual(newComment);
    });

    it("emits comment:created event", () => {
      const listener = vi.fn();
      room.on("comment:created", listener);

      const comment = makeComment({ id: "c1" });
      channel.simulateEvent("comment:created", { comment });

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith({ comment });
    });
  });

  // -------------------------------------------------------------------------
  // _setupListeners: comment:updated
  // -------------------------------------------------------------------------

  describe("comment:updated event", () => {
    it("replaces the matching comment in the array", () => {
      channel.simulateEvent("room_state", {
        comments: [
          makeComment({ id: "c1", body: "Original" }),
          makeComment({ id: "c2", body: "Other" }),
        ],
      });

      const updated = makeComment({ id: "c1", body: "Updated" });
      channel.simulateEvent("comment:updated", { comment: updated });

      expect(room.comments).toHaveLength(2);
      expect(room.comments[0].body).toBe("Updated");
      expect(room.comments[1].body).toBe("Other");
    });

    it("does not modify array if comment id not found", () => {
      channel.simulateEvent("room_state", {
        comments: [makeComment({ id: "c1" })],
      });

      const updated = makeComment({ id: "nonexistent", body: "Ghost" });
      channel.simulateEvent("comment:updated", { comment: updated });

      expect(room.comments).toHaveLength(1);
      expect(room.comments[0].id).toBe("c1");
    });

    it("emits comment:updated event", () => {
      const listener = vi.fn();
      room.on("comment:updated", listener);

      const updated = makeComment({ id: "c1" });
      channel.simulateEvent("comment:updated", { comment: updated });

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith({ comment: updated });
    });
  });

  // -------------------------------------------------------------------------
  // _setupListeners: comment:deleted
  // -------------------------------------------------------------------------

  describe("comment:deleted event", () => {
    it("removes the matching comment from the array", () => {
      channel.simulateEvent("room_state", {
        comments: [
          makeComment({ id: "c1" }),
          makeComment({ id: "c2" }),
          makeComment({ id: "c3" }),
        ],
      });

      channel.simulateEvent("comment:deleted", { comment_id: "c2" });

      expect(room.comments).toHaveLength(2);
      expect(room.comments.map((c) => c.id)).toEqual(["c1", "c3"]);
    });

    it("does nothing if comment id not found", () => {
      channel.simulateEvent("room_state", {
        comments: [makeComment({ id: "c1" })],
      });

      channel.simulateEvent("comment:deleted", { comment_id: "nonexistent" });

      expect(room.comments).toHaveLength(1);
    });

    it("emits comment:deleted event with comment_id", () => {
      const listener = vi.fn();
      room.on("comment:deleted", listener);

      channel.simulateEvent("comment:deleted", { comment_id: "c1" });

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith({ comment_id: "c1" });
    });
  });

  // -------------------------------------------------------------------------
  // _setupListeners: comment:resolved
  // -------------------------------------------------------------------------

  describe("comment:resolved event", () => {
    it("replaces the matching comment in the array with resolved version", () => {
      const original = makeComment({ id: "c1", resolved_at: null });
      channel.simulateEvent("room_state", { comments: [original] });

      const resolved = makeComment({
        id: "c1",
        resolved_at: "2026-02-06T12:00:00Z",
      });
      channel.simulateEvent("comment:resolved", { comment: resolved });

      expect(room.comments).toHaveLength(1);
      expect(room.comments[0].resolved_at).toBe("2026-02-06T12:00:00Z");
    });

    it("does not modify array if comment id not found", () => {
      channel.simulateEvent("room_state", {
        comments: [makeComment({ id: "c1" })],
      });

      const resolved = makeComment({ id: "nonexistent" });
      channel.simulateEvent("comment:resolved", { comment: resolved });

      expect(room.comments).toHaveLength(1);
      expect(room.comments[0].id).toBe("c1");
    });

    it("emits comment:resolved event", () => {
      const listener = vi.fn();
      room.on("comment:resolved", listener);

      const resolved = makeComment({
        id: "c1",
        resolved_at: "2026-02-06T12:00:00Z",
      });
      channel.simulateEvent("comment:resolved", { comment: resolved });

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith({ comment: resolved });
    });
  });

  // -------------------------------------------------------------------------
  // _setupListeners: reaction:added
  // -------------------------------------------------------------------------

  describe("reaction:added event", () => {
    it("emits reaction:added with the reaction payload", () => {
      const listener = vi.fn();
      room.on("reaction:added", listener);

      const reaction = makeReaction({ id: "r1", emoji: "heart" });
      channel.simulateEvent("reaction:added", { reaction });

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith({ reaction });
    });
  });

  // -------------------------------------------------------------------------
  // _setupListeners: reaction:removed
  // -------------------------------------------------------------------------

  describe("reaction:removed event", () => {
    it("emits reaction:removed with the removal payload", () => {
      const listener = vi.fn();
      room.on("reaction:removed", listener);

      const payload = {
        reaction_id: "r1",
        comment_id: "c1",
        user_id: "u1",
        emoji: "thumbsup",
      };
      channel.simulateEvent("reaction:removed", payload);

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith(payload);
    });
  });

  // -------------------------------------------------------------------------
  // _setupListeners: activity:created
  // -------------------------------------------------------------------------

  describe("activity:created event", () => {
    it("emits activity:created with the activity payload", () => {
      const listener = vi.fn();
      room.on("activity:created", listener);

      const activity = makeActivity({ id: "a1", type: "comment_created" });
      channel.simulateEvent("activity:created", { activity });

      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith({ activity });
    });
  });

  // -------------------------------------------------------------------------
  // Integration: full lifecycle
  // -------------------------------------------------------------------------

  describe("full lifecycle", () => {
    it("join -> receive state -> add comment -> leave clears everything", async () => {
      // Join
      const joinPromise = room.join();
      channel.simulateJoinOk({ room_id: "room-1" });
      await joinPromise;
      expect(room.joined).toBe(true);

      // Receive room state
      channel.simulateEvent("room_state", {
        comments: [makeComment({ id: "c1" })],
      });
      expect(room.comments).toHaveLength(1);

      // Add a comment
      channel.simulateEvent("comment:created", {
        comment: makeComment({ id: "c2" }),
      });
      expect(room.comments).toHaveLength(2);

      // Leave
      room.leave();
      expect(room.joined).toBe(false);
      expect(room.comments).toEqual([]);
    });
  });
});

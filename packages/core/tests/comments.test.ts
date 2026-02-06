import { describe, it, expect, vi, beforeEach } from "vitest";
import type { Comment } from "../src/types.js";
import type { Room } from "../src/room.js";
import { CommentManager } from "../src/comments.js";

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const mockComment: Comment = {
  id: "comment-1",
  body: "This needs work",
  anchor_id: "element-42",
  anchor_type: "element",
  position: { x: 100, y: 200 },
  resolved_at: null,
  user_id: "user-1",
  room_id: "room-1",
  parent_id: null,
  inserted_at: "2026-01-15T10:00:00Z",
  updated_at: "2026-01-15T10:00:00Z",
};

const resolvedComment: Comment = {
  ...mockComment,
  resolved_at: "2026-01-15T12:00:00Z",
};

// ---------------------------------------------------------------------------
// Mock Room
// ---------------------------------------------------------------------------

function createMockRoom(comments: Comment[] = []) {
  const mockRoom = {
    comments,
    push: vi.fn(),
    on: vi.fn().mockReturnValue(() => {}),
  } as unknown as Room;
  return mockRoom;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("CommentManager", () => {
  let mockRoom: Room;
  let manager: CommentManager;

  beforeEach(() => {
    mockRoom = createMockRoom([mockComment]);
    manager = new CommentManager(mockRoom);
  });

  // -----------------------------------------------------------------------
  // comments getter
  // -----------------------------------------------------------------------

  describe("comments getter", () => {
    it("delegates to room.comments", () => {
      expect(manager.comments).toBe(mockRoom.comments);
    });

    it("returns empty array when room has no comments", () => {
      const emptyRoom = createMockRoom([]);
      const emptyManager = new CommentManager(emptyRoom);
      expect(emptyManager.comments).toEqual([]);
    });

    it("reflects the same reference as the room", () => {
      const comments = [mockComment];
      const room = createMockRoom(comments);
      const mgr = new CommentManager(room);
      expect(mgr.comments).toBe(comments);
    });
  });

  // -----------------------------------------------------------------------
  // create()
  // -----------------------------------------------------------------------

  describe("create()", () => {
    it("pushes comment:create with params and returns the comment", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        comment: mockComment,
      });

      const params = {
        body: "This needs work",
        anchor_id: "element-42",
        anchor_type: "element" as const,
        position: { x: 100, y: 200 },
      };

      const result = await manager.create(params);

      expect(mockRoom.push).toHaveBeenCalledWith("comment:create", params);
      expect(result).toEqual(mockComment);
    });

    it("pushes comment:create with minimal params", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        comment: mockComment,
      });

      const params = { body: "Simple comment" };
      await manager.create(params);

      expect(mockRoom.push).toHaveBeenCalledWith("comment:create", params);
    });

    it("passes parent_id for threaded replies", async () => {
      const replyComment: Comment = {
        ...mockComment,
        id: "comment-2",
        parent_id: "comment-1",
      };
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        comment: replyComment,
      });

      const params = { body: "Reply to comment", parent_id: "comment-1" };
      const result = await manager.create(params);

      expect(mockRoom.push).toHaveBeenCalledWith("comment:create", params);
      expect(result.parent_id).toBe("comment-1");
    });
  });

  // -----------------------------------------------------------------------
  // update()
  // -----------------------------------------------------------------------

  describe("update()", () => {
    it("pushes comment:update with params and returns updated comment", async () => {
      const updatedComment: Comment = { ...mockComment, body: "Updated body" };
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        comment: updatedComment,
      });

      const params = { id: "comment-1", body: "Updated body" };
      const result = await manager.update(params);

      expect(mockRoom.push).toHaveBeenCalledWith("comment:update", params);
      expect(result.body).toBe("Updated body");
    });

    it("supports partial updates", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        comment: mockComment,
      });

      const params = { id: "comment-1", anchor_id: "new-element" };
      await manager.update(params);

      expect(mockRoom.push).toHaveBeenCalledWith("comment:update", params);
    });
  });

  // -----------------------------------------------------------------------
  // delete()
  // -----------------------------------------------------------------------

  describe("delete()", () => {
    it("pushes comment:delete with the comment id", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({});

      await manager.delete("comment-1");

      expect(mockRoom.push).toHaveBeenCalledWith("comment:delete", {
        id: "comment-1",
      });
    });

    it("resolves without returning a value", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({});

      const result = await manager.delete("comment-1");

      expect(result).toBeUndefined();
    });
  });

  // -----------------------------------------------------------------------
  // resolve()
  // -----------------------------------------------------------------------

  describe("resolve()", () => {
    it("pushes comment:resolve with resolved: true", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        comment: resolvedComment,
      });

      const result = await manager.resolve("comment-1");

      expect(mockRoom.push).toHaveBeenCalledWith("comment:resolve", {
        id: "comment-1",
        resolved: true,
      });
      expect(result.resolved_at).toBeTruthy();
    });
  });

  // -----------------------------------------------------------------------
  // unresolve()
  // -----------------------------------------------------------------------

  describe("unresolve()", () => {
    it("pushes comment:resolve with resolved: false", async () => {
      const unresolvedComment: Comment = {
        ...mockComment,
        resolved_at: null,
      };
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        comment: unresolvedComment,
      });

      const result = await manager.unresolve("comment-1");

      expect(mockRoom.push).toHaveBeenCalledWith("comment:resolve", {
        id: "comment-1",
        resolved: false,
      });
      expect(result.resolved_at).toBeNull();
    });
  });

  // -----------------------------------------------------------------------
  // Event subscriptions
  // -----------------------------------------------------------------------

  describe("onCreated()", () => {
    it("subscribes to comment:created via room.on()", () => {
      const cb = vi.fn();
      manager.onCreated(cb);

      expect(mockRoom.on).toHaveBeenCalledWith(
        "comment:created",
        expect.any(Function)
      );
    });

    it("returns an unsubscribe function", () => {
      const unsub = vi.fn();
      (mockRoom.on as ReturnType<typeof vi.fn>).mockReturnValue(unsub);

      const result = manager.onCreated(vi.fn());
      expect(result).toBe(unsub);
    });

    it("unwraps the comment payload before calling the callback", () => {
      let capturedHandler: (data: { comment: Comment }) => void = () => {};
      (mockRoom.on as ReturnType<typeof vi.fn>).mockImplementation(
        (_event: string, handler: (data: { comment: Comment }) => void) => {
          capturedHandler = handler;
          return () => {};
        }
      );

      const cb = vi.fn();
      manager.onCreated(cb);

      // Simulate the room emitting the event
      capturedHandler({ comment: mockComment });

      expect(cb).toHaveBeenCalledWith(mockComment);
    });
  });

  describe("onUpdated()", () => {
    it("subscribes to comment:updated via room.on()", () => {
      const cb = vi.fn();
      manager.onUpdated(cb);

      expect(mockRoom.on).toHaveBeenCalledWith(
        "comment:updated",
        expect.any(Function)
      );
    });

    it("unwraps the comment payload before calling the callback", () => {
      let capturedHandler: (data: { comment: Comment }) => void = () => {};
      (mockRoom.on as ReturnType<typeof vi.fn>).mockImplementation(
        (_event: string, handler: (data: { comment: Comment }) => void) => {
          capturedHandler = handler;
          return () => {};
        }
      );

      const cb = vi.fn();
      manager.onUpdated(cb);

      capturedHandler({ comment: { ...mockComment, body: "Changed" } });

      expect(cb).toHaveBeenCalledWith(
        expect.objectContaining({ body: "Changed" })
      );
    });
  });

  describe("onDeleted()", () => {
    it("subscribes to comment:deleted via room.on()", () => {
      const cb = vi.fn();
      manager.onDeleted(cb);

      expect(mockRoom.on).toHaveBeenCalledWith(
        "comment:deleted",
        expect.any(Function)
      );
    });

    it("unwraps the comment_id payload before calling the callback", () => {
      let capturedHandler: (data: { comment_id: string }) => void = () => {};
      (mockRoom.on as ReturnType<typeof vi.fn>).mockImplementation(
        (_event: string, handler: (data: { comment_id: string }) => void) => {
          capturedHandler = handler;
          return () => {};
        }
      );

      const cb = vi.fn();
      manager.onDeleted(cb);

      capturedHandler({ comment_id: "comment-1" });

      expect(cb).toHaveBeenCalledWith("comment-1");
    });
  });

  describe("onResolved()", () => {
    it("subscribes to comment:resolved via room.on()", () => {
      const cb = vi.fn();
      manager.onResolved(cb);

      expect(mockRoom.on).toHaveBeenCalledWith(
        "comment:resolved",
        expect.any(Function)
      );
    });

    it("returns an unsubscribe function", () => {
      const unsub = vi.fn();
      (mockRoom.on as ReturnType<typeof vi.fn>).mockReturnValue(unsub);

      const result = manager.onResolved(vi.fn());
      expect(result).toBe(unsub);
    });

    it("unwraps the comment payload before calling the callback", () => {
      let capturedHandler: (data: { comment: Comment }) => void = () => {};
      (mockRoom.on as ReturnType<typeof vi.fn>).mockImplementation(
        (_event: string, handler: (data: { comment: Comment }) => void) => {
          capturedHandler = handler;
          return () => {};
        }
      );

      const cb = vi.fn();
      manager.onResolved(cb);

      capturedHandler({ comment: resolvedComment });

      expect(cb).toHaveBeenCalledWith(resolvedComment);
    });
  });
});

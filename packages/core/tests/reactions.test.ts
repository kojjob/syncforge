import { describe, it, expect, vi, beforeEach } from "vitest";
import type { Reaction, RoomEventMap } from "../src/types.js";
import type { Room } from "../src/room.js";
import { ReactionManager } from "../src/reactions.js";

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const mockReaction: Reaction = {
  id: "reaction-1",
  emoji: "thumbs_up",
  comment_id: "comment-1",
  user_id: "user-1",
  inserted_at: "2026-01-15T10:30:00Z",
};

// ---------------------------------------------------------------------------
// Mock Room
// ---------------------------------------------------------------------------

function createMockRoom() {
  const mockRoom = {
    push: vi.fn(),
    on: vi.fn().mockReturnValue(() => {}),
  } as unknown as Room;
  return mockRoom;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("ReactionManager", () => {
  let mockRoom: Room;
  let manager: ReactionManager;

  beforeEach(() => {
    mockRoom = createMockRoom();
    manager = new ReactionManager(mockRoom);
  });

  // -----------------------------------------------------------------------
  // add()
  // -----------------------------------------------------------------------

  describe("add()", () => {
    it("pushes reaction:add with comment_id and emoji", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        reaction: mockReaction,
      });

      const result = await manager.add("comment-1", "thumbs_up");

      expect(mockRoom.push).toHaveBeenCalledWith("reaction:add", {
        comment_id: "comment-1",
        emoji: "thumbs_up",
      });
      expect(result).toEqual(mockReaction);
    });

    it("returns the reaction from the server response", async () => {
      const heartReaction: Reaction = {
        ...mockReaction,
        id: "reaction-2",
        emoji: "heart",
      };
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        reaction: heartReaction,
      });

      const result = await manager.add("comment-1", "heart");

      expect(result.emoji).toBe("heart");
      expect(result.id).toBe("reaction-2");
    });
  });

  // -----------------------------------------------------------------------
  // remove()
  // -----------------------------------------------------------------------

  describe("remove()", () => {
    it("pushes reaction:remove with comment_id and emoji", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({});

      await manager.remove("comment-1", "thumbs_up");

      expect(mockRoom.push).toHaveBeenCalledWith("reaction:remove", {
        comment_id: "comment-1",
        emoji: "thumbs_up",
      });
    });

    it("resolves without returning a value", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({});

      const result = await manager.remove("comment-1", "thumbs_up");

      expect(result).toBeUndefined();
    });
  });

  // -----------------------------------------------------------------------
  // toggle()
  // -----------------------------------------------------------------------

  describe("toggle()", () => {
    it("pushes reaction:toggle with comment_id and emoji", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        action: "added",
        reaction: mockReaction,
      });

      await manager.toggle("comment-1", "thumbs_up");

      expect(mockRoom.push).toHaveBeenCalledWith("reaction:toggle", {
        comment_id: "comment-1",
        emoji: "thumbs_up",
      });
    });

    it("returns action 'added' with reaction when adding", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        action: "added",
        reaction: mockReaction,
      });

      const result = await manager.toggle("comment-1", "thumbs_up");

      expect(result.action).toBe("added");
      expect(result.reaction).toEqual(mockReaction);
    });

    it("returns action 'removed' without reaction when removing", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        action: "removed",
      });

      const result = await manager.toggle("comment-1", "thumbs_up");

      expect(result.action).toBe("removed");
      expect(result.reaction).toBeUndefined();
    });
  });

  // -----------------------------------------------------------------------
  // Event subscriptions
  // -----------------------------------------------------------------------

  describe("onAdded()", () => {
    it("subscribes to reaction:added via room.on()", () => {
      const cb = vi.fn();
      manager.onAdded(cb);

      expect(mockRoom.on).toHaveBeenCalledWith(
        "reaction:added",
        expect.any(Function)
      );
    });

    it("returns an unsubscribe function", () => {
      const unsub = vi.fn();
      (mockRoom.on as ReturnType<typeof vi.fn>).mockReturnValue(unsub);

      const result = manager.onAdded(vi.fn());
      expect(result).toBe(unsub);
    });

    it("unwraps the reaction payload before calling the callback", () => {
      let capturedHandler: (data: { reaction: Reaction }) => void = () => {};
      (mockRoom.on as ReturnType<typeof vi.fn>).mockImplementation(
        (_event: string, handler: (data: { reaction: Reaction }) => void) => {
          capturedHandler = handler;
          return () => {};
        }
      );

      const cb = vi.fn();
      manager.onAdded(cb);

      capturedHandler({ reaction: mockReaction });

      expect(cb).toHaveBeenCalledWith(mockReaction);
    });
  });

  describe("onRemoved()", () => {
    it("subscribes to reaction:removed via room.on()", () => {
      const cb = vi.fn();
      manager.onRemoved(cb);

      expect(mockRoom.on).toHaveBeenCalledWith(
        "reaction:removed",
        expect.any(Function)
      );
    });

    it("returns an unsubscribe function", () => {
      const unsub = vi.fn();
      (mockRoom.on as ReturnType<typeof vi.fn>).mockReturnValue(unsub);

      const result = manager.onRemoved(vi.fn());
      expect(result).toBe(unsub);
    });

    it("passes the full removal payload to the callback", () => {
      let capturedHandler: (
        data: RoomEventMap["reaction:removed"]
      ) => void = () => {};
      (mockRoom.on as ReturnType<typeof vi.fn>).mockImplementation(
        (
          _event: string,
          handler: (data: RoomEventMap["reaction:removed"]) => void
        ) => {
          capturedHandler = handler;
          return () => {};
        }
      );

      const cb = vi.fn();
      manager.onRemoved(cb);

      const removalData: RoomEventMap["reaction:removed"] = {
        reaction_id: "reaction-1",
        comment_id: "comment-1",
        user_id: "user-1",
        emoji: "thumbs_up",
      };
      capturedHandler(removalData);

      expect(cb).toHaveBeenCalledWith(removalData);
    });
  });
});

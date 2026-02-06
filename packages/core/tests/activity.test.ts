import { describe, it, expect, vi, beforeEach } from "vitest";
import type { Activity } from "../src/types.js";
import type { Room } from "../src/room.js";
import { ActivityManager } from "../src/activity.js";

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const mockActivity: Activity = {
  id: "activity-1",
  type: "comment_created",
  actor_id: "user-1",
  subject_id: "comment-1",
  subject_type: "comment",
  payload: { body: "Hello world" },
  room_id: "room-1",
  inserted_at: "2026-01-15T10:00:00Z",
};

const mockActivities: Activity[] = [
  mockActivity,
  {
    id: "activity-2",
    type: "user_joined",
    actor_id: "user-2",
    subject_id: null,
    subject_type: null,
    payload: {},
    room_id: "room-1",
    inserted_at: "2026-01-15T09:00:00Z",
  },
  {
    id: "activity-3",
    type: "reaction_added",
    actor_id: "user-1",
    subject_id: "reaction-1",
    subject_type: "reaction",
    payload: { emoji: "thumbs_up", comment_id: "comment-1" },
    room_id: "room-1",
    inserted_at: "2026-01-15T11:00:00Z",
  },
];

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

describe("ActivityManager", () => {
  let mockRoom: Room;
  let manager: ActivityManager;

  beforeEach(() => {
    mockRoom = createMockRoom();
    manager = new ActivityManager(mockRoom);
  });

  // -----------------------------------------------------------------------
  // list()
  // -----------------------------------------------------------------------

  describe("list()", () => {
    it("pushes activity:list with default limit 50 and offset 0", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        activities: mockActivities,
      });

      const result = await manager.list();

      expect(mockRoom.push).toHaveBeenCalledWith("activity:list", {
        limit: 50,
        offset: 0,
      });
      expect(result).toEqual(mockActivities);
    });

    it("passes custom limit and offset options", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        activities: [mockActivity],
      });

      const result = await manager.list({ limit: 10, offset: 20 });

      expect(mockRoom.push).toHaveBeenCalledWith("activity:list", {
        limit: 10,
        offset: 20,
      });
      expect(result).toEqual([mockActivity]);
    });

    it("uses default limit when only offset is provided", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        activities: [],
      });

      await manager.list({ offset: 5 });

      expect(mockRoom.push).toHaveBeenCalledWith("activity:list", {
        limit: 50,
        offset: 5,
      });
    });

    it("uses default offset when only limit is provided", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        activities: [],
      });

      await manager.list({ limit: 25 });

      expect(mockRoom.push).toHaveBeenCalledWith("activity:list", {
        limit: 25,
        offset: 0,
      });
    });

    it("returns empty array when no activities exist", async () => {
      (mockRoom.push as ReturnType<typeof vi.fn>).mockResolvedValue({
        activities: [],
      });

      const result = await manager.list();

      expect(result).toEqual([]);
    });
  });

  // -----------------------------------------------------------------------
  // onCreated()
  // -----------------------------------------------------------------------

  describe("onCreated()", () => {
    it("subscribes to activity:created via room.on()", () => {
      const cb = vi.fn();
      manager.onCreated(cb);

      expect(mockRoom.on).toHaveBeenCalledWith(
        "activity:created",
        expect.any(Function)
      );
    });

    it("returns an unsubscribe function", () => {
      const unsub = vi.fn();
      (mockRoom.on as ReturnType<typeof vi.fn>).mockReturnValue(unsub);

      const result = manager.onCreated(vi.fn());
      expect(result).toBe(unsub);
    });

    it("unwraps the activity payload before calling the callback", () => {
      let capturedHandler: (data: { activity: Activity }) => void = () => {};
      (mockRoom.on as ReturnType<typeof vi.fn>).mockImplementation(
        (_event: string, handler: (data: { activity: Activity }) => void) => {
          capturedHandler = handler;
          return () => {};
        }
      );

      const cb = vi.fn();
      manager.onCreated(cb);

      capturedHandler({ activity: mockActivity });

      expect(cb).toHaveBeenCalledWith(mockActivity);
    });
  });
});

import { describe, it, expect, vi, beforeEach, type Mock } from "vitest";
import { renderHook, act, waitFor } from "@testing-library/react";
import type { CursorPosition } from "@syncforge/core";

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

const mockSendUpdate = vi.fn();
const mockDestroy = vi.fn();
const mockCursorOn = vi.fn(() => vi.fn()); // returns unsubscribe

let cursorsMap = new Map<string, CursorPosition>();
let cursorUpdateCallback:
  | ((payload: CursorPosition) => void)
  | null = null;

const mockCursorInstance = {
  cursors: cursorsMap,
  sendUpdate: mockSendUpdate,
  destroy: mockDestroy,
  removeCursor: vi.fn(),
  lerp: vi.fn(),
  on: mockCursorOn,
  off: vi.fn(),
  removeAllListeners: vi.fn(),
  emit: vi.fn(),
};

vi.mock("@syncforge/core", () => ({
  SyncForgeClient: vi.fn(),
  Room: vi.fn(),
  PresenceManager: vi.fn(),
  CursorManager: vi.fn(() => mockCursorInstance),
  CommentManager: vi.fn(),
  NotificationManager: vi.fn(),
}));

import { useCursors } from "../../src/hooks/useCursors.js";
import { CursorManager } from "@syncforge/core";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeCursor(overrides: Partial<CursorPosition> = {}): CursorPosition {
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

function createMockRoom() {
  return {
    roomId: "room-1",
    channel: { on: vi.fn(), push: vi.fn() },
    joined: true,
    comments: [],
    join: vi.fn(),
    leave: vi.fn(),
    push: vi.fn(),
    on: vi.fn(() => vi.fn()),
    off: vi.fn(),
    removeAllListeners: vi.fn(),
    emit: vi.fn(),
  };
}

function resetMocks() {
  vi.clearAllMocks();
  cursorsMap = new Map();
  cursorUpdateCallback = null;
  mockCursorInstance.cursors = cursorsMap;

  // Capture the "cursor:update" callback when on() is called
  mockCursorOn.mockImplementation((event: string, cb: unknown) => {
    if (event === "cursor:update") {
      cursorUpdateCallback = cb as (payload: CursorPosition) => void;
    }
    return vi.fn(); // unsubscribe
  });

  (CursorManager as unknown as Mock).mockImplementation(
    () => mockCursorInstance
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("useCursors", () => {
  beforeEach(() => {
    resetMocks();
  });

  it("returns empty cursors when room is null", () => {
    const { result } = renderHook(() => useCursors(null));

    expect(result.current.cursors).toEqual(new Map());
    expect(CursorManager).not.toHaveBeenCalled();
  });

  it("creates CursorManager when room is provided", () => {
    const mockRoom = createMockRoom();

    renderHook(() => useCursors(mockRoom as any));

    expect(CursorManager).toHaveBeenCalledWith(mockRoom.channel);
  });

  it("sendUpdate calls manager.sendUpdate", () => {
    const mockRoom = createMockRoom();

    const { result } = renderHook(() => useCursors(mockRoom as any));

    act(() => {
      result.current.sendUpdate(150, 250);
    });

    expect(mockSendUpdate).toHaveBeenCalledWith(150, 250, undefined);
  });

  it("sendUpdate passes elementId when provided", () => {
    const mockRoom = createMockRoom();

    const { result } = renderHook(() => useCursors(mockRoom as any));

    act(() => {
      result.current.sendUpdate(150, 250, "editor-canvas");
    });

    expect(mockSendUpdate).toHaveBeenCalledWith(150, 250, "editor-canvas");
  });

  it("destroys manager on unmount", () => {
    const mockRoom = createMockRoom();

    const { unmount } = renderHook(() => useCursors(mockRoom as any));

    expect(CursorManager).toHaveBeenCalled();

    unmount();

    expect(mockDestroy).toHaveBeenCalled();
  });

  it("updates cursors on cursor:update events", async () => {
    const mockRoom = createMockRoom();
    const cursor = makeCursor({ user_id: "user-2", x: 300, y: 400 });

    const { result } = renderHook(() => useCursors(mockRoom as any));

    // Verify the listener was registered
    expect(mockCursorOn).toHaveBeenCalledWith(
      "cursor:update",
      expect.any(Function)
    );

    // Simulate a cursor:update event
    if (cursorUpdateCallback) {
      // Also update the mock's internal map to reflect the new cursor
      cursorsMap.set("user-2", cursor);
      cursorUpdateCallback(cursor);
    }

    await waitFor(() => {
      expect(result.current.cursors.get("user-2")).toEqual(cursor);
    });
  });

  it("recreates CursorManager when room changes", () => {
    const room1 = createMockRoom();
    const room2 = createMockRoom();
    room2.roomId = "room-2";
    room2.channel = { on: vi.fn(), push: vi.fn() };

    const { rerender } = renderHook(
      ({ room }: { room: any }) => useCursors(room),
      { initialProps: { room: room1 } }
    );

    expect(CursorManager).toHaveBeenCalledWith(room1.channel);
    mockDestroy.mockClear();

    rerender({ room: room2 });

    // Should destroy old and create new
    expect(mockDestroy).toHaveBeenCalled();
    expect(CursorManager).toHaveBeenCalledWith(room2.channel);
  });

  it("cleans up when room becomes null", () => {
    const mockRoom = createMockRoom();

    const { rerender } = renderHook(
      ({ room }: { room: any }) => useCursors(room),
      { initialProps: { room: mockRoom } }
    );

    expect(CursorManager).toHaveBeenCalled();

    rerender({ room: null });

    expect(mockDestroy).toHaveBeenCalled();
  });

  it("returns a stable sendUpdate function reference", () => {
    const mockRoom = createMockRoom();

    const { result, rerender } = renderHook(() =>
      useCursors(mockRoom as any)
    );

    const firstRef = result.current.sendUpdate;

    rerender();

    // sendUpdate should be stable across renders (useCallback)
    expect(result.current.sendUpdate).toBe(firstRef);
  });
});

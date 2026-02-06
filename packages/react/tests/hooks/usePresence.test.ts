import { describe, it, expect, vi, beforeEach, type Mock } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import type { PresenceUser } from "@syncforge/core";

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

const mockAttach = vi.fn();
const mockDetach = vi.fn();
const mockPresenceOn = vi.fn(() => vi.fn()); // returns unsubscribe

let presenceUsers: PresenceUser[] = [];
let syncCallback: ((payload: { users: PresenceUser[] }) => void) | null = null;

const mockPresenceInstance = {
  users: presenceUsers,
  attach: mockAttach,
  detach: mockDetach,
  on: mockPresenceOn,
  off: vi.fn(),
  removeAllListeners: vi.fn(),
  emit: vi.fn(),
  updatePresence: vi.fn(),
};

vi.mock("@syncforge/core", () => ({
  SyncForgeClient: vi.fn(),
  Room: vi.fn(),
  PresenceManager: vi.fn(() => mockPresenceInstance),
  CursorManager: vi.fn(),
  CommentManager: vi.fn(),
  NotificationManager: vi.fn(),
}));

import { usePresence } from "../../src/hooks/usePresence.js";
import { PresenceManager } from "@syncforge/core";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeUser(overrides: Partial<PresenceUser> = {}): PresenceUser {
  return {
    id: "user-1",
    name: "Alice",
    status: "online",
    joined_at: "2026-01-01T00:00:00Z",
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
  presenceUsers = [];
  syncCallback = null;
  mockPresenceInstance.users = presenceUsers;
  mockAttach.mockResolvedValue(undefined);

  // Capture the "presence:sync" callback when on() is called
  mockPresenceOn.mockImplementation((event: string, cb: unknown) => {
    if (event === "presence:sync") {
      syncCallback = cb as (payload: { users: PresenceUser[] }) => void;
    }
    return vi.fn(); // unsubscribe
  });

  (PresenceManager as unknown as Mock).mockImplementation(
    () => mockPresenceInstance
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("usePresence", () => {
  beforeEach(() => {
    resetMocks();
  });

  it("returns empty users when room is null", () => {
    const { result } = renderHook(() => usePresence(null));

    expect(result.current.users).toEqual([]);
    expect(PresenceManager).not.toHaveBeenCalled();
  });

  it("attaches PresenceManager when room is provided", async () => {
    const mockRoom = createMockRoom();

    renderHook(() => usePresence(mockRoom as any));

    expect(PresenceManager).toHaveBeenCalled();

    await waitFor(() => {
      expect(mockAttach).toHaveBeenCalledWith(mockRoom.channel);
    });
  });

  it("updates users on presence:sync event", async () => {
    const mockRoom = createMockRoom();
    const alice = makeUser({ id: "user-1", name: "Alice" });
    const bob = makeUser({ id: "user-2", name: "Bob" });

    const { result } = renderHook(() => usePresence(mockRoom as any));

    await waitFor(() => {
      expect(mockPresenceOn).toHaveBeenCalledWith(
        "presence:sync",
        expect.any(Function)
      );
    });

    // Simulate a presence:sync event
    if (syncCallback) {
      syncCallback({ users: [alice, bob] });
    }

    await waitFor(() => {
      expect(result.current.users).toHaveLength(2);
      expect(result.current.users[0].name).toBe("Alice");
      expect(result.current.users[1].name).toBe("Bob");
    });
  });

  it("detaches on unmount", async () => {
    const mockRoom = createMockRoom();

    const { unmount } = renderHook(() => usePresence(mockRoom as any));

    await waitFor(() => {
      expect(mockAttach).toHaveBeenCalled();
    });

    unmount();

    expect(mockDetach).toHaveBeenCalled();
  });

  it("returns isLoading=true initially", () => {
    const mockRoom = createMockRoom();

    const { result } = renderHook(() => usePresence(mockRoom as any));

    expect(result.current.isLoading).toBe(true);
  });

  it("sets isLoading=false after presence:sync", async () => {
    const mockRoom = createMockRoom();
    const alice = makeUser();

    const { result } = renderHook(() => usePresence(mockRoom as any));

    expect(result.current.isLoading).toBe(true);

    // Trigger sync
    if (syncCallback) {
      syncCallback({ users: [alice] });
    }

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });
  });

  it("re-attaches when room changes", async () => {
    const room1 = createMockRoom();
    const room2 = createMockRoom();
    room2.roomId = "room-2";
    room2.channel = { on: vi.fn(), push: vi.fn() };

    const { rerender } = renderHook(
      ({ room }: { room: any }) => usePresence(room),
      { initialProps: { room: room1 } }
    );

    await waitFor(() => {
      expect(mockAttach).toHaveBeenCalledWith(room1.channel);
    });

    mockAttach.mockClear();
    mockDetach.mockClear();

    rerender({ room: room2 });

    // Should detach from old and attach to new
    expect(mockDetach).toHaveBeenCalled();

    await waitFor(() => {
      expect(mockAttach).toHaveBeenCalledWith(room2.channel);
    });
  });

  it("cleans up when room becomes null", async () => {
    const mockRoom = createMockRoom();

    const { rerender } = renderHook(
      ({ room }: { room: any }) => usePresence(room),
      { initialProps: { room: mockRoom } }
    );

    await waitFor(() => {
      expect(mockAttach).toHaveBeenCalled();
    });

    rerender({ room: null });

    expect(mockDetach).toHaveBeenCalled();
  });
});

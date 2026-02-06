import { describe, it, expect, vi, beforeEach, type Mock } from "vitest";
import { renderHook, act, waitFor } from "@testing-library/react";

// ---------------------------------------------------------------------------
// Mocks — must be declared before imports that use them
// ---------------------------------------------------------------------------

const mockJoin = vi.fn();
const mockLeave = vi.fn();
const mockPush = vi.fn();
const mockRoomOn = vi.fn(() => vi.fn()); // returns unsubscribe
const mockChannelOn = vi.fn();

const mockRoomInstance = {
  roomId: "room-1",
  channel: { on: mockChannelOn },
  joined: false,
  comments: [],
  join: mockJoin,
  leave: mockLeave,
  push: mockPush,
  on: mockRoomOn,
  off: vi.fn(),
  removeAllListeners: vi.fn(),
  emit: vi.fn(),
};

const mockChannel = {
  join: vi.fn(),
  leave: vi.fn(),
  push: vi.fn(),
  on: mockChannelOn,
};

const mockJoinRoom = vi.fn(() => ({
  channel: mockChannel,
  roomId: "room-1",
}));

const mockClient = {
  state: "connected" as const,
  socket: {},
  joinRoom: mockJoinRoom,
  joinNotifications: vi.fn(),
  connect: vi.fn(),
  disconnect: vi.fn(),
  on: vi.fn(() => vi.fn()),
  off: vi.fn(),
  removeAllListeners: vi.fn(),
  emit: vi.fn(),
};

vi.mock("@syncforge/core", () => ({
  SyncForgeClient: vi.fn(() => mockClient),
  Room: vi.fn(() => mockRoomInstance),
  PresenceManager: vi.fn(),
  CursorManager: vi.fn(),
  CommentManager: vi.fn(),
  NotificationManager: vi.fn(),
}));

vi.mock("../../src/provider.js", () => ({
  useSyncForge: vi.fn(() => ({
    client: mockClient,
    connectionState: "connected",
  })),
  SyncForgeProvider: vi.fn(),
}));

import { useRoom } from "../../src/hooks/useRoom.js";
import { Room } from "@syncforge/core";
import { useSyncForge } from "../../src/provider.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function resetMocks() {
  vi.clearAllMocks();
  mockRoomInstance.joined = false;
  mockJoin.mockResolvedValue({ status: "ok" });
  (useSyncForge as Mock).mockReturnValue({
    client: mockClient,
    connectionState: "connected",
  });
  (Room as unknown as Mock).mockImplementation(() => mockRoomInstance);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("useRoom", () => {
  beforeEach(() => {
    resetMocks();
  });

  it("returns null room before joining", () => {
    // Client is null — no room can be created
    (useSyncForge as Mock).mockReturnValue({
      client: null,
      connectionState: "disconnected",
    });

    const { result } = renderHook(() => useRoom("room-1"));

    expect(result.current.room).toBeNull();
    expect(result.current.joined).toBe(false);
    expect(result.current.error).toBeNull();
  });

  it("joins room on mount and returns Room instance", async () => {
    mockJoin.mockResolvedValue({ status: "ok" });

    const { result } = renderHook(() => useRoom("room-1"));

    // Room constructor should have been called
    expect(Room).toHaveBeenCalledWith(mockChannel, "room-1");
    expect(mockClient.joinRoom).toHaveBeenCalledWith("room-1", undefined);

    await waitFor(() => {
      expect(mockJoin).toHaveBeenCalled();
    });

    expect(result.current.room).toBe(mockRoomInstance);
  });

  it("sets joined=true after successful join", async () => {
    mockJoin.mockImplementation(() => {
      mockRoomInstance.joined = true;
      return Promise.resolve({ status: "ok" });
    });

    const { result } = renderHook(() => useRoom("room-1"));

    await waitFor(() => {
      expect(result.current.joined).toBe(true);
    });

    expect(result.current.error).toBeNull();
  });

  it("sets error on join failure", async () => {
    const joinError = { reason: "unauthorized" };
    mockJoin.mockRejectedValue(joinError);

    const { result } = renderHook(() => useRoom("room-1"));

    await waitFor(() => {
      expect(result.current.error).toBeTruthy();
    });

    expect(result.current.joined).toBe(false);
  });

  it("leaves room on unmount", async () => {
    mockJoin.mockImplementation(() => {
      mockRoomInstance.joined = true;
      return Promise.resolve({ status: "ok" });
    });

    const { result, unmount } = renderHook(() => useRoom("room-1"));

    await waitFor(() => {
      expect(result.current.joined).toBe(true);
    });

    unmount();

    expect(mockLeave).toHaveBeenCalled();
  });

  it("re-joins when roomId changes", async () => {
    mockJoin.mockImplementation(() => {
      mockRoomInstance.joined = true;
      return Promise.resolve({ status: "ok" });
    });

    const { result, rerender } = renderHook(
      ({ roomId }: { roomId: string }) => useRoom(roomId),
      { initialProps: { roomId: "room-1" } }
    );

    await waitFor(() => {
      expect(result.current.joined).toBe(true);
    });

    // Reset to track new calls
    mockLeave.mockClear();
    mockJoin.mockClear();
    mockRoomInstance.joined = false;
    mockJoinRoom.mockReturnValue({
      channel: mockChannel,
      roomId: "room-2",
    });

    rerender({ roomId: "room-2" });

    // Should leave the old room
    expect(mockLeave).toHaveBeenCalled();

    // Should join the new room
    await waitFor(() => {
      expect(mockClient.joinRoom).toHaveBeenCalledWith("room-2", undefined);
    });
  });

  it("passes join options to joinRoom", async () => {
    mockJoin.mockResolvedValue({ status: "ok" });
    const joinOptions = { params: { role: "viewer" } };

    renderHook(() => useRoom("room-1", joinOptions));

    expect(mockClient.joinRoom).toHaveBeenCalledWith("room-1", joinOptions);
  });

  it("does not join if client is null", () => {
    (useSyncForge as Mock).mockReturnValue({
      client: null,
      connectionState: "disconnected",
    });

    const { result } = renderHook(() => useRoom("room-1"));

    expect(Room).not.toHaveBeenCalled();
    expect(result.current.room).toBeNull();
    expect(result.current.joined).toBe(false);
  });
});

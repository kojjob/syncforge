import { describe, it, expect, vi, beforeEach, type Mock } from "vitest";
import { renderHook, act, waitFor } from "@testing-library/react";
import type { Notification } from "@syncforge/core";

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

const mockNotiJoin = vi.fn();
const mockNotiLeave = vi.fn();
const mockNotiList = vi.fn();
const mockMarkRead = vi.fn();
const mockMarkAllRead = vi.fn();
const mockNotiOn = vi.fn(() => vi.fn()); // returns unsubscribe

let notiUnreadCount = 0;
let newNotificationCallback:
  | ((notification: Notification) => void)
  | null = null;
let unreadCountCallback:
  | ((data: { count: number }) => void)
  | null = null;

const mockNotiManagerInstance = {
  get unreadCount() {
    return notiUnreadCount;
  },
  joined: false,
  join: mockNotiJoin,
  leave: mockNotiLeave,
  list: mockNotiList,
  markRead: mockMarkRead,
  markAllRead: mockMarkAllRead,
  on: mockNotiOn,
  off: vi.fn(),
  removeAllListeners: vi.fn(),
  emit: vi.fn(),
};

const mockChannel = {
  join: vi.fn(),
  leave: vi.fn(),
  push: vi.fn(),
  on: vi.fn(),
};

const mockClient = {
  state: "connected" as const,
  socket: {},
  joinRoom: vi.fn(),
  joinNotifications: vi.fn(() => ({
    channel: mockChannel,
    userId: "user-1",
  })),
  connect: vi.fn(),
  disconnect: vi.fn(),
  on: vi.fn(() => vi.fn()),
  off: vi.fn(),
  removeAllListeners: vi.fn(),
  emit: vi.fn(),
};

vi.mock("@syncforge/core", () => ({
  SyncForgeClient: vi.fn(() => mockClient),
  Room: vi.fn(),
  PresenceManager: vi.fn(),
  CursorManager: vi.fn(),
  CommentManager: vi.fn(),
  NotificationManager: vi.fn(() => mockNotiManagerInstance),
}));

vi.mock("../../src/provider.js", () => ({
  useSyncForge: vi.fn(() => ({
    client: mockClient,
    connectionState: "connected",
  })),
  SyncForgeProvider: vi.fn(),
}));

import { useNotifications } from "../../src/hooks/useNotifications.js";
import { NotificationManager } from "@syncforge/core";
import { useSyncForge } from "../../src/provider.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeNotification(
  overrides: Partial<Notification> = {}
): Notification {
  return {
    id: "notif-1",
    type: "comment_reply",
    payload: { comment_id: "c-1" },
    read_at: null,
    actor_id: "user-2",
    room_id: "room-1",
    inserted_at: "2026-01-01T00:00:00Z",
    ...overrides,
  };
}

function resetMocks() {
  vi.clearAllMocks();
  notiUnreadCount = 0;
  newNotificationCallback = null;
  unreadCountCallback = null;
  mockNotiManagerInstance.joined = false;

  mockNotiJoin.mockImplementation(() => {
    mockNotiManagerInstance.joined = true;
    notiUnreadCount = 3;
    return Promise.resolve({ unread_count: 3 });
  });

  mockNotiList.mockResolvedValue({
    notifications: [],
    total_unread: 0,
  });

  mockMarkRead.mockResolvedValue(
    makeNotification({ read_at: "2026-01-02T00:00:00Z" })
  );

  mockMarkAllRead.mockImplementation(() => {
    notiUnreadCount = 0;
    return Promise.resolve({ count: 3 });
  });

  // Capture event callbacks
  mockNotiOn.mockImplementation((event: string, cb: unknown) => {
    if (event === "notification:new") {
      newNotificationCallback = cb as (notification: Notification) => void;
    }
    if (event === "notification:unread_count") {
      unreadCountCallback = cb as (data: { count: number }) => void;
    }
    return vi.fn(); // unsubscribe
  });

  (NotificationManager as unknown as Mock).mockImplementation(
    () => mockNotiManagerInstance
  );
  (useSyncForge as Mock).mockReturnValue({
    client: mockClient,
    connectionState: "connected",
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("useNotifications", () => {
  beforeEach(() => {
    resetMocks();
  });

  it("returns empty state when client is null", () => {
    (useSyncForge as Mock).mockReturnValue({
      client: null,
      connectionState: "disconnected",
    });

    const { result } = renderHook(() => useNotifications("user-1"));

    expect(result.current.notifications).toEqual([]);
    expect(result.current.unreadCount).toBe(0);
    expect(NotificationManager).not.toHaveBeenCalled();
  });

  it("joins notification channel and fetches list", async () => {
    const notifications = [
      makeNotification({ id: "n1" }),
      makeNotification({ id: "n2" }),
    ];
    mockNotiList.mockResolvedValue({
      notifications,
      total_unread: 2,
    });

    const { result } = renderHook(() => useNotifications("user-1"));

    expect(mockClient.joinNotifications).toHaveBeenCalledWith("user-1");
    expect(NotificationManager).toHaveBeenCalledWith(mockChannel);

    await waitFor(() => {
      expect(mockNotiJoin).toHaveBeenCalled();
    });

    await waitFor(() => {
      expect(mockNotiList).toHaveBeenCalled();
    });

    await waitFor(() => {
      expect(result.current.notifications).toEqual(notifications);
    });
  });

  it("markRead delegates to NotificationManager.markRead", async () => {
    const { result } = renderHook(() => useNotifications("user-1"));

    await waitFor(() => {
      expect(mockNotiJoin).toHaveBeenCalled();
    });

    await act(async () => {
      await result.current.markRead("notif-1");
    });

    expect(mockMarkRead).toHaveBeenCalledWith("notif-1");
  });

  it("markAllRead delegates to NotificationManager.markAllRead", async () => {
    const { result } = renderHook(() => useNotifications("user-1"));

    await waitFor(() => {
      expect(mockNotiJoin).toHaveBeenCalled();
    });

    await act(async () => {
      await result.current.markAllRead();
    });

    expect(mockMarkAllRead).toHaveBeenCalled();
  });

  it("updates on notification:new events", async () => {
    const existingNotification = makeNotification({ id: "n1" });
    mockNotiList.mockResolvedValue({
      notifications: [existingNotification],
      total_unread: 1,
    });

    const { result } = renderHook(() => useNotifications("user-1"));

    await waitFor(() => {
      expect(result.current.notifications).toHaveLength(1);
    });

    // Verify the listener was registered
    expect(mockNotiOn).toHaveBeenCalledWith(
      "notification:new",
      expect.any(Function)
    );

    // Simulate a new notification arriving
    const newNotification = makeNotification({
      id: "n-realtime",
      type: "room_invite",
    });

    if (newNotificationCallback) {
      act(() => {
        newNotificationCallback!(newNotification);
      });
    }

    await waitFor(() => {
      expect(result.current.notifications).toContainEqual(newNotification);
    });
  });

  it("updates unreadCount on notification:unread_count event", async () => {
    const { result } = renderHook(() => useNotifications("user-1"));

    await waitFor(() => {
      expect(mockNotiJoin).toHaveBeenCalled();
    });

    expect(mockNotiOn).toHaveBeenCalledWith(
      "notification:unread_count",
      expect.any(Function)
    );

    // Simulate unread count update from server
    if (unreadCountCallback) {
      notiUnreadCount = 7;
      act(() => {
        unreadCountCallback!({ count: 7 });
      });
    }

    await waitFor(() => {
      expect(result.current.unreadCount).toBe(7);
    });
  });

  it("leaves channel on unmount", async () => {
    const { unmount } = renderHook(() => useNotifications("user-1"));

    await waitFor(() => {
      expect(mockNotiJoin).toHaveBeenCalled();
    });

    unmount();

    expect(mockNotiLeave).toHaveBeenCalled();
  });

  it("does not join if client is not connected", () => {
    (useSyncForge as Mock).mockReturnValue({
      client: null,
      connectionState: "connecting",
    });

    renderHook(() => useNotifications("user-1"));

    expect(NotificationManager).not.toHaveBeenCalled();
    expect(mockNotiJoin).not.toHaveBeenCalled();
  });

  it("re-joins when userId changes", async () => {
    const { rerender } = renderHook(
      ({ userId }: { userId: string }) => useNotifications(userId),
      { initialProps: { userId: "user-1" } }
    );

    await waitFor(() => {
      expect(mockNotiJoin).toHaveBeenCalled();
    });

    mockNotiJoin.mockClear();
    mockNotiLeave.mockClear();
    mockClient.joinNotifications.mockReturnValue({
      channel: mockChannel,
      userId: "user-2",
    });

    rerender({ userId: "user-2" });

    // Should leave old and join new
    expect(mockNotiLeave).toHaveBeenCalled();

    await waitFor(() => {
      expect(mockClient.joinNotifications).toHaveBeenCalledWith("user-2");
    });
  });

  it("returns isLoading during initial fetch", async () => {
    // Make the list call hang
    let resolveList: ((value: any) => void) | undefined;
    mockNotiList.mockReturnValue(
      new Promise((resolve) => {
        resolveList = resolve;
      })
    );

    const { result } = renderHook(() => useNotifications("user-1"));

    await waitFor(() => {
      expect(result.current.isLoading).toBe(true);
    });

    // Resolve the list call
    act(() => {
      resolveList!({ notifications: [], total_unread: 0 });
    });

    await waitFor(() => {
      expect(result.current.isLoading).toBe(false);
    });
  });

  it("sets error when join fails", async () => {
    mockNotiJoin.mockRejectedValue(new Error("Channel join failed"));

    const { result } = renderHook(() => useNotifications("user-1"));

    await waitFor(() => {
      expect(result.current.error).toBeTruthy();
    });
  });
});

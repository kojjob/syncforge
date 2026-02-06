import { describe, it, expect, vi, beforeEach } from "vitest";
import { MockChannel, MockPush } from "./helpers/mock-socket.js";
import { NotificationManager } from "../src/notifications.js";
import type { Channel } from "phoenix";
import type { Notification } from "../src/types.js";

/**
 * Helper to create a mock notification matching the Notification interface.
 */
function makeNotification(overrides: Partial<Notification> = {}): Notification {
  return {
    id: "notif-1",
    type: "comment_mention",
    payload: { comment_id: "c-1", room_id: "r-1" },
    read_at: null,
    actor_id: "user-2",
    room_id: "r-1",
    inserted_at: "2026-01-15T10:00:00Z",
    ...overrides,
  };
}

describe("NotificationManager", () => {
  let channel: MockChannel;
  let manager: NotificationManager;

  beforeEach(() => {
    channel = new MockChannel("notification:user-1");
    manager = new NotificationManager(channel as unknown as Channel);
  });

  // --------------------------------------------------------------------------
  // Initial state
  // --------------------------------------------------------------------------
  describe("initial state", () => {
    it("has unreadCount of 0", () => {
      expect(manager.unreadCount).toBe(0);
    });

    it("has joined as false", () => {
      expect(manager.joined).toBe(false);
    });
  });

  // --------------------------------------------------------------------------
  // join()
  // --------------------------------------------------------------------------
  describe("join()", () => {
    it("resolves with unread_count and sets joined to true", async () => {
      const promise = manager.join();
      channel.simulateJoinOk({ unread_count: 7 });

      const result = await promise;

      expect(result).toEqual({ unread_count: 7 });
      expect(manager.joined).toBe(true);
      expect(manager.unreadCount).toBe(7);
    });

    it("rejects on error response", async () => {
      const promise = manager.join();
      channel.simulateJoinError({ reason: "unauthorized" });

      await expect(promise).rejects.toEqual({ reason: "unauthorized" });
      expect(manager.joined).toBe(false);
    });

    it("rejects on timeout", async () => {
      // Access the internal join push to trigger timeout
      const joinPush = channel.join();
      // We need to reconstruct: the manager already called join() in its own
      // join() method. Let's use a fresh setup where we can control the push.
      const freshChannel = new MockChannel("notification:user-2");
      const freshManager = new NotificationManager(
        freshChannel as unknown as Channel
      );

      const promise = freshManager.join();

      // The MockChannel.join() returns its _joinPush. We need to trigger
      // timeout on the push that was returned to the NotificationManager.
      // Since MockChannel stores _joinPush and returns it from join(),
      // we can access it via simulateJoinOk/Error — but there is no
      // simulateJoinTimeout. We need to trigger it via the _joinPush directly.
      // The _joinPush is private, but the join() method returns it:
      // We already called freshManager.join() which called freshChannel.join()
      // internally. The returned MockPush from join() is the _joinPush.
      // Let's trigger timeout by accessing the push.

      // Alternative approach: spy on channel.join to capture the push
      const channel2 = new MockChannel("notification:user-3");
      const joinPush2 = new MockPush();
      channel2.join = vi.fn().mockReturnValue(joinPush2);

      const manager2 = new NotificationManager(
        channel2 as unknown as Channel
      );

      const promise2 = manager2.join();
      joinPush2.triggerTimeout();

      await expect(promise2).rejects.toThrow(
        "Notification channel join timed out"
      );
      expect(manager2.joined).toBe(false);
    });
  });

  // --------------------------------------------------------------------------
  // leave()
  // --------------------------------------------------------------------------
  describe("leave()", () => {
    it("resets joined to false", async () => {
      const promise = manager.join();
      channel.simulateJoinOk({ unread_count: 3 });
      await promise;

      manager.leave();

      expect(manager.joined).toBe(false);
    });

    it("resets unreadCount to 0", async () => {
      const promise = manager.join();
      channel.simulateJoinOk({ unread_count: 3 });
      await promise;

      manager.leave();

      expect(manager.unreadCount).toBe(0);
    });

    it("removes all event listeners", async () => {
      const listener = vi.fn();
      manager.on("notification:new", listener);

      manager.leave();

      // After leave, listeners should be cleared. We can verify by checking
      // that listenerCount is 0.
      expect(manager.listenerCount("notification:new")).toBe(0);
      expect(manager.listenerCount("notification:unread_count")).toBe(0);
    });

    it("calls channel.leave()", () => {
      const leaveSpy = vi.spyOn(channel, "leave");

      manager.leave();

      expect(leaveSpy).toHaveBeenCalledOnce();
    });
  });

  // --------------------------------------------------------------------------
  // list()
  // --------------------------------------------------------------------------
  describe("list()", () => {
    it("pushes notification:list with default options (limit 20, offset 0)", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const promise = manager.list();
      mockPush.triggerOk({ notifications: [], total_unread: 0 });
      await promise;

      expect(channel.push).toHaveBeenCalledWith("notification:list", {
        limit: 20,
        offset: 0,
      });
    });

    it("pushes notification:list with custom options", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const promise = manager.list({ limit: 50, offset: 10 });
      mockPush.triggerOk({ notifications: [], total_unread: 0 });
      await promise;

      expect(channel.push).toHaveBeenCalledWith("notification:list", {
        limit: 50,
        offset: 10,
      });
    });

    it("resolves with notifications and total_unread", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const notif1 = makeNotification({ id: "n-1" });
      const notif2 = makeNotification({ id: "n-2", type: "comment_reply" });

      const promise = manager.list();
      mockPush.triggerOk({
        notifications: [notif1, notif2],
        total_unread: 5,
      });

      const result = await promise;

      expect(result.notifications).toHaveLength(2);
      expect(result.notifications[0].id).toBe("n-1");
      expect(result.notifications[1].id).toBe("n-2");
      expect(result.total_unread).toBe(5);
    });

    it("updates unreadCount from response", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const promise = manager.list();
      mockPush.triggerOk({ notifications: [], total_unread: 12 });
      await promise;

      expect(manager.unreadCount).toBe(12);
    });

    it("rejects on error response", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const promise = manager.list();
      mockPush.triggerError({ reason: "not_joined" });

      await expect(promise).rejects.toEqual({ reason: "not_joined" });
    });
  });

  // --------------------------------------------------------------------------
  // markRead()
  // --------------------------------------------------------------------------
  describe("markRead()", () => {
    it("pushes notification:mark_read with the correct id", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const notif = makeNotification({
        id: "notif-42",
        read_at: "2026-01-15T12:00:00Z",
      });

      const promise = manager.markRead("notif-42");
      mockPush.triggerOk({ notification: notif });
      await promise;

      expect(channel.push).toHaveBeenCalledWith("notification:mark_read", {
        id: "notif-42",
      });
    });

    it("resolves with the notification object", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const notif = makeNotification({
        id: "notif-42",
        read_at: "2026-01-15T12:00:00Z",
      });

      const promise = manager.markRead("notif-42");
      mockPush.triggerOk({ notification: notif });

      const result = await promise;

      expect(result.id).toBe("notif-42");
      expect(result.read_at).toBe("2026-01-15T12:00:00Z");
    });

    it("rejects on error response", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const promise = manager.markRead("bad-id");
      mockPush.triggerError({ reason: "not_found" });

      await expect(promise).rejects.toEqual({ reason: "not_found" });
    });
  });

  // --------------------------------------------------------------------------
  // markAllRead()
  // --------------------------------------------------------------------------
  describe("markAllRead()", () => {
    it("pushes notification:mark_all_read", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const promise = manager.markAllRead();
      mockPush.triggerOk({ count: 8 });
      await promise;

      expect(channel.push).toHaveBeenCalledWith(
        "notification:mark_all_read",
        {}
      );
    });

    it("resolves with the count", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const promise = manager.markAllRead();
      mockPush.triggerOk({ count: 8 });

      const result = await promise;

      expect(result).toEqual({ count: 8 });
    });

    it("resets unreadCount to 0", async () => {
      // First set a non-zero unread count via join
      const joinPromise = manager.join();
      channel.simulateJoinOk({ unread_count: 15 });
      await joinPromise;
      expect(manager.unreadCount).toBe(15);

      // Now mark all read
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const promise = manager.markAllRead();
      mockPush.triggerOk({ count: 15 });
      await promise;

      expect(manager.unreadCount).toBe(0);
    });

    it("rejects on error response", async () => {
      const mockPush = new MockPush();
      channel.push = vi.fn().mockReturnValue(mockPush);

      const promise = manager.markAllRead();
      mockPush.triggerError({ reason: "server_error" });

      await expect(promise).rejects.toEqual({ reason: "server_error" });
    });
  });

  // --------------------------------------------------------------------------
  // Server-pushed events (_setupListeners)
  // --------------------------------------------------------------------------
  describe("notification:new event", () => {
    it("increments unreadCount", () => {
      expect(manager.unreadCount).toBe(0);

      const notif = makeNotification({ id: "n-new-1" });
      channel.simulateEvent("notification:new", notif);

      expect(manager.unreadCount).toBe(1);
    });

    it("increments unreadCount cumulatively", () => {
      channel.simulateEvent(
        "notification:new",
        makeNotification({ id: "n-1" })
      );
      channel.simulateEvent(
        "notification:new",
        makeNotification({ id: "n-2" })
      );
      channel.simulateEvent(
        "notification:new",
        makeNotification({ id: "n-3" })
      );

      expect(manager.unreadCount).toBe(3);
    });

    it("emits notification:new event with the notification payload", () => {
      const listener = vi.fn();
      manager.on("notification:new", listener);

      const notif = makeNotification({ id: "n-emitted" });
      channel.simulateEvent("notification:new", notif);

      expect(listener).toHaveBeenCalledOnce();
      expect(listener).toHaveBeenCalledWith(notif);
    });
  });

  describe("notification:unread_count event", () => {
    it("updates unreadCount to the received value", () => {
      channel.simulateEvent("notification:unread_count", { count: 42 });

      expect(manager.unreadCount).toBe(42);
    });

    it("can set unreadCount to 0", async () => {
      // Start with some unread
      const joinPromise = manager.join();
      channel.simulateJoinOk({ unread_count: 10 });
      await joinPromise;
      expect(manager.unreadCount).toBe(10);

      channel.simulateEvent("notification:unread_count", { count: 0 });

      expect(manager.unreadCount).toBe(0);
    });

    it("emits notification:unread_count event with the payload", () => {
      const listener = vi.fn();
      manager.on("notification:unread_count", listener);

      channel.simulateEvent("notification:unread_count", { count: 7 });

      expect(listener).toHaveBeenCalledOnce();
      expect(listener).toHaveBeenCalledWith({ count: 7 });
    });
  });
});

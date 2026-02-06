/**
 * useNotifications — React hook for real-time user notifications.
 *
 * Creates a NotificationManager from the connected SyncForgeClient,
 * joins the notification channel, fetches the initial list, and
 * returns reactive state that updates on new notification events.
 */

import { useCallback, useEffect, useRef, useState } from "react";
import {
  NotificationManager,
  type Notification,
} from "@syncforge/core";
import { useSyncForge } from "../provider.js";

export interface UseNotificationsReturn {
  notifications: Notification[];
  unreadCount: number;
  markRead: (id: string) => Promise<Notification>;
  markAllRead: () => Promise<{ count: number }>;
  refresh: () => Promise<void>;
  isLoading: boolean;
  error: string | null;
}

export function useNotifications(userId: string): UseNotificationsReturn {
  const { client, connectionState } = useSyncForge();
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const managerRef = useRef<NotificationManager | null>(null);

  // Fetch notification list from the manager
  const fetchList = useCallback(async (manager: NotificationManager) => {
    try {
      const { notifications: list, total_unread } = await manager.list();
      setNotifications([...list]);
      setUnreadCount(total_unread);
    } catch {
      // Silently handle list fetch errors — channel may not be ready
    }
  }, []);

  useEffect(() => {
    if (!client || connectionState !== "connected") {
      return;
    }

    setIsLoading(true);
    setError(null);
    let cancelled = false;

    try {
      const { channel } = client.joinNotifications(userId);
      const manager = new NotificationManager(channel);
      managerRef.current = manager;

      // Listen for real-time new notifications
      const unsubNew = manager.on("notification:new", (notification) => {
        if (!cancelled) {
          setNotifications((prev) => [notification, ...prev]);
          setUnreadCount(manager.unreadCount);
        }
      });

      // Listen for unread count changes
      const unsubCount = manager.on(
        "notification:unread_count",
        ({ count }) => {
          if (!cancelled) {
            setUnreadCount(count);
          }
        }
      );

      // Join the notification channel, then fetch the initial list
      manager
        .join()
        .then(({ unread_count }) => {
          if (!cancelled) {
            setUnreadCount(unread_count);
            return fetchList(manager);
          }
        })
        .then(() => {
          if (!cancelled) {
            setIsLoading(false);
          }
        })
        .catch((err: unknown) => {
          if (!cancelled) {
            setIsLoading(false);
            const message =
              err instanceof Error
                ? err.message
                : "Failed to join notification channel";
            setError(message);
          }
        });

      return () => {
        cancelled = true;
        unsubNew();
        unsubCount();
        manager.leave();
        managerRef.current = null;
      };
    } catch {
      // client.joinNotifications can throw if not connected
      if (!cancelled) {
        setIsLoading(false);
      }
      return;
    }
  }, [client, connectionState, userId, fetchList]);

  const markRead = useCallback(
    async (id: string): Promise<Notification> => {
      if (!managerRef.current) {
        throw new Error(
          "NotificationManager not available — channel not joined"
        );
      }
      const notification = await managerRef.current.markRead(id);
      // Update local state: mark the notification as read
      setNotifications((prev) =>
        prev.map((n) => (n.id === id ? notification : n))
      );
      setUnreadCount(managerRef.current.unreadCount);
      return notification;
    },
    []
  );

  const markAllRead = useCallback(async (): Promise<{ count: number }> => {
    if (!managerRef.current) {
      throw new Error(
        "NotificationManager not available — channel not joined"
      );
    }
    const result = await managerRef.current.markAllRead();
    // Update local state: mark all as read
    setNotifications((prev) =>
      prev.map((n) => ({
        ...n,
        read_at: n.read_at ?? new Date().toISOString(),
      }))
    );
    setUnreadCount(0);
    return result;
  }, []);

  const refresh = useCallback(async (): Promise<void> => {
    if (!managerRef.current) {
      throw new Error(
        "NotificationManager not available — channel not joined"
      );
    }
    await fetchList(managerRef.current);
  }, [fetchList]);

  return {
    notifications,
    unreadCount,
    markRead,
    markAllRead,
    refresh,
    isLoading,
    error,
  };
}

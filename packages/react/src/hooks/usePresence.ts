/**
 * usePresence — React hook for tracking user presence in a room.
 *
 * Creates a PresenceManager, attaches it to the room's channel,
 * and returns a reactive list of present users.
 */

import { useEffect, useRef, useState } from "react";
import { PresenceManager, type Room, type PresenceUser } from "@syncforge/core";

export interface UsePresenceReturn {
  users: PresenceUser[];
  isLoading: boolean;
}

export function usePresence(room: Room | null): UsePresenceReturn {
  const [users, setUsers] = useState<PresenceUser[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const managerRef = useRef<PresenceManager | null>(null);

  useEffect(() => {
    if (!room || !room.joined) {
      setUsers([]);
      setIsLoading(true);
      return;
    }

    const manager = new PresenceManager();
    managerRef.current = manager;
    let cancelled = false;

    const unsubSync = manager.on("presence:sync", ({ users: syncedUsers }) => {
      if (!cancelled) {
        // Create new array reference to trigger React re-render
        setUsers([...syncedUsers]);
        setIsLoading(false);
      }
    });

    manager
      .attach(room.channel)
      .then(() => {
        // After attach, read initial users if available
        if (!cancelled && manager.users.length > 0) {
          setUsers([...manager.users]);
          setIsLoading(false);
        }
      })
      .catch(() => {
        // Presence attach failed — remain in loading state
        if (!cancelled) {
          setIsLoading(false);
        }
      });

    return () => {
      cancelled = true;
      unsubSync();
      manager.detach();
      managerRef.current = null;
    };
  }, [room, room?.joined]);

  return { users, isLoading };
}

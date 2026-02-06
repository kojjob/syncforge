/**
 * useCursors — React hook for real-time cursor tracking.
 *
 * Creates a CursorManager when a room is available, returns a reactive
 * Map of remote cursors, and provides a sendUpdate function for
 * broadcasting the local user's cursor position.
 */

import { useCallback, useEffect, useRef, useState } from "react";
import { CursorManager, type Room, type CursorPosition } from "@syncforge/core";

export interface UseCursorsReturn {
  cursors: Map<string, CursorPosition>;
  sendUpdate: (x: number, y: number, elementId?: string) => void;
}

export function useCursors(room: Room | null): UseCursorsReturn {
  const [cursors, setCursors] = useState<Map<string, CursorPosition>>(
    () => new Map()
  );
  const managerRef = useRef<CursorManager | null>(null);

  useEffect(() => {
    if (!room || !room.joined) {
      setCursors(new Map());
      return;
    }

    const manager = new CursorManager(room.channel);
    managerRef.current = manager;
    let cancelled = false;

    const unsubUpdate = manager.on("cursor:update", () => {
      if (!cancelled) {
        // Create a new Map reference so React detects the state change
        setCursors(new Map(manager.cursors));
      }
    });

    return () => {
      cancelled = true;
      unsubUpdate();
      manager.destroy();
      managerRef.current = null;
    };
  }, [room, room?.joined]);

  const sendUpdate = useCallback(
    (x: number, y: number, elementId?: string) => {
      managerRef.current?.sendUpdate(x, y, elementId);
    },
    []
  );

  return { cursors, sendUpdate };
}

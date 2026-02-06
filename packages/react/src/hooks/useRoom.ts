/**
 * useRoom — React hook for joining and managing a SyncForge room.
 *
 * Creates a Room from the connected SyncForgeClient, joins on mount,
 * and cleans up (leaves) on unmount or when roomId changes.
 */

import { useCallback, useEffect, useRef, useState } from "react";
import { Room } from "@syncforge/core";
import { useSyncForge } from "../provider.js";

export interface UseRoomReturn {
  room: Room | null;
  joined: boolean;
  error: string | null;
  leave: () => void;
}

export function useRoom(
  roomId: string,
  options?: Record<string, unknown>,
): UseRoomReturn {
  const { client, connectionState } = useSyncForge();
  const [room, setRoom] = useState<Room | null>(null);
  const [joined, setJoined] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const roomRef = useRef<Room | null>(null);

  useEffect(() => {
    // Wait until client is connected before joining
    if (!client || connectionState !== "connected") {
      return;
    }

    setError(null);
    setJoined(false);

    let cancelled = false;

    try {
      const { channel, roomId: id } = client.joinRoom(roomId, options);
      const newRoom = new Room(channel, id);
      roomRef.current = newRoom;

      if (!cancelled) {
        setRoom(newRoom);
      }

      newRoom
        .join()
        .then(() => {
          if (!cancelled) {
            setJoined(true);
          }
        })
        .catch((err: unknown) => {
          if (!cancelled) {
            const message =
              err instanceof Error
                ? err.message
                : typeof err === "object" && err !== null && "reason" in err
                  ? String((err as Record<string, unknown>).reason)
                  : "Failed to join room";
            setError(message);
          }
        });

      // Listen for errors after join
      const unsubError = newRoom.on("error", ({ reason }) => {
        if (!cancelled) {
          setError(reason);
        }
      });

      return () => {
        cancelled = true;
        unsubError();
        newRoom.leave();
        roomRef.current = null;
        setRoom(null);
        setJoined(false);
      };
    } catch (err: unknown) {
      // client.joinRoom can throw if not connected
      const message =
        err instanceof Error ? err.message : "Failed to create room";
      if (!cancelled) {
        setError(message);
      }
      return;
    }
  }, [client, connectionState, roomId, options]);

  const leave = useCallback(() => {
    if (roomRef.current) {
      roomRef.current.leave();
      roomRef.current = null;
      setRoom(null);
      setJoined(false);
    }
  }, []);

  return { room, joined, error, leave };
}

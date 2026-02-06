/**
 * useComments — React hook for real-time threaded comments.
 *
 * Creates a CommentManager when a room is available, returns a reactive
 * comment list that updates from both room_state hydration and real-time
 * events, and provides CRUD methods.
 */

import { useCallback, useEffect, useRef, useState } from "react";
import {
  CommentManager,
  type Room,
  type Comment,
  type CreateCommentParams,
  type UpdateCommentParams,
} from "@syncforge/core";

export interface UseCommentsReturn {
  comments: Comment[];
  create: (params: CreateCommentParams) => Promise<Comment>;
  update: (params: UpdateCommentParams) => Promise<Comment>;
  remove: (commentId: string) => Promise<void>;
  resolve: (commentId: string) => Promise<Comment>;
}

export function useComments(room: Room | null): UseCommentsReturn {
  const [comments, setComments] = useState<Comment[]>([]);
  const managerRef = useRef<CommentManager | null>(null);

  useEffect(() => {
    if (!room || !room.joined) {
      setComments([]);
      managerRef.current = null;
      return;
    }

    const manager = new CommentManager(room);
    managerRef.current = manager;
    let cancelled = false;

    // Sync initial comments from room state
    setComments([...manager.comments]);

    // Listen for room_state to hydrate comments on join
    const unsubState = room.on("room:state", () => {
      if (!cancelled) {
        setComments([...manager.comments]);
      }
    });

    // Listen for real-time comment events
    const unsubCreated = manager.onCreated(() => {
      if (!cancelled) {
        setComments([...manager.comments]);
      }
    });

    const unsubUpdated = manager.onUpdated(() => {
      if (!cancelled) {
        setComments([...manager.comments]);
      }
    });

    const unsubDeleted = manager.onDeleted(() => {
      if (!cancelled) {
        setComments([...manager.comments]);
      }
    });

    const unsubResolved = manager.onResolved(() => {
      if (!cancelled) {
        setComments([...manager.comments]);
      }
    });

    return () => {
      cancelled = true;
      unsubState();
      unsubCreated();
      unsubUpdated();
      unsubDeleted();
      unsubResolved();
      managerRef.current = null;
    };
  }, [room, room?.joined]);

  const create = useCallback(
    async (params: CreateCommentParams): Promise<Comment> => {
      if (!managerRef.current) {
        throw new Error("CommentManager not available — room not joined");
      }
      return managerRef.current.create(params);
    },
    []
  );

  const update = useCallback(
    async (params: UpdateCommentParams): Promise<Comment> => {
      if (!managerRef.current) {
        throw new Error("CommentManager not available — room not joined");
      }
      return managerRef.current.update(params);
    },
    []
  );

  const remove = useCallback(async (commentId: string): Promise<void> => {
    if (!managerRef.current) {
      throw new Error("CommentManager not available — room not joined");
    }
    return managerRef.current.delete(commentId);
  }, []);

  const resolve = useCallback(
    async (commentId: string): Promise<Comment> => {
      if (!managerRef.current) {
        throw new Error("CommentManager not available — room not joined");
      }
      return managerRef.current.resolve(commentId);
    },
    []
  );

  return { comments, create, update, remove, resolve };
}

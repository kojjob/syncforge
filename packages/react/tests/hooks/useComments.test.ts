import { describe, it, expect, vi, beforeEach, type Mock } from "vitest";
import { renderHook, act, waitFor } from "@testing-library/react";
import type { Comment } from "@syncforge/core";

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

const mockCreate = vi.fn();
const mockUpdate = vi.fn();
const mockDelete = vi.fn();
const mockResolve = vi.fn();
const mockUnresolve = vi.fn();
const mockOnCreated = vi.fn(() => vi.fn()); // returns unsubscribe
const mockOnUpdated = vi.fn(() => vi.fn());
const mockOnDeleted = vi.fn(() => vi.fn());
const mockOnResolved = vi.fn(() => vi.fn());

let commentsList: Comment[] = [];

// Store callbacks so tests can trigger events
let onCreatedCallback: ((comment: Comment) => void) | null = null;
let onUpdatedCallback: ((comment: Comment) => void) | null = null;
let onDeletedCallback: ((commentId: string) => void) | null = null;
let onResolvedCallback: ((comment: Comment) => void) | null = null;

const mockCommentManagerInstance = {
  get comments() {
    return commentsList;
  },
  create: mockCreate,
  update: mockUpdate,
  delete: mockDelete,
  resolve: mockResolve,
  unresolve: mockUnresolve,
  onCreated: mockOnCreated,
  onUpdated: mockOnUpdated,
  onDeleted: mockOnDeleted,
  onResolved: mockOnResolved,
};

vi.mock("@syncforge/core", () => ({
  SyncForgeClient: vi.fn(),
  Room: vi.fn(),
  PresenceManager: vi.fn(),
  CursorManager: vi.fn(),
  CommentManager: vi.fn(() => mockCommentManagerInstance),
  NotificationManager: vi.fn(),
}));

import { useComments } from "../../src/hooks/useComments.js";
import { CommentManager } from "@syncforge/core";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeComment(overrides: Partial<Comment> = {}): Comment {
  return {
    id: "comment-1",
    body: "Hello world",
    user_id: "user-1",
    room_id: "room-1",
    inserted_at: "2026-01-01T00:00:00Z",
    updated_at: "2026-01-01T00:00:00Z",
    ...overrides,
  };
}

function createMockRoom(comments: Comment[] = []) {
  return {
    roomId: "room-1",
    channel: { on: vi.fn(), push: vi.fn() },
    joined: true,
    comments,
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
  commentsList = [];
  onCreatedCallback = null;
  onUpdatedCallback = null;
  onDeletedCallback = null;
  onResolvedCallback = null;

  // Capture callbacks when onCreated/onUpdated/onDeleted/onResolved are called
  mockOnCreated.mockImplementation((cb: (comment: Comment) => void) => {
    onCreatedCallback = cb;
    return vi.fn(); // unsubscribe
  });
  mockOnUpdated.mockImplementation((cb: (comment: Comment) => void) => {
    onUpdatedCallback = cb;
    return vi.fn();
  });
  mockOnDeleted.mockImplementation((cb: (commentId: string) => void) => {
    onDeletedCallback = cb;
    return vi.fn();
  });
  mockOnResolved.mockImplementation((cb: (comment: Comment) => void) => {
    onResolvedCallback = cb;
    return vi.fn();
  });

  (CommentManager as unknown as Mock).mockImplementation(
    () => mockCommentManagerInstance
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("useComments", () => {
  beforeEach(() => {
    resetMocks();
  });

  it("returns empty comments when room is null", () => {
    const { result } = renderHook(() => useComments(null));

    expect(result.current.comments).toEqual([]);
    expect(CommentManager).not.toHaveBeenCalled();
  });

  it("returns room comments when room is provided", () => {
    const existingComments = [
      makeComment({ id: "c1", body: "First" }),
      makeComment({ id: "c2", body: "Second" }),
    ];
    commentsList = existingComments;
    const mockRoom = createMockRoom(existingComments);

    const { result } = renderHook(() => useComments(mockRoom as any));

    expect(CommentManager).toHaveBeenCalledWith(mockRoom);
    expect(result.current.comments).toEqual(existingComments);
  });

  it("create delegates to CommentManager.create", async () => {
    const mockRoom = createMockRoom();
    const newComment = makeComment({ id: "c-new", body: "New comment" });
    mockCreate.mockResolvedValue(newComment);

    const { result } = renderHook(() => useComments(mockRoom as any));

    let created: Comment | undefined;
    await act(async () => {
      created = await result.current.create({ body: "New comment" });
    });

    expect(mockCreate).toHaveBeenCalledWith({ body: "New comment" });
    expect(created).toEqual(newComment);
  });

  it("update delegates to CommentManager.update", async () => {
    const mockRoom = createMockRoom();
    const updatedComment = makeComment({ id: "c1", body: "Updated" });
    mockUpdate.mockResolvedValue(updatedComment);

    const { result } = renderHook(() => useComments(mockRoom as any));

    let updated: Comment | undefined;
    await act(async () => {
      updated = await result.current.update({ id: "c1", body: "Updated" });
    });

    expect(mockUpdate).toHaveBeenCalledWith({ id: "c1", body: "Updated" });
    expect(updated).toEqual(updatedComment);
  });

  it("remove delegates to CommentManager.delete", async () => {
    const mockRoom = createMockRoom();
    mockDelete.mockResolvedValue(undefined);

    const { result } = renderHook(() => useComments(mockRoom as any));

    await act(async () => {
      await result.current.remove("c1");
    });

    expect(mockDelete).toHaveBeenCalledWith("c1");
  });

  it("resolve delegates to CommentManager.resolve", async () => {
    const mockRoom = createMockRoom();
    const resolvedComment = makeComment({
      id: "c1",
      resolved_at: "2026-01-02T00:00:00Z",
    });
    mockResolve.mockResolvedValue(resolvedComment);

    const { result } = renderHook(() => useComments(mockRoom as any));

    let resolved: Comment | undefined;
    await act(async () => {
      resolved = await result.current.resolve("c1");
    });

    expect(mockResolve).toHaveBeenCalledWith("c1");
    expect(resolved).toEqual(resolvedComment);
  });

  it("updates comments on comment:created event", async () => {
    const mockRoom = createMockRoom();
    const newComment = makeComment({ id: "c-real-time", body: "Real-time" });

    const { result } = renderHook(() => useComments(mockRoom as any));

    // Verify the onCreated callback was registered
    expect(mockOnCreated).toHaveBeenCalledWith(expect.any(Function));

    // Simulate a real-time comment creation
    if (onCreatedCallback) {
      commentsList = [...commentsList, newComment];
      act(() => {
        onCreatedCallback!(newComment);
      });
    }

    await waitFor(() => {
      expect(result.current.comments).toContainEqual(newComment);
    });
  });

  it("updates comments on comment:updated event", async () => {
    const original = makeComment({ id: "c1", body: "Original" });
    commentsList = [original];
    const mockRoom = createMockRoom([original]);

    const { result } = renderHook(() => useComments(mockRoom as any));

    expect(mockOnUpdated).toHaveBeenCalledWith(expect.any(Function));

    const updated = makeComment({ id: "c1", body: "Updated via event" });
    if (onUpdatedCallback) {
      commentsList = [updated];
      act(() => {
        onUpdatedCallback!(updated);
      });
    }

    await waitFor(() => {
      expect(result.current.comments[0]?.body).toBe("Updated via event");
    });
  });

  it("updates comments on comment:deleted event", async () => {
    const comment = makeComment({ id: "c1" });
    commentsList = [comment];
    const mockRoom = createMockRoom([comment]);

    const { result } = renderHook(() => useComments(mockRoom as any));

    expect(mockOnDeleted).toHaveBeenCalledWith(expect.any(Function));

    if (onDeletedCallback) {
      commentsList = [];
      act(() => {
        onDeletedCallback!("c1");
      });
    }

    await waitFor(() => {
      expect(result.current.comments).toEqual([]);
    });
  });

  it("updates comments on comment:resolved event", async () => {
    const comment = makeComment({ id: "c1", resolved_at: null });
    commentsList = [comment];
    const mockRoom = createMockRoom([comment]);

    const { result } = renderHook(() => useComments(mockRoom as any));

    expect(mockOnResolved).toHaveBeenCalledWith(expect.any(Function));

    const resolved = makeComment({
      id: "c1",
      resolved_at: "2026-02-06T00:00:00Z",
    });
    if (onResolvedCallback) {
      commentsList = [resolved];
      act(() => {
        onResolvedCallback!(resolved);
      });
    }

    await waitFor(() => {
      expect(result.current.comments[0]?.resolved_at).toBe(
        "2026-02-06T00:00:00Z"
      );
    });
  });

  it("unsubscribes from events on unmount", () => {
    const mockRoom = createMockRoom();
    const unsubCreated = vi.fn();
    const unsubUpdated = vi.fn();
    const unsubDeleted = vi.fn();
    const unsubResolved = vi.fn();

    mockOnCreated.mockReturnValue(unsubCreated);
    mockOnUpdated.mockReturnValue(unsubUpdated);
    mockOnDeleted.mockReturnValue(unsubDeleted);
    mockOnResolved.mockReturnValue(unsubResolved);

    const { unmount } = renderHook(() => useComments(mockRoom as any));

    unmount();

    expect(unsubCreated).toHaveBeenCalled();
    expect(unsubUpdated).toHaveBeenCalled();
    expect(unsubDeleted).toHaveBeenCalled();
    expect(unsubResolved).toHaveBeenCalled();
  });

  it("recreates CommentManager when room changes", () => {
    const room1 = createMockRoom();
    const room2 = createMockRoom();
    room2.roomId = "room-2";

    const { rerender } = renderHook(
      ({ room }: { room: any }) => useComments(room),
      { initialProps: { room: room1 } }
    );

    expect(CommentManager).toHaveBeenCalledWith(room1);

    const callCountBefore = (CommentManager as unknown as Mock).mock.calls
      .length;

    rerender({ room: room2 });

    expect((CommentManager as unknown as Mock).mock.calls.length).toBeGreaterThan(
      callCountBefore
    );
  });
});

/**
 * CommentPanel -- Slide-out panel with threaded comments.
 *
 * Top-level comments are displayed in chronological order. Replies are
 * indented beneath their parent. Each comment shows body text, a relative
 * timestamp, and action buttons (reply, resolve, delete) depending on
 * ownership and provided callbacks.
 */

import {
  forwardRef,
  useCallback,
  useMemo,
  useState,
} from "react";
import type { Comment } from "@syncforge/core";

export interface CommentPanelProps {
  /** All comments for the current room (flat list). */
  comments: Comment[];
  /** ID of the user viewing the panel (used for ownership checks). */
  currentUserId: string;
  /** Called when the user submits a new comment or reply. */
  onSubmit: (body: string, parentId?: string) => void;
  /** Called when the user deletes a comment they own. */
  onDelete?: (commentId: string) => void;
  /** Called when the user resolves a comment thread. */
  onResolve?: (commentId: string) => void;
  /** Additional CSS class name on the root panel. */
  className?: string;
  /** Inline styles merged onto the root panel. */
  style?: React.CSSProperties;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function relativeTime(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime();
  const seconds = Math.floor(diff / 1000);
  if (seconds < 60) return "just now";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.floor(hours / 24);
  return `${days}d ago`;
}

interface Thread {
  root: Comment;
  replies: Comment[];
}

function buildThreads(comments: Comment[]): Thread[] {
  const rootMap = new Map<string, Thread>();
  const roots: Thread[] = [];

  // First pass: collect all root comments (no parent_id)
  for (const c of comments) {
    if (!c.parent_id) {
      const thread: Thread = { root: c, replies: [] };
      rootMap.set(c.id, thread);
      roots.push(thread);
    }
  }

  // Second pass: attach replies
  for (const c of comments) {
    if (c.parent_id) {
      const thread = rootMap.get(c.parent_id);
      if (thread) {
        thread.replies.push(c);
      }
    }
  }

  // Sort roots and replies chronologically
  roots.sort(
    (a, b) =>
      new Date(a.root.inserted_at).getTime() -
      new Date(b.root.inserted_at).getTime(),
  );
  for (const t of roots) {
    t.replies.sort(
      (a, b) =>
        new Date(a.inserted_at).getTime() - new Date(b.inserted_at).getTime(),
    );
  }

  return roots;
}

// ---------------------------------------------------------------------------
// Styles
// ---------------------------------------------------------------------------

const panelStyle: React.CSSProperties = {
  display: "flex",
  flexDirection: "column",
  height: "100%",
  width: 360,
  backgroundColor: "#fff",
  borderLeft: "1px solid #e5e7eb",
  fontFamily:
    '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
  fontSize: 14,
  color: "#1f2937",
  boxSizing: "border-box",
};

const headerStyle: React.CSSProperties = {
  padding: "16px 16px 12px",
  fontWeight: 600,
  fontSize: 16,
  borderBottom: "1px solid #e5e7eb",
};

const listStyle: React.CSSProperties = {
  flex: 1,
  overflowY: "auto",
  padding: 16,
};

const commentBlockStyle: React.CSSProperties = {
  marginBottom: 16,
};

const commentBubbleStyle: React.CSSProperties = {
  backgroundColor: "#f3f4f6",
  borderRadius: 8,
  padding: "10px 12px",
};

const resolvedBubbleStyle: React.CSSProperties = {
  ...commentBubbleStyle,
  opacity: 0.6,
};

const replyBubbleStyle: React.CSSProperties = {
  ...commentBubbleStyle,
  marginLeft: 24,
  marginTop: 8,
};

const metaStyle: React.CSSProperties = {
  fontSize: 11,
  color: "#6b7280",
  marginBottom: 4,
};

const bodyStyle: React.CSSProperties = {
  lineHeight: 1.45,
  whiteSpace: "pre-wrap",
  wordBreak: "break-word",
};

const actionsStyle: React.CSSProperties = {
  display: "flex",
  gap: 8,
  marginTop: 6,
};

const actionBtnStyle: React.CSSProperties = {
  background: "none",
  border: "none",
  fontSize: 12,
  color: "#6b7280",
  cursor: "pointer",
  padding: 0,
  textDecoration: "underline",
};

const composerStyle: React.CSSProperties = {
  borderTop: "1px solid #e5e7eb",
  padding: 12,
  display: "flex",
  gap: 8,
};

const inputStyle: React.CSSProperties = {
  flex: 1,
  padding: "8px 10px",
  fontSize: 14,
  borderRadius: 6,
  border: "1px solid #d1d5db",
  outline: "none",
  fontFamily: "inherit",
  boxSizing: "border-box",
};

const sendBtnStyle: React.CSSProperties = {
  padding: "8px 14px",
  fontSize: 14,
  fontWeight: 500,
  borderRadius: 6,
  border: "none",
  backgroundColor: "#6366f1",
  color: "#fff",
  cursor: "pointer",
  whiteSpace: "nowrap",
};

const sendBtnDisabledStyle: React.CSSProperties = {
  ...sendBtnStyle,
  opacity: 0.5,
  cursor: "not-allowed",
};

// ---------------------------------------------------------------------------
// Sub-components
// ---------------------------------------------------------------------------

interface CommentBubbleProps {
  comment: Comment;
  isReply?: boolean;
  isOwner: boolean;
  onReply?: () => void;
  onDelete?: () => void;
  onResolve?: () => void;
}

function CommentBubble({
  comment,
  isReply = false,
  isOwner,
  onReply,
  onDelete,
  onResolve,
}: CommentBubbleProps) {
  const isResolved = !!comment.resolved_at;
  const bubbleBase = isReply ? replyBubbleStyle : commentBubbleStyle;
  const bubble = isResolved && !isReply ? resolvedBubbleStyle : bubbleBase;

  return (
    <div style={bubble}>
      <div style={metaStyle}>
        <strong>{comment.user_id}</strong> &middot;{" "}
        <time dateTime={comment.inserted_at}>
          {relativeTime(comment.inserted_at)}
        </time>
        {isResolved && " (resolved)"}
      </div>
      <div style={bodyStyle}>{comment.body}</div>
      <div style={actionsStyle}>
        {onReply && !isResolved && (
          <button
            type="button"
            style={actionBtnStyle}
            onClick={onReply}
            aria-label="Reply to this comment"
          >
            Reply
          </button>
        )}
        {onResolve && isOwner && !isResolved && !isReply && (
          <button
            type="button"
            style={actionBtnStyle}
            onClick={onResolve}
            aria-label="Resolve this comment thread"
          >
            Resolve
          </button>
        )}
        {onDelete && isOwner && (
          <button
            type="button"
            style={{ ...actionBtnStyle, color: "#ef4444" }}
            onClick={onDelete}
            aria-label="Delete this comment"
          >
            Delete
          </button>
        )}
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Inline composer for replies
// ---------------------------------------------------------------------------

interface ReplyComposerProps {
  parentId: string;
  onSubmit: (body: string, parentId: string) => void;
  onCancel: () => void;
}

function ReplyComposer({ parentId, onSubmit, onCancel }: ReplyComposerProps) {
  const [value, setValue] = useState("");

  const handleSubmit = () => {
    const trimmed = value.trim();
    if (!trimmed) return;
    onSubmit(trimmed, parentId);
    setValue("");
    onCancel();
  };

  return (
    <div style={{ ...composerStyle, borderTop: "none", paddingLeft: 24 }}>
      <input
        style={inputStyle}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            handleSubmit();
          }
          if (e.key === "Escape") onCancel();
        }}
        placeholder="Write a reply..."
        aria-label="Reply text"
        // eslint-disable-next-line jsx-a11y/no-autofocus
        autoFocus
      />
      <button
        type="button"
        style={value.trim() ? sendBtnStyle : sendBtnDisabledStyle}
        onClick={handleSubmit}
        disabled={!value.trim()}
        aria-label="Send reply"
      >
        Reply
      </button>
      <button
        type="button"
        style={actionBtnStyle}
        onClick={onCancel}
        aria-label="Cancel reply"
      >
        Cancel
      </button>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Main component
// ---------------------------------------------------------------------------

export const CommentPanel = forwardRef<HTMLDivElement, CommentPanelProps>(
  function CommentPanel(
    { comments, currentUserId, onSubmit, onDelete, onResolve, className, style },
    ref,
  ) {
    const threads = useMemo(() => buildThreads(comments), [comments]);
    const [replyingTo, setReplyingTo] = useState<string | null>(null);
    const [newComment, setNewComment] = useState("");

    const handleSubmitRoot = useCallback(() => {
      const trimmed = newComment.trim();
      if (!trimmed) return;
      onSubmit(trimmed);
      setNewComment("");
    }, [newComment, onSubmit]);

    const handleReplySubmit = useCallback(
      (body: string, parentId: string) => {
        onSubmit(body, parentId);
      },
      [onSubmit],
    );

    return (
      <div
        ref={ref}
        className={className}
        style={{ ...panelStyle, ...style }}
        role="complementary"
        aria-label="Comments"
      >
        {/* Header */}
        <div style={headerStyle}>
          Comments{" "}
          <span style={{ fontWeight: 400, color: "#6b7280" }}>
            ({comments.length})
          </span>
        </div>

        {/* Thread list */}
        <div style={listStyle}>
          {threads.length === 0 && (
            <div style={{ color: "#9ca3af", textAlign: "center", marginTop: 32 }}>
              No comments yet.
            </div>
          )}

          {threads.map((thread) => (
            <div key={thread.root.id} style={commentBlockStyle}>
              <CommentBubble
                comment={thread.root}
                isOwner={thread.root.user_id === currentUserId}
                onReply={() => setReplyingTo(thread.root.id)}
                onDelete={
                  onDelete ? () => onDelete(thread.root.id) : undefined
                }
                onResolve={
                  onResolve ? () => onResolve(thread.root.id) : undefined
                }
              />

              {/* Replies */}
              {thread.replies.map((reply) => (
                <CommentBubble
                  key={reply.id}
                  comment={reply}
                  isReply
                  isOwner={reply.user_id === currentUserId}
                  onDelete={
                    onDelete ? () => onDelete(reply.id) : undefined
                  }
                />
              ))}

              {/* Inline reply composer */}
              {replyingTo === thread.root.id && (
                <ReplyComposer
                  parentId={thread.root.id}
                  onSubmit={handleReplySubmit}
                  onCancel={() => setReplyingTo(null)}
                />
              )}
            </div>
          ))}
        </div>

        {/* Root comment composer */}
        <div style={composerStyle}>
          <input
            style={inputStyle}
            value={newComment}
            onChange={(e) => setNewComment(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault();
                handleSubmitRoot();
              }
            }}
            placeholder="Write a comment..."
            aria-label="New comment text"
          />
          <button
            type="button"
            style={newComment.trim() ? sendBtnStyle : sendBtnDisabledStyle}
            onClick={handleSubmitRoot}
            disabled={!newComment.trim()}
            aria-label="Send comment"
          >
            Send
          </button>
        </div>
      </div>
    );
  },
);

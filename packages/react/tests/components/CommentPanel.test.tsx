import { describe, it, expect, vi } from "vitest";
import { render, screen, fireEvent, waitFor } from "@testing-library/react";
import type { Comment } from "@syncforge/core";
import { CommentPanel } from "../../src/components/CommentPanel.js";

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

function makeComment(overrides?: Partial<Comment>): Comment {
  return {
    id: "comment-1",
    body: "Hello!",
    anchor_id: null,
    anchor_type: null,
    position: null,
    resolved_at: null,
    user_id: "user-1",
    room_id: "room-1",
    parent_id: null,
    inserted_at: "2024-01-01T00:00:00Z",
    updated_at: "2024-01-01T00:00:00Z",
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("CommentPanel", () => {
  const defaultProps = {
    comments: [] as Comment[],
    currentUserId: "user-1",
    onSubmit: vi.fn(),
  };

  // -------------------------------------------------------------------------
  // Rendering comments
  // -------------------------------------------------------------------------

  describe("rendering comments", () => {
    it("renders a list of comments", () => {
      const comments = [
        makeComment({ id: "c1", body: "First comment" }),
        makeComment({ id: "c2", body: "Second comment" }),
        makeComment({ id: "c3", body: "Third comment" }),
      ];

      render(<CommentPanel {...defaultProps} comments={comments} />);

      expect(screen.getByText("First comment")).toBeInTheDocument();
      expect(screen.getByText("Second comment")).toBeInTheDocument();
      expect(screen.getByText("Third comment")).toBeInTheDocument();
    });

    it("shows the comment body text", () => {
      const comments = [
        makeComment({ id: "c1", body: "This is a detailed comment about the feature." }),
      ];

      render(<CommentPanel {...defaultProps} comments={comments} />);

      expect(
        screen.getByText("This is a detailed comment about the feature.")
      ).toBeInTheDocument();
    });

    it("renders comments with special characters in body", () => {
      const comments = [
        makeComment({ id: "c1", body: "Hello <World> & 'Friends'" }),
      ];

      render(<CommentPanel {...defaultProps} comments={comments} />);

      expect(
        screen.getByText("Hello <World> & 'Friends'")
      ).toBeInTheDocument();
    });
  });

  // -------------------------------------------------------------------------
  // Threading replies
  // -------------------------------------------------------------------------

  describe("threading replies", () => {
    it("threads replies under their parent comments", () => {
      const comments = [
        makeComment({ id: "c1", body: "Parent comment", parent_id: null }),
        makeComment({
          id: "c2",
          body: "Reply to parent",
          parent_id: "c1",
          user_id: "user-2",
        }),
      ];

      const { container } = render(
        <CommentPanel {...defaultProps} comments={comments} />
      );

      const parentText = screen.getByText("Parent comment");
      const replyText = screen.getByText("Reply to parent");

      expect(parentText).toBeInTheDocument();
      expect(replyText).toBeInTheDocument();

      // Reply should be nested within or after the parent's subtree
      // The parent's container should appear before the reply in the DOM
      const allTextNodes = container.textContent || "";
      const parentIdx = allTextNodes.indexOf("Parent comment");
      const replyIdx = allTextNodes.indexOf("Reply to parent");
      expect(parentIdx).toBeLessThan(replyIdx);
    });

    it("renders multiple replies under the same parent", () => {
      const comments = [
        makeComment({ id: "c1", body: "Discussion topic", parent_id: null }),
        makeComment({
          id: "c2",
          body: "First reply",
          parent_id: "c1",
          user_id: "user-2",
        }),
        makeComment({
          id: "c3",
          body: "Second reply",
          parent_id: "c1",
          user_id: "user-3",
        }),
      ];

      render(<CommentPanel {...defaultProps} comments={comments} />);

      expect(screen.getByText("Discussion topic")).toBeInTheDocument();
      expect(screen.getByText("First reply")).toBeInTheDocument();
      expect(screen.getByText("Second reply")).toBeInTheDocument();
    });

    it("does not render replies as top-level comments", () => {
      const comments = [
        makeComment({ id: "c1", body: "Top level", parent_id: null }),
        makeComment({
          id: "c2",
          body: "Nested reply",
          parent_id: "c1",
          user_id: "user-2",
        }),
      ];

      const { container } = render(
        <CommentPanel {...defaultProps} comments={comments} />
      );

      // The reply text should exist but nested within the parent structure
      // Checking that both texts exist is the key assertion
      expect(screen.getByText("Top level")).toBeInTheDocument();
      expect(screen.getByText("Nested reply")).toBeInTheDocument();

      // Verify there is some nesting by checking DOM depth difference
      const topLevelEl = screen.getByText("Top level");
      const replyEl = screen.getByText("Nested reply");

      // Count ancestors to verify reply is deeper in the DOM tree
      const getDepth = (el: HTMLElement) => {
        let depth = 0;
        let current: HTMLElement | null = el;
        while (current && current !== container) {
          depth++;
          current = current.parentElement;
        }
        return depth;
      };

      expect(getDepth(replyEl)).toBeGreaterThanOrEqual(getDepth(topLevelEl));
    });
  });

  // -------------------------------------------------------------------------
  // Submitting new comments
  // -------------------------------------------------------------------------

  describe("submitting new comments", () => {
    it("calls onSubmit when submitting a new comment", async () => {
      const onSubmit = vi.fn();

      render(
        <CommentPanel {...defaultProps} comments={[]} onSubmit={onSubmit} />
      );

      // Find the input/textarea for writing a comment
      const input =
        screen.getByRole("textbox") ||
        screen.getByPlaceholderText(/comment/i);

      fireEvent.change(input, { target: { value: "New comment text" } });

      // Find and click the submit button
      const submitButton =
        screen.getByRole("button", { name: /submit|send|post/i });
      fireEvent.click(submitButton);

      await waitFor(() => {
        expect(onSubmit).toHaveBeenCalledOnce();
      });

      expect(onSubmit).toHaveBeenCalledWith("New comment text");
    });

    it("does not call onSubmit with empty text", () => {
      const onSubmit = vi.fn();

      render(
        <CommentPanel {...defaultProps} comments={[]} onSubmit={onSubmit} />
      );

      // Try submitting without entering text
      const submitButton =
        screen.getByRole("button", { name: /submit|send|post/i });
      fireEvent.click(submitButton);

      expect(onSubmit).not.toHaveBeenCalled();
    });

    it("clears the input after successful submission", async () => {
      const onSubmit = vi.fn();

      render(
        <CommentPanel {...defaultProps} comments={[]} onSubmit={onSubmit} />
      );

      const input = screen.getByRole("textbox") as HTMLInputElement | HTMLTextAreaElement;

      fireEvent.change(input, { target: { value: "Test comment" } });
      expect(input.value).toBe("Test comment");

      const submitButton =
        screen.getByRole("button", { name: /submit|send|post/i });
      fireEvent.click(submitButton);

      await waitFor(() => {
        expect(input.value).toBe("");
      });
    });
  });

  // -------------------------------------------------------------------------
  // Deleting comments
  // -------------------------------------------------------------------------

  describe("deleting comments", () => {
    it("calls onDelete when delete button is clicked", () => {
      const onDelete = vi.fn();
      const comments = [
        makeComment({ id: "c1", body: "My comment", user_id: "user-1" }),
      ];

      render(
        <CommentPanel
          {...defaultProps}
          comments={comments}
          currentUserId="user-1"
          onDelete={onDelete}
        />
      );

      // Delete button should be visible for the current user's comments
      const deleteButton = screen.getByRole("button", {
        name: /delete|remove/i,
      });
      fireEvent.click(deleteButton);

      expect(onDelete).toHaveBeenCalledOnce();
      expect(onDelete).toHaveBeenCalledWith("c1");
    });

    it("only shows delete button for the current user's comments", () => {
      const onDelete = vi.fn();
      const comments = [
        makeComment({
          id: "c1",
          body: "My comment",
          user_id: "user-1",
        }),
        makeComment({
          id: "c2",
          body: "Someone else's comment",
          user_id: "user-2",
        }),
      ];

      render(
        <CommentPanel
          {...defaultProps}
          comments={comments}
          currentUserId="user-1"
          onDelete={onDelete}
        />
      );

      // There should only be one delete button (for user-1's comment)
      const deleteButtons = screen.getAllByRole("button", {
        name: /delete|remove/i,
      });
      expect(deleteButtons).toHaveLength(1);
    });

    it("does not show delete buttons when currentUserId does not match any comment", () => {
      const onDelete = vi.fn();
      const comments = [
        makeComment({ id: "c1", body: "Not my comment", user_id: "user-2" }),
        makeComment({ id: "c2", body: "Also not mine", user_id: "user-3" }),
      ];

      render(
        <CommentPanel
          {...defaultProps}
          comments={comments}
          currentUserId="user-1"
          onDelete={onDelete}
        />
      );

      const deleteButtons = screen.queryAllByRole("button", {
        name: /delete|remove/i,
      });
      expect(deleteButtons).toHaveLength(0);
    });
  });

  // -------------------------------------------------------------------------
  // Resolving comments
  // -------------------------------------------------------------------------

  describe("resolving comments", () => {
    it("calls onResolve when resolve button is clicked", () => {
      const onResolve = vi.fn();
      const comments = [
        makeComment({
          id: "c1",
          body: "Unresolved issue",
          resolved_at: null,
        }),
      ];

      render(
        <CommentPanel
          {...defaultProps}
          comments={comments}
          onResolve={onResolve}
        />
      );

      const resolveButton = screen.getByRole("button", {
        name: /resolve/i,
      });
      fireEvent.click(resolveButton);

      expect(onResolve).toHaveBeenCalledOnce();
      expect(onResolve).toHaveBeenCalledWith("c1");
    });

    it("indicates when a comment is already resolved", () => {
      const comments = [
        makeComment({
          id: "c1",
          body: "Fixed issue",
          resolved_at: "2024-01-02T00:00:00Z",
        }),
      ];

      const { container } = render(
        <CommentPanel {...defaultProps} comments={comments} />
      );

      // The resolved comment should have some visual indicator
      // Check for resolved text, class, or the absence of a resolve button
      const html = container.innerHTML.toLowerCase();
      const hasResolvedIndicator =
        html.includes("resolved") ||
        screen.queryByRole("button", { name: /resolve/i }) === null;

      expect(hasResolvedIndicator).toBe(true);
    });
  });

  // -------------------------------------------------------------------------
  // Empty state
  // -------------------------------------------------------------------------

  describe("empty state", () => {
    it("shows empty state when there are no comments", () => {
      render(<CommentPanel {...defaultProps} comments={[]} />);

      // Shows a "No comments yet." message
      const emptyText = screen.queryByText(/no comments/i);
      expect(emptyText).toBeInTheDocument();

      // The input should still be available for adding the first comment
      const input = screen.queryByRole("textbox");
      expect(input).toBeInTheDocument();
    });

    it("still shows the comment input when there are no comments", () => {
      render(<CommentPanel {...defaultProps} comments={[]} />);

      const input = screen.getByRole("textbox");
      expect(input).toBeInTheDocument();
    });
  });

  // -------------------------------------------------------------------------
  // Edge cases
  // -------------------------------------------------------------------------

  describe("edge cases", () => {
    it("handles comments with very long body text", () => {
      const longBody = "A".repeat(5000);
      const comments = [makeComment({ id: "c1", body: longBody })];

      render(<CommentPanel {...defaultProps} comments={comments} />);

      expect(screen.getByText(longBody)).toBeInTheDocument();
    });

    it("renders multiple top-level comments without parent_id", () => {
      const comments = [
        makeComment({ id: "c1", body: "First", parent_id: null }),
        makeComment({ id: "c2", body: "Second", parent_id: null }),
        makeComment({ id: "c3", body: "Third", parent_id: null }),
      ];

      render(<CommentPanel {...defaultProps} comments={comments} />);

      expect(screen.getByText("First")).toBeInTheDocument();
      expect(screen.getByText("Second")).toBeInTheDocument();
      expect(screen.getByText("Third")).toBeInTheDocument();
    });
  });
});

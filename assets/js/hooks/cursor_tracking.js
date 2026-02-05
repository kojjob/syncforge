/**
 * CursorTracking Hook
 *
 * LiveView hook for real-time cursor tracking with smooth interpolation.
 * Tracks local cursor movements and renders remote cursors with 60fps smoothing.
 *
 * Usage:
 *   <div id="collaboration-area" phx-hook="CursorTracking" data-user-id={@current_user.id}>
 *     <!-- Content here -->
 *   </div>
 *
 * Attributes:
 *   - data-user-id: Current user's ID (required for filtering own cursor)
 *   - data-throttle: Throttle interval in ms (default: 16 = ~60fps)
 *   - data-show-labels: Show/hide cursor labels (default: true)
 */

import { CursorManager, CursorRenderer } from "../sdk/index.js";

const CursorTracking = {
  mounted() {
    // Get configuration from data attributes
    this.currentUserId = this.el.dataset.userId;
    this.throttleMs = parseInt(this.el.dataset.throttle || "16", 10);
    this.showLabels = this.el.dataset.showLabels !== "false";

    // Track local cursor position
    this.lastCursorUpdate = 0;

    // Initialize cursor manager for smooth remote cursor rendering
    this.cursorManager = new CursorManager({
      currentUserId: this.currentUserId,
      smoothingFactor: 0.15,
      snapThreshold: 100,
      idleTimeout: 5000
    });

    // Create container for cursor overlays
    this.cursorContainer = document.createElement("div");
    this.cursorContainer.className = "syncforge-cursor-container";
    this.cursorContainer.style.cssText = `
      position: absolute;
      inset: 0;
      pointer-events: none;
      overflow: hidden;
    `;

    // Ensure parent has relative positioning for absolute cursor container
    const computedStyle = window.getComputedStyle(this.el);
    if (computedStyle.position === "static") {
      this.el.style.position = "relative";
    }

    this.el.appendChild(this.cursorContainer);

    // Initialize cursor renderer
    this.cursorRenderer = new CursorRenderer(this.cursorContainer, {
      showLabels: this.showLabels
    });

    // Connect cursor manager to renderer
    this.cursorManager.onRender((cursors) => {
      this.cursorRenderer.render(cursors);
    });

    // Bind event handlers
    this.handleMouseMove = this.handleMouseMove.bind(this);
    this.handleMouseLeave = this.handleMouseLeave.bind(this);
    this.handleCursorUpdate = this.handleCursorUpdate.bind(this);
    this.handlePresenceDiff = this.handlePresenceDiff.bind(this);

    // Listen for local cursor movements
    this.el.addEventListener("mousemove", this.handleMouseMove);
    this.el.addEventListener("mouseleave", this.handleMouseLeave);

    // Listen for remote cursor updates from the server
    this.handleEvent("cursor:update", this.handleCursorUpdate);

    // Listen for presence changes to remove cursors when users leave
    this.handleEvent("presence_diff", this.handlePresenceDiff);
  },

  /**
   * Handle local cursor movement
   * Throttles updates and sends position to server
   */
  handleMouseMove(event) {
    const now = Date.now();

    // Throttle updates to prevent flooding
    if (now - this.lastCursorUpdate < this.throttleMs) {
      return;
    }

    this.lastCursorUpdate = now;

    // Calculate position relative to the tracked element
    const rect = this.el.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;

    // Send cursor position to server
    this.pushEvent("cursor:update", {
      x: Math.round(x),
      y: Math.round(y)
    });
  },

  /**
   * Handle cursor leaving the tracked area
   */
  handleMouseLeave() {
    // Optionally notify server that cursor has left
    // This could be used to hide the cursor for other users
  },

  /**
   * Handle remote cursor update from server
   */
  handleCursorUpdate(payload) {
    const { user_id, x, y, name, color, element_id } = payload;

    // Update cursor in manager (handles smoothing automatically)
    this.cursorManager.updateCursor(user_id, x, y, {
      name,
      color,
      elementId: element_id
    });
  },

  /**
   * Handle presence diff to remove cursors for users who left
   */
  handlePresenceDiff(diff) {
    // Remove cursors for users who left
    if (diff.leaves) {
      for (const userId of Object.keys(diff.leaves)) {
        this.cursorManager.removeCursor(userId);
      }
    }
  },

  /**
   * Clean up when hook is destroyed
   */
  destroyed() {
    // Remove event listeners
    this.el.removeEventListener("mousemove", this.handleMouseMove);
    this.el.removeEventListener("mouseleave", this.handleMouseLeave);

    // Clean up cursor manager and renderer
    if (this.cursorManager) {
      this.cursorManager.destroy();
    }

    if (this.cursorRenderer) {
      this.cursorRenderer.destroy();
    }

    // Remove cursor container
    if (this.cursorContainer && this.cursorContainer.parentNode) {
      this.cursorContainer.remove();
    }
  }
};

export default CursorTracking;

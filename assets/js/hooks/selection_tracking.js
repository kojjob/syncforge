/**
 * SelectionTracking Hook
 *
 * LiveView hook for real-time selection highlighting.
 * Tracks local text selections and renders remote selections with visual overlays.
 *
 * Usage:
 *   <div id="collaboration-area" phx-hook="SelectionTracking" data-user-id={@current_user.id}>
 *     <!-- Editable content here -->
 *   </div>
 *
 * Attributes:
 *   - data-user-id: Current user's ID (required for filtering own selection)
 *   - data-throttle: Throttle interval in ms (default: 100ms)
 *   - data-show-labels: Show/hide selection labels (default: true)
 */

import { SelectionManager, SelectionRenderer, getTextSelection } from "../sdk/index.js";

const SelectionTracking = {
  mounted() {
    // Get configuration from data attributes
    this.currentUserId = this.el.dataset.userId;
    this.throttleMs = parseInt(this.el.dataset.throttle || "100", 10);
    this.showLabels = this.el.dataset.showLabels !== "false";

    // Track selection updates
    this.lastSelectionUpdate = 0;
    this.lastSelection = null;

    // Initialize selection manager for remote selection rendering
    this.selectionManager = new SelectionManager({
      currentUserId: this.currentUserId,
      idleTimeout: 5000
    });

    // Create container for selection overlays
    this.selectionContainer = document.createElement("div");
    this.selectionContainer.className = "syncforge-selection-container";
    this.selectionContainer.style.cssText = `
      position: absolute;
      inset: 0;
      pointer-events: none;
      overflow: hidden;
    `;

    // Ensure parent has relative positioning for absolute selection container
    const computedStyle = window.getComputedStyle(this.el);
    if (computedStyle.position === "static") {
      this.el.style.position = "relative";
    }

    this.el.appendChild(this.selectionContainer);

    // Initialize selection renderer
    this.selectionRenderer = new SelectionRenderer(this.selectionContainer, {
      showLabels: this.showLabels
    });

    // Connect selection manager to renderer
    this.selectionManager.onRender((selections) => {
      this.selectionRenderer.render(selections);
    });

    // Bind event handlers
    this.handleSelectionChange = this.handleSelectionChange.bind(this);
    this.handleMouseUp = this.handleMouseUp.bind(this);
    this.handleKeyUp = this.handleKeyUp.bind(this);
    this.handleSelectionUpdate = this.handleSelectionUpdate.bind(this);
    this.handlePresenceDiff = this.handlePresenceDiff.bind(this);

    // Listen for local selection changes
    document.addEventListener("selectionchange", this.handleSelectionChange);
    this.el.addEventListener("mouseup", this.handleMouseUp);
    this.el.addEventListener("keyup", this.handleKeyUp);

    // Listen for remote selection updates from the server
    this.handleEvent("selection:update", this.handleSelectionUpdate);

    // Listen for presence changes to remove selections when users leave
    this.handleEvent("presence_diff", this.handlePresenceDiff);
  },

  /**
   * Handle selection change events
   * Throttled to prevent excessive updates
   */
  handleSelectionChange() {
    const now = Date.now();

    // Throttle updates to prevent flooding
    if (now - this.lastSelectionUpdate < this.throttleMs) {
      return;
    }

    // Defer to mouseup/keyup for actual sending to avoid mid-selection updates
  },

  /**
   * Handle mouse up - send selection after user finishes selecting
   */
  handleMouseUp() {
    this.sendSelectionUpdate();
  },

  /**
   * Handle key up - send selection after shift+arrow selections
   */
  handleKeyUp(event) {
    // Only send on selection-related keys
    if (event.shiftKey || ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown", "Home", "End"].includes(event.key)) {
      this.sendSelectionUpdate();
    }
  },

  /**
   * Send current selection to server
   */
  sendSelectionUpdate() {
    const now = Date.now();

    // Throttle updates
    if (now - this.lastSelectionUpdate < this.throttleMs) {
      return;
    }

    this.lastSelectionUpdate = now;

    // Get current selection
    const selection = getTextSelection();

    // Only send if selection changed
    const selectionJson = JSON.stringify(selection);
    if (selectionJson === this.lastSelection) {
      return;
    }

    this.lastSelection = selectionJson;

    // Find if selection is within our element
    const windowSelection = window.getSelection();
    if (windowSelection && !windowSelection.isCollapsed) {
      const range = windowSelection.getRangeAt(0);
      if (!this.el.contains(range.commonAncestorContainer)) {
        // Selection is outside our element, send null to clear
        this.pushEvent("selection:update", { selection: null });
        return;
      }
    }

    // Calculate selection bounds relative to our container
    if (selection && windowSelection) {
      const range = windowSelection.getRangeAt(0);
      const rect = range.getBoundingClientRect();
      const containerRect = this.el.getBoundingClientRect();

      selection.bounds = {
        left: rect.left - containerRect.left,
        top: rect.top - containerRect.top,
        width: rect.width,
        height: rect.height
      };
    }

    // Send selection to server
    this.pushEvent("selection:update", {
      selection: selection,
      element_id: this.el.id || null
    });
  },

  /**
   * Handle remote selection update from server
   */
  handleSelectionUpdate(payload) {
    const { user_id, selection, name, color, element_id } = payload;

    // Update selection in manager
    this.selectionManager.updateSelection(user_id, selection, {
      name,
      color,
      elementId: element_id
    });
  },

  /**
   * Handle presence diff to remove selections for users who left
   */
  handlePresenceDiff(diff) {
    // Remove selections for users who left
    if (diff.leaves) {
      for (const userId of Object.keys(diff.leaves)) {
        this.selectionManager.removeSelection(userId);
      }
    }
  },

  /**
   * Clean up when hook is destroyed
   */
  destroyed() {
    // Remove event listeners
    document.removeEventListener("selectionchange", this.handleSelectionChange);
    this.el.removeEventListener("mouseup", this.handleMouseUp);
    this.el.removeEventListener("keyup", this.handleKeyUp);

    // Clean up selection manager and renderer
    if (this.selectionManager) {
      this.selectionManager.destroy();
    }

    if (this.selectionRenderer) {
      this.selectionRenderer.destroy();
    }

    // Remove selection container
    if (this.selectionContainer && this.selectionContainer.parentNode) {
      this.selectionContainer.remove();
    }
  }
};

export default SelectionTracking;

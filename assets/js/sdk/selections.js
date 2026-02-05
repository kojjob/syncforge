/**
 * SyncForge Selection Highlighting SDK
 *
 * Provides client-side selection highlighting for remote users.
 * Renders colored overlays showing what other users have selected.
 */

/**
 * Remote selection state
 */
class RemoteSelection {
  constructor(userId, options = {}) {
    this.userId = userId;
    this.name = options.name || "Anonymous";
    this.color = options.color || "#3B82F6";

    // Selection data from server
    this.selection = null;
    this.elementId = null;

    // Visibility and idle handling
    this.visible = true;
    this.lastUpdate = Date.now();
    this.idleTimeout = options.idleTimeout || 5000; // 5 seconds
  }

  /**
   * Update selection from server
   * @param {object|null} selection - Selection data or null to clear
   * @param {object} options - Additional options
   */
  updateSelection(selection, options = {}) {
    this.selection = selection;
    this.lastUpdate = Date.now();
    this.visible = selection !== null;

    if (options.elementId !== undefined) {
      this.elementId = options.elementId;
    }

    if (options.name) {
      this.name = options.name;
    }

    if (options.color) {
      this.color = options.color;
    }
  }

  /**
   * Check if selection should be considered idle
   * @returns {boolean}
   */
  isIdle() {
    return Date.now() - this.lastUpdate > this.idleTimeout;
  }

  /**
   * Get current selection for rendering
   * @returns {{userId: string, selection: object|null, name: string, color: string, visible: boolean, elementId: string|null}}
   */
  getSelection() {
    return {
      userId: this.userId,
      selection: this.selection,
      name: this.name,
      color: this.color,
      visible: this.visible && !this.isIdle() && this.selection !== null,
      elementId: this.elementId
    };
  }
}

/**
 * SelectionManager handles multiple remote selections
 */
export class SelectionManager {
  constructor(options = {}) {
    // Store all remote selections by userId
    this.selections = new Map();

    // Configuration
    this.idleTimeout = options.idleTimeout || 5000;
    this.renderCallback = options.onRender || null;

    // Current user ID (to exclude from rendering)
    this.currentUserId = options.currentUserId || null;

    // Periodic cleanup interval
    this.cleanupInterval = null;
    this.startCleanupInterval();
  }

  /**
   * Set the current user ID to exclude from display
   * @param {string} userId
   */
  setCurrentUser(userId) {
    this.currentUserId = userId;
  }

  /**
   * Set the render callback
   * @param {function} callback - Called with selections array when updates occur
   */
  onRender(callback) {
    this.renderCallback = callback;
  }

  /**
   * Update a remote user's selection
   * @param {string} userId - User ID
   * @param {object|null} selection - Selection data or null to clear
   * @param {object} options - Additional options (name, color, elementId)
   */
  updateSelection(userId, selection, options = {}) {
    // Ignore updates for current user
    if (userId === this.currentUserId) {
      return;
    }

    let remoteSelection = this.selections.get(userId);

    if (!remoteSelection) {
      remoteSelection = new RemoteSelection(userId, {
        idleTimeout: this.idleTimeout,
        ...options
      });
      this.selections.set(userId, remoteSelection);
    }

    remoteSelection.updateSelection(selection, options);

    // Trigger render callback
    this.triggerRender();
  }

  /**
   * Remove a selection (user left)
   * @param {string} userId
   */
  removeSelection(userId) {
    this.selections.delete(userId);
    this.triggerRender();
  }

  /**
   * Clear all selections
   */
  clear() {
    this.selections.clear();
    this.triggerRender();
  }

  /**
   * Start cleanup interval for idle selections
   */
  startCleanupInterval() {
    this.cleanupInterval = setInterval(() => {
      let removed = false;
      const now = Date.now();

      for (const [userId, selection] of this.selections.entries()) {
        // Remove selections that have been idle for twice the timeout
        if (now - selection.lastUpdate > selection.idleTimeout * 2) {
          this.selections.delete(userId);
          removed = true;
        }
      }

      if (removed) {
        this.triggerRender();
      }
    }, 1000);
  }

  /**
   * Stop cleanup interval
   */
  stopCleanupInterval() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }
  }

  /**
   * Trigger render callback with current selections
   */
  triggerRender() {
    if (this.renderCallback) {
      const selections = this.getVisibleSelections();
      this.renderCallback(selections);
    }
  }

  /**
   * Get all visible selections
   * @returns {Array}
   */
  getVisibleSelections() {
    const selections = [];
    for (const selection of this.selections.values()) {
      const data = selection.getSelection();
      if (data.visible) {
        selections.push(data);
      }
    }
    return selections;
  }

  /**
   * Get all selections (including hidden)
   * @returns {Array}
   */
  getAllSelections() {
    const selections = [];
    for (const selection of this.selections.values()) {
      selections.push(selection.getSelection());
    }
    return selections;
  }

  /**
   * Destroy the manager and clean up
   */
  destroy() {
    this.stopCleanupInterval();
    this.clear();
    this.renderCallback = null;
  }
}

/**
 * Get text selection range in a content-editable or textarea element
 * @returns {object|null} Selection range or null if no selection
 */
export function getTextSelection() {
  const selection = window.getSelection();

  if (!selection || selection.isCollapsed) {
    return null;
  }

  const range = selection.getRangeAt(0);

  return {
    text: selection.toString(),
    startOffset: range.startOffset,
    endOffset: range.endOffset,
    startContainer: getNodePath(range.startContainer),
    endContainer: getNodePath(range.endContainer),
    collapsed: selection.isCollapsed
  };
}

/**
 * Get DOM path to a node (for serialization)
 * @param {Node} node
 * @returns {Array<number>}
 */
function getNodePath(node) {
  const path = [];
  let current = node;

  while (current && current.parentNode) {
    const parent = current.parentNode;
    const index = Array.from(parent.childNodes).indexOf(current);
    path.unshift(index);
    current = parent;

    // Stop at document body
    if (current === document.body) {
      break;
    }
  }

  return path;
}

/**
 * Create a selection highlight element
 * @param {string} userId
 * @param {string} name
 * @param {string} color
 * @returns {HTMLElement}
 */
export function createSelectionHighlight(userId, name, color) {
  const highlight = document.createElement("div");
  highlight.className = "syncforge-selection";
  highlight.dataset.userId = userId;
  highlight.style.cssText = `
    position: absolute;
    background-color: ${color}20;
    border: 1px solid ${color};
    border-radius: 2px;
    pointer-events: none;
    z-index: 9998;
    transition: opacity 0.2s ease;
  `;

  // Add a small label showing who selected
  const label = document.createElement("div");
  label.className = "syncforge-selection-label";
  label.textContent = name;
  label.style.cssText = `
    position: absolute;
    top: -18px;
    left: 0;
    background: ${color};
    color: #fff;
    font-size: 10px;
    font-weight: 500;
    padding: 1px 6px;
    border-radius: 2px;
    white-space: nowrap;
    box-shadow: 0 1px 2px rgba(0,0,0,0.2);
  `;
  highlight.appendChild(label);

  return highlight;
}

/**
 * SelectionRenderer handles DOM rendering of selections
 */
export class SelectionRenderer {
  constructor(container, options = {}) {
    this.container = typeof container === "string"
      ? document.querySelector(container)
      : container;

    this.selectionElements = new Map();
    this.showLabels = options.showLabels !== false;
  }

  /**
   * Update selection highlights in the DOM
   * @param {Array} selections - Array of selection data from SelectionManager
   */
  render(selections) {
    const currentUserIds = new Set(selections.map(s => s.userId));

    // Remove selections that are no longer present
    for (const [userId, element] of this.selectionElements.entries()) {
      if (!currentUserIds.has(userId)) {
        element.remove();
        this.selectionElements.delete(userId);
      }
    }

    // Update or create selection elements
    for (const selection of selections) {
      if (!selection.selection) {
        // No selection data, remove element if exists
        const element = this.selectionElements.get(selection.userId);
        if (element) {
          element.remove();
          this.selectionElements.delete(selection.userId);
        }
        continue;
      }

      let element = this.selectionElements.get(selection.userId);

      if (!element) {
        element = createSelectionHighlight(
          selection.userId,
          selection.name,
          selection.color
        );
        this.container.appendChild(element);
        this.selectionElements.set(selection.userId, element);
      }

      // Calculate position from selection range
      const rect = this.getSelectionRect(selection);
      if (rect) {
        element.style.left = `${rect.left}px`;
        element.style.top = `${rect.top}px`;
        element.style.width = `${rect.width}px`;
        element.style.height = `${rect.height}px`;
        element.style.opacity = selection.visible ? "1" : "0";
      } else {
        element.style.opacity = "0";
      }

      // Update label if needed
      const label = element.querySelector(".syncforge-selection-label");
      if (label) {
        label.style.display = this.showLabels ? "block" : "none";
        if (label.textContent !== selection.name) {
          label.textContent = selection.name;
        }
      }
    }
  }

  /**
   * Calculate bounding rectangle for a selection
   * @param {object} selection - Selection data
   * @returns {{left: number, top: number, width: number, height: number}|null}
   */
  getSelectionRect(selection) {
    // If selection has explicit bounds, use them
    if (selection.selection && selection.selection.bounds) {
      return selection.selection.bounds;
    }

    // If selection targets an element, get its bounds
    if (selection.elementId) {
      const element = document.getElementById(selection.elementId);
      if (element) {
        const rect = element.getBoundingClientRect();
        const containerRect = this.container.getBoundingClientRect();

        return {
          left: rect.left - containerRect.left,
          top: rect.top - containerRect.top,
          width: rect.width,
          height: rect.height
        };
      }
    }

    // Fallback: try to reconstruct range from selection data
    if (selection.selection && selection.selection.startOffset !== undefined) {
      // This is a text selection, would need more complex handling
      // For now, return null and let specific implementations handle it
      return null;
    }

    return null;
  }

  /**
   * Clean up all selection elements
   */
  destroy() {
    for (const element of this.selectionElements.values()) {
      element.remove();
    }
    this.selectionElements.clear();
  }
}

export default SelectionManager;

/**
 * SyncForge Cursor Smoothing SDK
 *
 * Provides client-side cursor interpolation for smooth remote cursor rendering.
 * Uses linear interpolation (lerp) with requestAnimationFrame for 60fps animation.
 */

/**
 * Linear interpolation between two values
 * @param {number} start - Starting value
 * @param {number} end - Target value
 * @param {number} factor - Interpolation factor (0-1)
 * @returns {number} Interpolated value
 */
export function lerp(start, end, factor) {
  return start + (end - start) * factor;
}

/**
 * Calculate distance between two points
 * @param {number} x1
 * @param {number} y1
 * @param {number} x2
 * @param {number} y2
 * @returns {number} Distance
 */
export function distance(x1, y1, x2, y2) {
  return Math.sqrt(Math.pow(x2 - x1, 2) + Math.pow(y2 - y1, 2));
}

/**
 * Remote cursor state for smooth interpolation
 */
class RemoteCursor {
  constructor(userId, options = {}) {
    this.userId = userId;
    this.name = options.name || "Anonymous";
    this.color = options.color || "#3B82F6";

    // Current rendered position
    this.currentX = 0;
    this.currentY = 0;

    // Target position (from server)
    this.targetX = 0;
    this.targetY = 0;

    // Smoothing configuration
    this.smoothingFactor = options.smoothingFactor || 0.15;
    this.snapThreshold = options.snapThreshold || 100; // Snap if distance > threshold

    // Visibility and idle handling
    this.visible = true;
    this.lastUpdate = Date.now();
    this.idleTimeout = options.idleTimeout || 5000; // 5 seconds

    // Optional element-relative positioning
    this.elementId = null;

    // Animation state
    this.isAnimating = false;
  }

  /**
   * Update target position from server
   * @param {number} x - Target X coordinate
   * @param {number} y - Target Y coordinate
   * @param {object} options - Additional options
   */
  updateTarget(x, y, options = {}) {
    this.targetX = x;
    this.targetY = y;
    this.lastUpdate = Date.now();
    this.visible = true;

    if (options.elementId !== undefined) {
      this.elementId = options.elementId;
    }

    if (options.name) {
      this.name = options.name;
    }

    if (options.color) {
      this.color = options.color;
    }

    // Snap to position if distance is too large (e.g., user teleported)
    const dist = distance(this.currentX, this.currentY, this.targetX, this.targetY);
    if (dist > this.snapThreshold) {
      this.currentX = this.targetX;
      this.currentY = this.targetY;
    }
  }

  /**
   * Perform one frame of interpolation
   * @returns {boolean} True if cursor moved (needs re-render)
   */
  interpolate() {
    const prevX = this.currentX;
    const prevY = this.currentY;

    this.currentX = lerp(this.currentX, this.targetX, this.smoothingFactor);
    this.currentY = lerp(this.currentY, this.targetY, this.smoothingFactor);

    // Check if we've essentially reached the target (within 0.5px)
    const dist = distance(this.currentX, this.currentY, this.targetX, this.targetY);
    if (dist < 0.5) {
      this.currentX = this.targetX;
      this.currentY = this.targetY;
    }

    // Return true if position changed significantly
    return Math.abs(this.currentX - prevX) > 0.1 || Math.abs(this.currentY - prevY) > 0.1;
  }

  /**
   * Check if cursor should be considered idle
   * @returns {boolean}
   */
  isIdle() {
    return Date.now() - this.lastUpdate > this.idleTimeout;
  }

  /**
   * Get current position for rendering
   * @returns {{x: number, y: number, name: string, color: string, visible: boolean, elementId: string|null}}
   */
  getPosition() {
    return {
      userId: this.userId,
      x: this.currentX,
      y: this.currentY,
      name: this.name,
      color: this.color,
      visible: this.visible && !this.isIdle(),
      elementId: this.elementId
    };
  }
}

/**
 * CursorManager handles multiple remote cursors with smooth interpolation
 */
export class CursorManager {
  constructor(options = {}) {
    // Store all remote cursors by userId
    this.cursors = new Map();

    // Configuration
    this.smoothingFactor = options.smoothingFactor || 0.15;
    this.snapThreshold = options.snapThreshold || 100;
    this.idleTimeout = options.idleTimeout || 5000;
    this.renderCallback = options.onRender || null;

    // Animation state
    this.animationFrameId = null;
    this.isRunning = false;

    // Current user ID (to exclude from rendering)
    this.currentUserId = options.currentUserId || null;
  }

  /**
   * Set the current user ID to exclude from cursor display
   * @param {string} userId
   */
  setCurrentUser(userId) {
    this.currentUserId = userId;
  }

  /**
   * Set the render callback
   * @param {function} callback - Called with cursor positions array on each frame
   */
  onRender(callback) {
    this.renderCallback = callback;
  }

  /**
   * Update a remote cursor position
   * @param {string} userId - User ID
   * @param {number} x - X coordinate
   * @param {number} y - Y coordinate
   * @param {object} options - Additional options (name, color, elementId)
   */
  updateCursor(userId, x, y, options = {}) {
    // Ignore updates for current user
    if (userId === this.currentUserId) {
      return;
    }

    let cursor = this.cursors.get(userId);

    if (!cursor) {
      cursor = new RemoteCursor(userId, {
        smoothingFactor: this.smoothingFactor,
        snapThreshold: this.snapThreshold,
        idleTimeout: this.idleTimeout,
        ...options
      });
      this.cursors.set(userId, cursor);
    }

    cursor.updateTarget(x, y, options);

    // Start animation loop if not running
    if (!this.isRunning) {
      this.start();
    }
  }

  /**
   * Remove a cursor (user left)
   * @param {string} userId
   */
  removeCursor(userId) {
    this.cursors.delete(userId);
  }

  /**
   * Clear all cursors
   */
  clear() {
    this.cursors.clear();
  }

  /**
   * Start the animation loop
   */
  start() {
    if (this.isRunning) return;
    this.isRunning = true;
    this.animate();
  }

  /**
   * Stop the animation loop
   */
  stop() {
    this.isRunning = false;
    if (this.animationFrameId) {
      cancelAnimationFrame(this.animationFrameId);
      this.animationFrameId = null;
    }
  }

  /**
   * Animation loop - interpolates all cursors and triggers render callback
   */
  animate() {
    if (!this.isRunning) return;

    let anyMoved = false;

    // Interpolate all cursors
    for (const cursor of this.cursors.values()) {
      if (cursor.interpolate()) {
        anyMoved = true;
      }
    }

    // Remove idle cursors that have been hidden for a while
    const now = Date.now();
    for (const [userId, cursor] of this.cursors.entries()) {
      if (now - cursor.lastUpdate > cursor.idleTimeout * 2) {
        this.cursors.delete(userId);
      }
    }

    // Trigger render callback with current positions
    if (this.renderCallback && (anyMoved || this.cursors.size > 0)) {
      const positions = this.getVisibleCursors();
      this.renderCallback(positions);
    }

    // Continue animation loop if we have cursors
    if (this.cursors.size > 0) {
      this.animationFrameId = requestAnimationFrame(() => this.animate());
    } else {
      this.isRunning = false;
    }
  }

  /**
   * Get all visible cursor positions
   * @returns {Array<{userId: string, x: number, y: number, name: string, color: string, visible: boolean}>}
   */
  getVisibleCursors() {
    const positions = [];
    for (const cursor of this.cursors.values()) {
      const pos = cursor.getPosition();
      if (pos.visible) {
        positions.push(pos);
      }
    }
    return positions;
  }

  /**
   * Get all cursor positions (including hidden)
   * @returns {Array}
   */
  getAllCursors() {
    const positions = [];
    for (const cursor of this.cursors.values()) {
      positions.push(cursor.getPosition());
    }
    return positions;
  }

  /**
   * Destroy the manager and clean up
   */
  destroy() {
    this.stop();
    this.clear();
    this.renderCallback = null;
  }
}

/**
 * Create a cursor DOM element
 * @param {string} userId
 * @param {string} name
 * @param {string} color
 * @returns {HTMLElement}
 */
export function createCursorElement(userId, name, color) {
  const cursor = document.createElement("div");
  cursor.className = "syncforge-cursor";
  cursor.dataset.userId = userId;
  cursor.style.cssText = `
    position: absolute;
    pointer-events: none;
    z-index: 9999;
    transition: opacity 0.3s ease;
  `;

  // Cursor pointer SVG
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("width", "24");
  svg.setAttribute("height", "24");
  svg.setAttribute("viewBox", "0 0 24 24");
  svg.style.cssText = `filter: drop-shadow(0 1px 2px rgba(0,0,0,0.3));`;

  const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
  path.setAttribute("d", "M5.5 3.21V20.8c0 .45.54.67.85.35l4.86-4.86a.5.5 0 0 1 .35-.15h6.87a.5.5 0 0 0 .35-.85L6.35 2.86a.5.5 0 0 0-.85.35Z");
  path.setAttribute("fill", color);
  path.setAttribute("stroke", "#fff");
  path.setAttribute("stroke-width", "1.5");

  svg.appendChild(path);
  cursor.appendChild(svg);

  // Name label
  const label = document.createElement("div");
  label.className = "syncforge-cursor-label";
  label.textContent = name;
  label.style.cssText = `
    position: absolute;
    left: 16px;
    top: 16px;
    background: ${color};
    color: #fff;
    font-size: 12px;
    font-weight: 500;
    padding: 2px 8px;
    border-radius: 4px;
    white-space: nowrap;
    box-shadow: 0 1px 3px rgba(0,0,0,0.2);
  `;
  cursor.appendChild(label);

  return cursor;
}

/**
 * CursorRenderer handles DOM rendering of cursors
 */
export class CursorRenderer {
  constructor(container, options = {}) {
    this.container = typeof container === "string"
      ? document.querySelector(container)
      : container;

    this.cursorElements = new Map();
    this.showLabels = options.showLabels !== false;
  }

  /**
   * Update cursor positions in the DOM
   * @param {Array} cursors - Array of cursor positions from CursorManager
   */
  render(cursors) {
    const currentUserIds = new Set(cursors.map(c => c.userId));

    // Remove cursors that are no longer present
    for (const [userId, element] of this.cursorElements.entries()) {
      if (!currentUserIds.has(userId)) {
        element.remove();
        this.cursorElements.delete(userId);
      }
    }

    // Update or create cursor elements
    for (const cursor of cursors) {
      let element = this.cursorElements.get(cursor.userId);

      if (!element) {
        element = createCursorElement(cursor.userId, cursor.name, cursor.color);
        this.container.appendChild(element);
        this.cursorElements.set(cursor.userId, element);
      }

      // Update position
      element.style.transform = `translate(${cursor.x}px, ${cursor.y}px)`;
      element.style.opacity = cursor.visible ? "1" : "0";

      // Update label if needed
      const label = element.querySelector(".syncforge-cursor-label");
      if (label) {
        label.style.display = this.showLabels ? "block" : "none";
        if (label.textContent !== cursor.name) {
          label.textContent = cursor.name;
        }
      }
    }
  }

  /**
   * Clean up all cursor elements
   */
  destroy() {
    for (const element of this.cursorElements.values()) {
      element.remove();
    }
    this.cursorElements.clear();
  }
}

export default CursorManager;

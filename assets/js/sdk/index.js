/**
 * SyncForge SDK - Main Entry Point
 *
 * Provides client-side utilities for real-time collaboration features.
 */

// Cursor smoothing SDK
export {
  lerp,
  distance,
  CursorManager,
  CursorRenderer,
  createCursorElement
} from "./cursors.js";

// Default export for convenience
import CursorManager from "./cursors.js";
export default CursorManager;

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

// Selection highlighting SDK
export {
  SelectionManager,
  SelectionRenderer,
  createSelectionHighlight,
  getTextSelection
} from "./selections.js";

// Default exports for convenience
import CursorManager from "./cursors.js";
import SelectionManager from "./selections.js";
export default CursorManager;
export { SelectionManager as Selections };

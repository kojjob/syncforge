/**
 * Phoenix LiveView Hooks for SyncForge
 */

import CursorTracking from "./cursor_tracking.js";
import SelectionTracking from "./selection_tracking.js";
import ConnectionStatus from "./connection_status.js";

/**
 * ThemeToggle Hook
 * Handles dark/light mode with system preference detection
 */
const ThemeToggle = {
  validThemes: new Set(["light", "dark", "system"]),

  mounted() {
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");

    // Restore persisted theme and sync with LiveView assign.
    const storedTheme = this.normalizeTheme(localStorage.getItem("phx:theme"));
    const assignedTheme = this.normalizeTheme(this.el.dataset.theme);
    const themeToApply = storedTheme || assignedTheme;

    this.applyTheme(themeToApply);

    if (themeToApply !== assignedTheme) {
      this.pushEvent("toggle_theme", { theme: themeToApply });
    }

    // Listen for system theme changes
    this.handleSystemThemeChange = (e) => {
      if (this.el.dataset.theme === "system") {
        this.applySystemTheme(e.matches);
      }
    };
    this.mediaQuery.addEventListener("change", this.handleSystemThemeChange);
  },

  updated() {
    this.applyTheme(this.normalizeTheme(this.el.dataset.theme));
  },

  destroyed() {
    if (this.mediaQuery) {
      this.mediaQuery.removeEventListener("change", this.handleSystemThemeChange);
    }
  },

  normalizeTheme(theme) {
    return this.validThemes.has(theme) ? theme : "system";
  },

  applyTheme(theme) {
    const safeTheme = this.normalizeTheme(theme);

    if (safeTheme === "system") {
      localStorage.removeItem("phx:theme");
    } else {
      localStorage.setItem("phx:theme", safeTheme);
    }

    if (safeTheme === "system") {
      this.applySystemTheme(this.mediaQuery.matches);
    } else {
      document.documentElement.setAttribute("data-theme", safeTheme);
      this.el.setAttribute("data-resolved-theme", safeTheme);
    }
  },

  applySystemTheme(prefersDark) {
    const resolvedTheme = prefersDark ? "dark" : "light";
    document.documentElement.setAttribute("data-theme", resolvedTheme);
    this.el.setAttribute("data-resolved-theme", resolvedTheme);
  }
};

/**
 * AnimatedCursors Hook
 * Creates animated cursor demonstrations on the landing page
 */
const AnimatedCursors = {
  mounted() {
    this.cursors = this.el.querySelectorAll(".demo-cursor");
    this.animateCursors();
  },

  animateCursors() {
    const container = this.el;
    const rect = container.getBoundingClientRect();

    this.cursors.forEach((cursor, index) => {
      this.animateSingleCursor(cursor, index, rect);
    });
  },

  animateSingleCursor(cursor, index, containerRect) {
    const animate = () => {
      const x = Math.random() * (containerRect.width - 40) + 20;
      const y = Math.random() * (containerRect.height - 40) + 20;
      const duration = 2000 + Math.random() * 2000;

      cursor.style.transition = `transform ${duration}ms ease-in-out`;
      cursor.style.transform = `translate(${x}px, ${y}px)`;

      setTimeout(() => animate(), duration);
    };

    // Stagger the initial animation
    setTimeout(() => animate(), index * 500);
  }
};

/**
 * PresencePulse Hook
 * Adds pulsing animation to presence indicators
 */
const PresencePulse = {
  mounted() {
    this.indicators = this.el.querySelectorAll(".presence-indicator");
    this.startPulsing();
  },

  startPulsing() {
    this.indicators.forEach((indicator, index) => {
      // Stagger the pulse animations
      indicator.style.animationDelay = `${index * 0.2}s`;
    });
  }
};

// Export all hooks
export const Hooks = {
  ThemeToggle,
  AnimatedCursors,
  PresencePulse,
  CursorTracking,
  SelectionTracking,
  ConnectionStatus
};

export default Hooks;

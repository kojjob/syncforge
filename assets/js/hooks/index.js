/**
 * Phoenix LiveView Hooks for SyncForge
 */

import CursorTracking from "./cursor_tracking.js";

/**
 * ThemeToggle Hook
 * Handles dark/light mode with system preference detection
 */
const ThemeToggle = {
  mounted() {
    this.applyTheme(this.el.dataset.theme);

    // Listen for system theme changes
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
    this.handleSystemThemeChange = (e) => {
      if (this.el.dataset.theme === "system") {
        this.applySystemTheme(e.matches);
      }
    };
    this.mediaQuery.addEventListener("change", this.handleSystemThemeChange);
  },

  updated() {
    this.applyTheme(this.el.dataset.theme);
  },

  destroyed() {
    if (this.mediaQuery) {
      this.mediaQuery.removeEventListener("change", this.handleSystemThemeChange);
    }
  },

  applyTheme(theme) {
    if (theme === "system") {
      this.applySystemTheme(this.mediaQuery.matches);
    } else {
      document.documentElement.setAttribute("data-theme", theme);
      this.el.setAttribute("data-resolved-theme", theme);
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
  CursorTracking
};

export default Hooks;

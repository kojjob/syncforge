/**
 * Phoenix LiveView Hooks for SyncForge
 */

/**
 * ThemeToggle Hook
 * Handles dark/light mode with system preference detection
 */
const ThemeToggle = {
  mounted() {
    // Apply the theme from the element's data attribute
    this.applyTheme(this.el.dataset.theme);

    // Listen for system theme changes
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
    this.handleSystemThemeChange = (e) => {
      const currentTheme = this.el.dataset.theme;
      if (currentTheme === "system") {
        this.applySystemTheme(e.matches);
      }
    };
    this.mediaQuery.addEventListener("change", this.handleSystemThemeChange);

    // Store initial theme
    this.storeTheme(this.el.dataset.theme);
  },

  updated() {
    // When LiveView updates the element, apply the new theme
    const theme = this.el.dataset.theme;
    this.applyTheme(theme);
    this.storeTheme(theme);
  },

  destroyed() {
    if (this.mediaQuery) {
      this.mediaQuery.removeEventListener("change", this.handleSystemThemeChange);
    }
  },

  applyTheme(theme) {
    const root = document.documentElement;

    if (theme === "system") {
      // Remove explicit theme, let CSS media query handle it
      root.removeAttribute("data-theme");
      this.applySystemTheme(this.mediaQuery.matches);
    } else {
      // Set explicit light or dark theme
      root.setAttribute("data-theme", theme);
      if (theme === "dark") {
        root.classList.add("dark");
      } else {
        root.classList.remove("dark");
      }
    }

    // Update visual indicator on the element
    this.el.setAttribute("data-resolved-theme", this.getResolvedTheme(theme));
  },

  applySystemTheme(prefersDark) {
    const root = document.documentElement;
    const resolvedTheme = prefersDark ? "dark" : "light";
    // For system preference, we still need to set the attribute for CSS to pick up
    root.setAttribute("data-theme", resolvedTheme);
    if (prefersDark) {
      root.classList.add("dark");
    } else {
      root.classList.remove("dark");
    }
  },

  getResolvedTheme(theme) {
    if (theme === "system") {
      return this.mediaQuery.matches ? "dark" : "light";
    }
    return theme;
  },

  storeTheme(theme) {
    try {
      localStorage.setItem("syncforge-theme", theme);
    } catch (e) {
      // localStorage might not be available
    }
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
  PresencePulse
};

export default Hooks;

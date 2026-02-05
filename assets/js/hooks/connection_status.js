/**
 * ConnectionStatus Hook
 *
 * LiveView hook for displaying connection status with automatic reconnection handling.
 * Shows visual indicators when connection is lost and manages reconnection attempts.
 *
 * Usage:
 *   <div id="connection-status" phx-hook="ConnectionStatus" data-show-indicator="true">
 *     <!-- Optional custom content -->
 *   </div>
 *
 * Attributes:
 *   - data-show-indicator: Show floating connection indicator (default: true)
 *   - data-reconnect-delay: Base reconnect delay in ms (default: 1000)
 *   - data-max-delay: Maximum reconnect delay in ms (default: 30000)
 *
 * Events:
 *   - syncforge:connected - Fired when connection is established
 *   - syncforge:disconnected - Fired when connection is lost
 *   - syncforge:reconnecting - Fired during reconnection attempts
 */

import {
  ConnectionManager,
  ConnectionState,
  createConnectionIndicator
} from "../sdk/index.js";

const ConnectionStatus = {
  mounted() {
    // Get configuration from data attributes
    this.showIndicator = this.el.dataset.showIndicator !== "false";
    this.reconnectDelay = parseInt(this.el.dataset.reconnectDelay || "1000", 10);
    this.maxDelay = parseInt(this.el.dataset.maxDelay || "30000", 10);

    // Initialize connection manager
    this.connectionManager = new ConnectionManager({
      baseDelay: this.reconnectDelay,
      maxDelay: this.maxDelay,
      maxAttempts: Infinity
    });

    // Track connection state
    this.isConnected = true;
    this.reconnectAttempt = 0;

    // Bind event handlers
    this.handlePhxConnect = this.handlePhxConnect.bind(this);
    this.handlePhxDisconnect = this.handlePhxDisconnect.bind(this);
    this.handleVisibilityChange = this.handleVisibilityChange.bind(this);
    this.handleOnline = this.handleOnline.bind(this);
    this.handleOffline = this.handleOffline.bind(this);

    // Listen for Phoenix LiveView connection events
    window.addEventListener("phx:live_socket_connected", this.handlePhxConnect);
    window.addEventListener("phx:live_socket_disconnected", this.handlePhxDisconnect);

    // Listen for browser visibility changes
    document.addEventListener("visibilitychange", this.handleVisibilityChange);

    // Listen for network status changes
    window.addEventListener("online", this.handleOnline);
    window.addEventListener("offline", this.handleOffline);

    // Set up connection manager event listeners
    this.setupConnectionEvents();

    // Create connection indicator if enabled
    if (this.showIndicator) {
      this.indicator = createConnectionIndicator(this.connectionManager);
      document.body.appendChild(this.indicator);
    }

    // Check initial connection state
    this.checkConnectionState();
  },

  /**
   * Set up connection manager event listeners
   */
  setupConnectionEvents() {
    this.connectionManager.on("stateChange", ({ state, prevState }) => {
      // Dispatch custom events for external listeners
      this.dispatchConnectionEvent(state);

      // Update element classes
      this.updateElementClasses(state);

      // Push event to server if needed
      if (state === ConnectionState.CONNECTED && prevState === ConnectionState.RECONNECTING) {
        // Successfully reconnected - push event to server
        this.pushEvent("connection:restored", {
          reconnect_attempts: this.reconnectAttempt
        });
      }
    });

    this.connectionManager.on("reconnecting", ({ attempt }) => {
      this.reconnectAttempt = attempt;
      this.updateReconnectingUI(attempt);
    });

    this.connectionManager.on("error", ({ error }) => {
      console.error("[SyncForge] Connection error:", error);
    });
  },

  /**
   * Dispatch custom connection events
   */
  dispatchConnectionEvent(state) {
    const eventName = `syncforge:${state}`;
    const event = new CustomEvent(eventName, {
      detail: {
        state,
        timestamp: Date.now(),
        reconnectAttempt: this.reconnectAttempt
      },
      bubbles: true
    });

    this.el.dispatchEvent(event);
    window.dispatchEvent(event);
  },

  /**
   * Update element classes based on connection state
   */
  updateElementClasses(state) {
    // Remove all state classes
    this.el.classList.remove(
      "syncforge-connected",
      "syncforge-disconnected",
      "syncforge-connecting",
      "syncforge-reconnecting",
      "syncforge-error"
    );

    // Add current state class
    this.el.classList.add(`syncforge-${state}`);

    // Update data attribute
    this.el.dataset.connectionState = state;
  },

  /**
   * Update UI during reconnection
   */
  updateReconnectingUI(attempt) {
    // Update data attribute with attempt count
    this.el.dataset.reconnectAttempt = attempt;

    // Dispatch attempt event
    const event = new CustomEvent("syncforge:reconnect_attempt", {
      detail: {
        attempt,
        timestamp: Date.now()
      },
      bubbles: true
    });

    this.el.dispatchEvent(event);
  },

  /**
   * Handle Phoenix LiveSocket connect
   */
  handlePhxConnect() {
    this.isConnected = true;
    this.reconnectAttempt = 0;
    this.connectionManager.setState(ConnectionState.CONNECTED);
  },

  /**
   * Handle Phoenix LiveSocket disconnect
   */
  handlePhxDisconnect() {
    this.isConnected = false;
    this.connectionManager.setState(ConnectionState.RECONNECTING);
  },

  /**
   * Handle visibility change (tab focus/blur)
   */
  handleVisibilityChange() {
    if (document.visibilityState === "visible" && !this.isConnected) {
      // Tab became visible and we're disconnected - check connection
      this.checkConnectionState();
    }
  },

  /**
   * Handle browser coming online
   */
  handleOnline() {
    if (!this.isConnected) {
      // Network is back - attempt reconnection
      this.connectionManager.setState(ConnectionState.RECONNECTING);

      // Phoenix LiveSocket should auto-reconnect, but let's verify
      if (window.liveSocket && !window.liveSocket.isConnected()) {
        window.liveSocket.connect();
      }
    }
  },

  /**
   * Handle browser going offline
   */
  handleOffline() {
    this.isConnected = false;
    this.connectionManager.setState(ConnectionState.DISCONNECTED, {
      reason: "network_offline"
    });
  },

  /**
   * Check current connection state
   */
  checkConnectionState() {
    // Check if browser is online
    if (!navigator.onLine) {
      this.isConnected = false;
      this.connectionManager.setState(ConnectionState.DISCONNECTED, {
        reason: "network_offline"
      });
      return;
    }

    // Check Phoenix LiveSocket connection
    if (window.liveSocket) {
      if (window.liveSocket.isConnected()) {
        this.isConnected = true;
        this.connectionManager.setState(ConnectionState.CONNECTED);
      } else {
        this.isConnected = false;
        this.connectionManager.setState(ConnectionState.RECONNECTING);
      }
    }
  },

  /**
   * Force reconnection
   */
  forceReconnect() {
    this.reconnectAttempt = 0;

    if (window.liveSocket) {
      window.liveSocket.disconnect();
      window.liveSocket.connect();
    }
  },

  /**
   * Clean up when hook is destroyed
   */
  destroyed() {
    // Remove event listeners
    window.removeEventListener("phx:live_socket_connected", this.handlePhxConnect);
    window.removeEventListener("phx:live_socket_disconnected", this.handlePhxDisconnect);
    document.removeEventListener("visibilitychange", this.handleVisibilityChange);
    window.removeEventListener("online", this.handleOnline);
    window.removeEventListener("offline", this.handleOffline);

    // Clean up connection manager
    if (this.connectionManager) {
      this.connectionManager.destroy();
    }

    // Remove indicator
    if (this.indicator && this.indicator.parentNode) {
      this.indicator.remove();
    }
  }
};

export default ConnectionStatus;

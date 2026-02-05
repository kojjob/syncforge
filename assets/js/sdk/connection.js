/**
 * SyncForge Connection Management SDK
 *
 * Provides robust WebSocket connection handling with:
 * - Automatic reconnection with exponential backoff
 * - Connection state tracking and events
 * - Channel management with state restoration
 * - Heartbeat monitoring
 */

/**
 * Connection states
 */
export const ConnectionState = {
  DISCONNECTED: "disconnected",
  CONNECTING: "connecting",
  CONNECTED: "connected",
  RECONNECTING: "reconnecting",
  ERROR: "error"
};

/**
 * Calculate exponential backoff delay
 * @param {number} attempt - Current attempt number (0-based)
 * @param {number} baseDelay - Base delay in ms (default: 1000)
 * @param {number} maxDelay - Maximum delay in ms (default: 30000)
 * @param {number} jitter - Jitter factor 0-1 (default: 0.1)
 * @returns {number} Delay in milliseconds
 */
export function calculateBackoff(attempt, baseDelay = 1000, maxDelay = 30000, jitter = 0.1) {
  // Exponential backoff: baseDelay * 2^attempt
  const exponentialDelay = baseDelay * Math.pow(2, attempt);

  // Cap at maximum delay
  const cappedDelay = Math.min(exponentialDelay, maxDelay);

  // Add jitter to prevent thundering herd
  const jitterAmount = cappedDelay * jitter * Math.random();

  return Math.floor(cappedDelay + jitterAmount);
}

/**
 * Simple event emitter for connection events
 */
class EventEmitter {
  constructor() {
    this.listeners = new Map();
  }

  /**
   * Add event listener
   * @param {string} event - Event name
   * @param {function} callback - Callback function
   * @returns {function} Unsubscribe function
   */
  on(event, callback) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event).add(callback);

    // Return unsubscribe function
    return () => this.off(event, callback);
  }

  /**
   * Remove event listener
   * @param {string} event - Event name
   * @param {function} callback - Callback function
   */
  off(event, callback) {
    const eventListeners = this.listeners.get(event);
    if (eventListeners) {
      eventListeners.delete(callback);
    }
  }

  /**
   * Emit event to all listeners
   * @param {string} event - Event name
   * @param {*} data - Event data
   */
  emit(event, data) {
    const eventListeners = this.listeners.get(event);
    if (eventListeners) {
      for (const callback of eventListeners) {
        try {
          callback(data);
        } catch (error) {
          console.error(`Error in ${event} listener:`, error);
        }
      }
    }
  }

  /**
   * Remove all listeners
   */
  removeAllListeners() {
    this.listeners.clear();
  }
}

/**
 * ConnectionManager handles WebSocket connection lifecycle
 */
export class ConnectionManager extends EventEmitter {
  /**
   * @param {object} options - Configuration options
   * @param {number} options.baseDelay - Base reconnect delay (default: 1000ms)
   * @param {number} options.maxDelay - Max reconnect delay (default: 30000ms)
   * @param {number} options.maxAttempts - Max reconnect attempts (default: Infinity)
   * @param {number} options.heartbeatInterval - Heartbeat check interval (default: 30000ms)
   * @param {number} options.heartbeatTimeout - Heartbeat timeout (default: 10000ms)
   */
  constructor(options = {}) {
    super();

    // Configuration
    this.baseDelay = options.baseDelay || 1000;
    this.maxDelay = options.maxDelay || 30000;
    this.maxAttempts = options.maxAttempts || Infinity;
    this.heartbeatInterval = options.heartbeatInterval || 30000;
    this.heartbeatTimeout = options.heartbeatTimeout || 10000;

    // State
    this.state = ConnectionState.DISCONNECTED;
    this.socket = null;
    this.channels = new Map();
    this.reconnectAttempt = 0;
    this.reconnectTimer = null;
    this.heartbeatTimer = null;
    this.lastHeartbeat = null;

    // Bind methods
    this.handleSocketOpen = this.handleSocketOpen.bind(this);
    this.handleSocketClose = this.handleSocketClose.bind(this);
    this.handleSocketError = this.handleSocketError.bind(this);
  }

  /**
   * Get current connection state
   * @returns {string}
   */
  getState() {
    return this.state;
  }

  /**
   * Check if connected
   * @returns {boolean}
   */
  isConnected() {
    return this.state === ConnectionState.CONNECTED;
  }

  /**
   * Set connection state and emit event
   * @param {string} newState
   * @param {object} data - Additional event data
   */
  setState(newState, data = {}) {
    const prevState = this.state;
    this.state = newState;

    this.emit("stateChange", {
      state: newState,
      prevState,
      ...data
    });

    // Emit specific state events
    this.emit(newState, data);
  }

  /**
   * Connect to a Phoenix Socket
   * @param {Socket} socket - Phoenix Socket instance
   */
  connect(socket) {
    if (this.socket) {
      this.disconnect();
    }

    this.socket = socket;
    this.setState(ConnectionState.CONNECTING);

    // Attach event handlers
    this.socket.onOpen(this.handleSocketOpen);
    this.socket.onClose(this.handleSocketClose);
    this.socket.onError(this.handleSocketError);

    // Connect if not already connected
    if (!this.socket.isConnected()) {
      this.socket.connect();
    } else {
      this.handleSocketOpen();
    }
  }

  /**
   * Disconnect from socket
   */
  disconnect() {
    this.stopReconnectTimer();
    this.stopHeartbeat();

    // Leave all channels
    for (const [topic, channelInfo] of this.channels) {
      if (channelInfo.channel) {
        channelInfo.channel.leave();
      }
    }
    this.channels.clear();

    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }

    this.setState(ConnectionState.DISCONNECTED);
    this.reconnectAttempt = 0;
  }

  /**
   * Handle socket open event
   */
  handleSocketOpen() {
    this.reconnectAttempt = 0;
    this.stopReconnectTimer();
    this.setState(ConnectionState.CONNECTED);
    this.startHeartbeat();

    // Rejoin all channels
    this.rejoinChannels();
  }

  /**
   * Handle socket close event
   */
  handleSocketClose(event) {
    this.stopHeartbeat();

    const wasConnected = this.state === ConnectionState.CONNECTED;

    if (wasConnected) {
      // Only attempt reconnect if we were previously connected
      this.scheduleReconnect();
    } else {
      this.setState(ConnectionState.DISCONNECTED, { event });
    }
  }

  /**
   * Handle socket error event
   */
  handleSocketError(error) {
    this.emit("error", { error });

    if (this.state === ConnectionState.CONNECTING) {
      // Connection failed, schedule reconnect
      this.scheduleReconnect();
    }
  }

  /**
   * Schedule a reconnection attempt
   */
  scheduleReconnect() {
    if (this.reconnectAttempt >= this.maxAttempts) {
      this.setState(ConnectionState.ERROR, {
        reason: "max_attempts_reached",
        attempts: this.reconnectAttempt
      });
      return;
    }

    this.setState(ConnectionState.RECONNECTING, {
      attempt: this.reconnectAttempt + 1,
      maxAttempts: this.maxAttempts
    });

    const delay = calculateBackoff(
      this.reconnectAttempt,
      this.baseDelay,
      this.maxDelay
    );

    this.emit("reconnectScheduled", {
      attempt: this.reconnectAttempt + 1,
      delay,
      nextAttemptAt: Date.now() + delay
    });

    this.reconnectTimer = setTimeout(() => {
      this.reconnectAttempt++;

      if (this.socket) {
        this.socket.connect();
      }
    }, delay);
  }

  /**
   * Stop reconnect timer
   */
  stopReconnectTimer() {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  }

  /**
   * Start heartbeat monitoring
   */
  startHeartbeat() {
    this.lastHeartbeat = Date.now();

    this.heartbeatTimer = setInterval(() => {
      const now = Date.now();
      const timeSinceLastHeartbeat = now - this.lastHeartbeat;

      if (timeSinceLastHeartbeat > this.heartbeatInterval + this.heartbeatTimeout) {
        // Heartbeat timed out, connection may be dead
        this.emit("heartbeatTimeout", {
          lastHeartbeat: this.lastHeartbeat,
          timeout: this.heartbeatTimeout
        });

        // Force reconnect
        if (this.socket) {
          this.socket.disconnect();
        }
      }
    }, this.heartbeatInterval);
  }

  /**
   * Stop heartbeat monitoring
   */
  stopHeartbeat() {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  /**
   * Update last heartbeat time (call when receiving messages)
   */
  heartbeat() {
    this.lastHeartbeat = Date.now();
  }

  /**
   * Join a channel with automatic rejoin on reconnect
   * @param {string} topic - Channel topic
   * @param {object} params - Join parameters
   * @param {object} options - Channel options
   * @returns {Promise<object>} Channel join result
   */
  joinChannel(topic, params = {}, options = {}) {
    return new Promise((resolve, reject) => {
      if (!this.socket) {
        reject(new Error("Socket not connected"));
        return;
      }

      // Store channel info for rejoin on reconnect
      this.channels.set(topic, {
        topic,
        params,
        options,
        channel: null,
        joined: false
      });

      const channel = this.socket.channel(topic, params);
      this.channels.get(topic).channel = channel;

      // Set up message handler to update heartbeat
      channel.onMessage = (event, payload, ref) => {
        this.heartbeat();
        return payload;
      };

      channel.join()
        .receive("ok", (response) => {
          this.channels.get(topic).joined = true;
          this.emit("channelJoined", { topic, response });
          resolve({ channel, response });
        })
        .receive("error", (error) => {
          this.emit("channelError", { topic, error });
          reject(error);
        })
        .receive("timeout", () => {
          const error = new Error("Channel join timeout");
          this.emit("channelError", { topic, error });
          reject(error);
        });
    });
  }

  /**
   * Leave a channel
   * @param {string} topic - Channel topic
   */
  leaveChannel(topic) {
    const channelInfo = this.channels.get(topic);

    if (channelInfo && channelInfo.channel) {
      channelInfo.channel.leave();
      this.emit("channelLeft", { topic });
    }

    this.channels.delete(topic);
  }

  /**
   * Get a channel by topic
   * @param {string} topic
   * @returns {Channel|null}
   */
  getChannel(topic) {
    const channelInfo = this.channels.get(topic);
    return channelInfo ? channelInfo.channel : null;
  }

  /**
   * Rejoin all channels after reconnect
   */
  rejoinChannels() {
    for (const [topic, channelInfo] of this.channels) {
      if (channelInfo.channel) {
        // Channel already exists, rejoin it
        channelInfo.channel.rejoin();

        channelInfo.channel.join()
          .receive("ok", (response) => {
            channelInfo.joined = true;
            this.emit("channelRejoined", { topic, response });
          })
          .receive("error", (error) => {
            this.emit("channelRejoinError", { topic, error });
          });
      } else {
        // Create new channel instance
        const channel = this.socket.channel(channelInfo.topic, channelInfo.params);
        channelInfo.channel = channel;

        channel.join()
          .receive("ok", (response) => {
            channelInfo.joined = true;
            this.emit("channelRejoined", { topic, response });
          })
          .receive("error", (error) => {
            this.emit("channelRejoinError", { topic, error });
          });
      }
    }
  }

  /**
   * Force a reconnection attempt
   */
  forceReconnect() {
    this.reconnectAttempt = 0;

    if (this.socket) {
      this.socket.disconnect();
      this.scheduleReconnect();
    }
  }

  /**
   * Destroy the connection manager
   */
  destroy() {
    this.disconnect();
    this.removeAllListeners();
  }
}

/**
 * Create a connection status indicator element
 * @param {ConnectionManager} manager
 * @returns {HTMLElement}
 */
export function createConnectionIndicator(manager) {
  const indicator = document.createElement("div");
  indicator.className = "syncforge-connection-indicator";
  indicator.style.cssText = `
    position: fixed;
    bottom: 16px;
    right: 16px;
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 12px;
    background: rgba(0, 0, 0, 0.8);
    color: white;
    font-size: 12px;
    font-weight: 500;
    border-radius: 8px;
    z-index: 10000;
    transition: opacity 0.3s ease, transform 0.3s ease;
    pointer-events: none;
  `;

  const dot = document.createElement("div");
  dot.className = "syncforge-connection-dot";
  dot.style.cssText = `
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #10B981;
    transition: background 0.3s ease;
  `;

  const text = document.createElement("span");
  text.className = "syncforge-connection-text";
  text.textContent = "Connected";

  indicator.appendChild(dot);
  indicator.appendChild(text);

  // Update indicator based on connection state
  const updateIndicator = ({ state }) => {
    switch (state) {
      case ConnectionState.CONNECTED:
        dot.style.background = "#10B981"; // Green
        text.textContent = "Connected";
        indicator.style.opacity = "0";
        indicator.style.transform = "translateY(20px)";
        break;

      case ConnectionState.CONNECTING:
        dot.style.background = "#F59E0B"; // Yellow
        text.textContent = "Connecting...";
        indicator.style.opacity = "1";
        indicator.style.transform = "translateY(0)";
        break;

      case ConnectionState.RECONNECTING:
        dot.style.background = "#F59E0B"; // Yellow
        dot.style.animation = "pulse 1s infinite";
        text.textContent = "Reconnecting...";
        indicator.style.opacity = "1";
        indicator.style.transform = "translateY(0)";
        break;

      case ConnectionState.DISCONNECTED:
        dot.style.background = "#6B7280"; // Gray
        text.textContent = "Disconnected";
        indicator.style.opacity = "1";
        indicator.style.transform = "translateY(0)";
        break;

      case ConnectionState.ERROR:
        dot.style.background = "#EF4444"; // Red
        text.textContent = "Connection Error";
        indicator.style.opacity = "1";
        indicator.style.transform = "translateY(0)";
        break;
    }
  };

  manager.on("stateChange", updateIndicator);

  // Set initial state
  updateIndicator({ state: manager.getState() });

  // Add pulse animation style
  const style = document.createElement("style");
  style.textContent = `
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }
  `;
  document.head.appendChild(style);

  return indicator;
}

export default ConnectionManager;

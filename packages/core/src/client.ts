/**
 * SyncForgeClient — main entry point for the SDK.
 *
 * Wraps a Phoenix Socket and manages the connection lifecycle.
 * Use `.joinRoom(roomId)` to get a Room instance.
 */

import type { Socket as PhoenixSocket } from "phoenix";
import { TypedEventEmitter } from "./events.js";
import type {
  ClientEventMap,
  ClientOptions,
  ConnectionState,
  JoinRoomOptions,
} from "./types.js";

export class SyncForgeClient extends TypedEventEmitter<ClientEventMap> {
  private _socket: PhoenixSocket | null = null;
  private _state: ConnectionState = "disconnected";
  private _options: ClientOptions;
  private _reconnectAttempt = 0;

  constructor(options: ClientOptions) {
    super();
    this._options = {
      reconnect: true,
      ...options,
    };
  }

  /** Current connection state */
  get state(): ConnectionState {
    return this._state;
  }

  /** The underlying Phoenix Socket (null if not connected) */
  get socket(): PhoenixSocket | null {
    return this._socket;
  }

  /**
   * Connect to the SyncForge server.
   *
   * Dynamically imports `phoenix` (peer dependency) and opens a WebSocket.
   * Returns `this` for chaining.
   */
  async connect(): Promise<SyncForgeClient> {
    if (this._state === "connected" || this._state === "connecting") {
      return this;
    }

    this._setState("connecting");

    try {
      // Dynamic import — phoenix is a peer dependency
      const { Socket } = await import("phoenix");

      const socketParams = {
        token: this._options.token,
        ...this._options.params,
      };

      this._socket = new Socket(this._options.endpoint, {
        params: socketParams,
        logger: this._options.logger,
      }) as PhoenixSocket;

      this._setupSocketCallbacks();
      this._socket.connect();

      return this;
    } catch (err) {
      this._setState("errored");
      this.emit("error", {
        message: err instanceof Error ? err.message : "Failed to connect",
      });
      throw err;
    }
  }

  /** Disconnect from the server and clean up all channels. */
  disconnect(): void {
    if (this._socket) {
      this._socket.disconnect();
      this._socket = null;
    }
    this._setState("disconnected");
    this.emit("disconnected", { reason: "manual" });
    this.removeAllListeners();
  }

  /**
   * Join a collaboration room.
   *
   * Returns a Room instance that wraps a Phoenix Channel.
   * The Room is lazy — it joins the channel but feature managers
   * are initialized on demand.
   */
  joinRoom(roomId: string, options?: JoinRoomOptions): JoinRoomResult {
    if (!this._socket) {
      throw new Error(
        "SyncForgeClient is not connected. Call connect() first."
      );
    }

    const topic = `room:${roomId}`;
    const channel = this._socket.channel(topic, options?.params ?? {});

    return { channel, roomId };
  }

  /**
   * Join the notification channel for the current user.
   *
   * Returns the raw Phoenix Channel for NotificationManager to wrap.
   */
  joinNotifications(userId: string): JoinNotificationResult {
    if (!this._socket) {
      throw new Error(
        "SyncForgeClient is not connected. Call connect() first."
      );
    }

    const topic = `notification:${userId}`;
    const channel = this._socket.channel(topic, {});

    return { channel, userId };
  }

  private _setupSocketCallbacks(): void {
    if (!this._socket) return;

    this._socket.onOpen(() => {
      this._reconnectAttempt = 0;
      this._setState("connected");
      this.emit("connected");
    });

    this._socket.onClose(() => {
      this._setState("disconnected");
      this.emit("disconnected", { reason: "closed" });
    });

    this._socket.onError(() => {
      this._setState("errored");
      this.emit("error", { message: "Socket error" });
    });
  }

  private _setState(state: ConnectionState): void {
    this._state = state;
  }
}

/** Result of joinRoom — consumed by Room class in room.ts */
export interface JoinRoomResult {
  channel: ReturnType<PhoenixSocket["channel"]>;
  roomId: string;
}

/** Result of joinNotifications — consumed by NotificationManager */
export interface JoinNotificationResult {
  channel: ReturnType<PhoenixSocket["channel"]>;
  userId: string;
}

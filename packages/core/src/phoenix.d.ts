/**
 * Type declarations for the `phoenix` package (peer dependency).
 * The npm phoenix package doesn't ship its own .d.ts files.
 */

declare module "phoenix" {
  export interface SocketOptions {
    params?: Record<string, unknown> | (() => Record<string, unknown>);
    logger?: (kind: string, msg: string, data?: unknown) => void;
    transport?: unknown;
    heartbeatIntervalMs?: number;
    reconnectAfterMs?: (tries: number) => number;
    timeout?: number;
    longpollerTimeout?: number;
    binaryType?: string;
    vsn?: string;
  }

  export interface Push {
    receive(status: string, callback: (response: unknown) => void): Push;
  }

  export class Channel {
    topic: string;
    params: Record<string, unknown>;
    state: string;
    join(timeout?: number): Push;
    leave(timeout?: number): Push;
    push(event: string, payload?: unknown, timeout?: number): Push;
    on(event: string, callback: (payload: unknown) => void): number;
    off(event: string, ref?: number): void;
    onClose(callback: () => void): void;
    onError(callback: (reason?: unknown) => void): void;
  }

  export class Socket {
    constructor(endPoint: string, opts?: SocketOptions);
    connect(): void;
    disconnect(callback?: () => void, code?: number, reason?: string): void;
    channel(topic: string, params?: Record<string, unknown>): Channel;
    onOpen(callback: () => void): void;
    onClose(callback: () => void): void;
    onError(callback: (error: unknown) => void): void;
    isConnected(): boolean;
  }

  export class Presence {
    constructor(channel: Channel);
    onSync(callback: () => void): void;
    onJoin(
      callback: (
        id: string,
        current: { metas: Record<string, unknown>[] } | undefined,
        newPres: { metas: Record<string, unknown>[] }
      ) => void
    ): void;
    onLeave(
      callback: (
        id: string,
        current: { metas: Record<string, unknown>[] } | undefined,
        leftPres: { metas: Record<string, unknown>[] }
      ) => void
    ): void;
    list<T>(
      chooser?: (
        id: string,
        presence: { metas: Record<string, unknown>[] }
      ) => T
    ): T[];
  }
}

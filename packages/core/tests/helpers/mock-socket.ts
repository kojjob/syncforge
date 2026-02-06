/**
 * Mock implementations of Phoenix Socket, Channel, and Presence
 * for unit testing without a real server connection.
 */

type PushCallback = (response: Record<string, unknown>) => void;
type EventHandler = (...args: unknown[]) => void;

export class MockPush {
  private _okCb: PushCallback | null = null;
  private _errorCb: PushCallback | null = null;
  private _timeoutCb: (() => void) | null = null;

  receive(status: string, cb: PushCallback): MockPush {
    if (status === "ok") this._okCb = cb;
    if (status === "error") this._errorCb = cb;
    if (status === "timeout") this._timeoutCb = cb as unknown as () => void;
    return this;
  }

  /** Simulate a successful server response */
  triggerOk(response: Record<string, unknown> = {}): void {
    this._okCb?.(response);
  }

  /** Simulate an error server response */
  triggerError(response: Record<string, unknown> = {}): void {
    this._errorCb?.(response);
  }

  /** Simulate a timeout */
  triggerTimeout(): void {
    this._timeoutCb?.();
  }
}

export class MockChannel {
  topic: string;
  params: Record<string, unknown>;
  private _handlers = new Map<string, EventHandler[]>();
  private _joinPush = new MockPush();
  state: string = "closed";

  /** Track all pushed events for assertions */
  pushLog: Array<{ event: string; payload: unknown }> = [];

  constructor(topic: string, params: Record<string, unknown> = {}) {
    this.topic = topic;
    this.params = params;
  }

  join(): MockPush {
    this.state = "joined";
    return this._joinPush;
  }

  leave(): MockPush {
    this.state = "closed";
    return new MockPush();
  }

  push(event: string, payload: unknown = {}): MockPush {
    this.pushLog.push({ event, payload });
    return new MockPush();
  }

  on(event: string, handler: EventHandler): number {
    const handlers = this._handlers.get(event) || [];
    handlers.push(handler);
    this._handlers.set(event, handlers);
    return handlers.length - 1;
  }

  off(event: string, _ref?: number): void {
    if (_ref !== undefined) {
      const handlers = this._handlers.get(event);
      if (handlers) handlers.splice(_ref, 1);
    } else {
      this._handlers.delete(event);
    }
  }

  /** Simulate the server pushing an event to the client */
  simulateEvent(event: string, payload: unknown): void {
    const handlers = this._handlers.get(event) || [];
    for (const handler of handlers) {
      handler(payload);
    }
  }

  /** Trigger the join push ok callback */
  simulateJoinOk(response: Record<string, unknown> = {}): void {
    this._joinPush.triggerOk(response);
  }

  /** Trigger the join push error callback */
  simulateJoinError(response: Record<string, unknown> = {}): void {
    this._joinPush.triggerError(response);
  }
}

export class MockPresence {
  private _state: Record<string, { metas: Record<string, unknown>[] }> = {};
  private _syncCb: (() => void) | null = null;
  private _joinCb: ((id: string, current: unknown, newPres: unknown) => void) | null = null;
  private _leaveCb: ((id: string, current: unknown, leftPres: unknown) => void) | null = null;

  constructor(_channel: MockChannel) {
    // In real Phoenix, Presence listens on the channel for presence_state/presence_diff
  }

  onSync(cb: () => void): void {
    this._syncCb = cb;
  }

  onJoin(cb: (id: string, current: unknown, newPres: unknown) => void): void {
    this._joinCb = cb;
  }

  onLeave(cb: (id: string, current: unknown, leftPres: unknown) => void): void {
    this._leaveCb = cb;
  }

  list(
    chooser?: (id: string, presence: { metas: Record<string, unknown>[] }) => unknown
  ): unknown[] {
    return Object.entries(this._state).map(([id, presence]) =>
      chooser ? chooser(id, presence) : presence
    );
  }

  /** Simulate presence state sync */
  simulateSync(
    state: Record<string, { metas: Record<string, unknown>[] }>
  ): void {
    this._state = state;
    this._syncCb?.();
  }

  /** Simulate a user joining */
  simulateJoin(
    id: string,
    current: unknown,
    newPres: { metas: Record<string, unknown>[] }
  ): void {
    this._state[id] = newPres;
    this._joinCb?.(id, current, newPres);
    this._syncCb?.();
  }

  /** Simulate a user leaving */
  simulateLeave(
    id: string,
    current: unknown,
    leftPres: unknown
  ): void {
    delete this._state[id];
    this._leaveCb?.(id, current, leftPres);
    this._syncCb?.();
  }
}

export class MockSocket {
  endpoint: string;
  params: Record<string, unknown>;
  private _channels = new Map<string, MockChannel>();
  private _onOpenCb: (() => void) | null = null;
  private _onCloseCb: (() => void) | null = null;
  private _onErrorCb: ((err: unknown) => void) | null = null;
  private _connected = false;

  constructor(endpoint: string, opts: { params?: Record<string, unknown>; logger?: unknown } = {}) {
    this.endpoint = endpoint;
    this.params = opts.params ?? {};
  }

  connect(): void {
    this._connected = true;
    // Trigger onOpen asynchronously to match real Phoenix behavior
    setTimeout(() => this._onOpenCb?.(), 0);
  }

  disconnect(): void {
    this._connected = false;
    this._onCloseCb?.();
  }

  channel(topic: string, params: Record<string, unknown> = {}): MockChannel {
    const ch = new MockChannel(topic, params);
    this._channels.set(topic, ch);
    return ch;
  }

  onOpen(cb: () => void): void {
    this._onOpenCb = cb;
    // If already connected, fire immediately
    if (this._connected) setTimeout(() => cb(), 0);
  }

  onClose(cb: () => void): void {
    this._onCloseCb = cb;
  }

  onError(cb: (err: unknown) => void): void {
    this._onErrorCb = cb;
  }

  /** Test helper: simulate socket error */
  simulateError(err?: unknown): void {
    this._onErrorCb?.(err);
  }

  /** Test helper: simulate socket close */
  simulateClose(): void {
    this._connected = false;
    this._onCloseCb?.();
  }

  /** Get a channel that was created via .channel() */
  getChannel(topic: string): MockChannel | undefined {
    return this._channels.get(topic);
  }

  get isConnected(): boolean {
    return this._connected;
  }
}

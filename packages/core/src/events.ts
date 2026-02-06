/**
 * Strongly-typed event emitter.
 *
 * Generic parameter `Events` maps event names to their payload types.
 * Provides compile-time safety for all subscribe/emit calls.
 */

type Listener<T> = (payload: T) => void;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export class TypedEventEmitter<Events extends Record<string, any>> {
  private _listeners = new Map<keyof Events, Set<Listener<never>>>();

  on<E extends keyof Events>(event: E, listener: Listener<Events[E]>): () => void {
    if (!this._listeners.has(event)) {
      this._listeners.set(event, new Set());
    }
    const set = this._listeners.get(event)!;
    set.add(listener as Listener<never>);

    // Return unsubscribe function
    return () => {
      set.delete(listener as Listener<never>);
      if (set.size === 0) this._listeners.delete(event);
    };
  }

  once<E extends keyof Events>(event: E, listener: Listener<Events[E]>): () => void {
    const unsubscribe = this.on(event, ((payload: Events[E]) => {
      unsubscribe();
      listener(payload);
    }) as Listener<Events[E]>);
    return unsubscribe;
  }

  off<E extends keyof Events>(event: E, listener?: Listener<Events[E]>): void {
    if (!listener) {
      this._listeners.delete(event);
      return;
    }
    const set = this._listeners.get(event);
    if (set) {
      set.delete(listener as Listener<never>);
      if (set.size === 0) this._listeners.delete(event);
    }
  }

  protected emit<E extends keyof Events>(
    event: E,
    ...args: Events[E] extends undefined ? [] : [Events[E]]
  ): void {
    const set = this._listeners.get(event);
    if (!set) return;
    for (const listener of set) {
      (listener as Listener<Events[E]>)(args[0] as Events[E]);
    }
  }

  removeAllListeners(): void {
    this._listeners.clear();
  }

  listenerCount<E extends keyof Events>(event: E): number {
    return this._listeners.get(event)?.size ?? 0;
  }
}

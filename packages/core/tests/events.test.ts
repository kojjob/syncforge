import { describe, it, expect, vi } from "vitest";
import { TypedEventEmitter } from "../src/events.js";

// Define a test event map
interface TestEvents {
  greet: { name: string };
  count: { value: number };
  done: undefined;
}

function createEmitter() {
  // Expose emit for testing by extending
  class TestEmitter extends TypedEventEmitter<TestEvents> {
    public fire<E extends keyof TestEvents>(
      event: E,
      ...args: TestEvents[E] extends undefined ? [] : [TestEvents[E]]
    ) {
      this.emit(event, ...args);
    }
  }
  return new TestEmitter();
}

describe("TypedEventEmitter", () => {
  it("calls listeners when event is emitted", () => {
    const emitter = createEmitter();
    const listener = vi.fn();

    emitter.on("greet", listener);
    emitter.fire("greet", { name: "Alice" });

    expect(listener).toHaveBeenCalledWith({ name: "Alice" });
    expect(listener).toHaveBeenCalledTimes(1);
  });

  it("supports multiple listeners for the same event", () => {
    const emitter = createEmitter();
    const listener1 = vi.fn();
    const listener2 = vi.fn();

    emitter.on("greet", listener1);
    emitter.on("greet", listener2);
    emitter.fire("greet", { name: "Bob" });

    expect(listener1).toHaveBeenCalledOnce();
    expect(listener2).toHaveBeenCalledOnce();
  });

  it("returns an unsubscribe function from on()", () => {
    const emitter = createEmitter();
    const listener = vi.fn();

    const unsub = emitter.on("greet", listener);
    unsub();
    emitter.fire("greet", { name: "Charlie" });

    expect(listener).not.toHaveBeenCalled();
  });

  it("once() fires the listener only once", () => {
    const emitter = createEmitter();
    const listener = vi.fn();

    emitter.once("count", listener);
    emitter.fire("count", { value: 1 });
    emitter.fire("count", { value: 2 });

    expect(listener).toHaveBeenCalledOnce();
    expect(listener).toHaveBeenCalledWith({ value: 1 });
  });

  it("once() returns an unsubscribe function that works before emit", () => {
    const emitter = createEmitter();
    const listener = vi.fn();

    const unsub = emitter.once("count", listener);
    unsub();
    emitter.fire("count", { value: 99 });

    expect(listener).not.toHaveBeenCalled();
  });

  it("off() with specific listener removes only that listener", () => {
    const emitter = createEmitter();
    const listener1 = vi.fn();
    const listener2 = vi.fn();

    emitter.on("greet", listener1);
    emitter.on("greet", listener2);
    emitter.off("greet", listener1);
    emitter.fire("greet", { name: "Diana" });

    expect(listener1).not.toHaveBeenCalled();
    expect(listener2).toHaveBeenCalledOnce();
  });

  it("off() without listener removes all listeners for event", () => {
    const emitter = createEmitter();
    const listener1 = vi.fn();
    const listener2 = vi.fn();

    emitter.on("greet", listener1);
    emitter.on("greet", listener2);
    emitter.off("greet");
    emitter.fire("greet", { name: "Eve" });

    expect(listener1).not.toHaveBeenCalled();
    expect(listener2).not.toHaveBeenCalled();
  });

  it("removeAllListeners() clears everything", () => {
    const emitter = createEmitter();
    const greetListener = vi.fn();
    const countListener = vi.fn();

    emitter.on("greet", greetListener);
    emitter.on("count", countListener);
    emitter.removeAllListeners();
    emitter.fire("greet", { name: "Frank" });
    emitter.fire("count", { value: 42 });

    expect(greetListener).not.toHaveBeenCalled();
    expect(countListener).not.toHaveBeenCalled();
  });

  it("listenerCount() returns correct count", () => {
    const emitter = createEmitter();

    expect(emitter.listenerCount("greet")).toBe(0);

    emitter.on("greet", () => {});
    expect(emitter.listenerCount("greet")).toBe(1);

    emitter.on("greet", () => {});
    expect(emitter.listenerCount("greet")).toBe(2);
  });

  it("handles events with undefined payload", () => {
    const emitter = createEmitter();
    const listener = vi.fn();

    emitter.on("done", listener);
    emitter.fire("done");

    expect(listener).toHaveBeenCalledOnce();
  });

  it("does not throw when emitting with no listeners", () => {
    const emitter = createEmitter();
    expect(() => emitter.fire("greet", { name: "Ghost" })).not.toThrow();
  });
});

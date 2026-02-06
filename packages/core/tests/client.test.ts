import { describe, it, expect, vi, beforeEach } from "vitest";
import { MockSocket } from "./helpers/mock-socket.js";

// We test the SyncForgeClient by mocking the phoenix import
// Since client.ts uses dynamic import("phoenix"), we mock the module
vi.mock("phoenix", () => ({
  Socket: MockSocket,
}));

import { SyncForgeClient } from "../src/client.js";

describe("SyncForgeClient", () => {
  let client: SyncForgeClient;

  beforeEach(() => {
    client = new SyncForgeClient({
      endpoint: "ws://localhost:4000/socket",
      token: "test-token-123",
    });
  });

  describe("constructor", () => {
    it("initializes with disconnected state", () => {
      expect(client.state).toBe("disconnected");
    });

    it("has null socket before connect", () => {
      expect(client.socket).toBeNull();
    });
  });

  describe("connect()", () => {
    it("transitions to connecting then connected state", async () => {
      const states: string[] = [];
      const connectedPromise = new Promise<void>((resolve) => {
        client.on("connected", () => {
          states.push(client.state);
          resolve();
        });
      });

      await client.connect();

      // After connect() returns, socket exists
      expect(client.socket).not.toBeNull();

      // Wait for the async onOpen callback
      await connectedPromise;
      expect(states).toContain("connected");
    });

    it("does not reconnect if already connected", async () => {
      await client.connect();
      const socket1 = client.socket;

      // Wait for connection
      await new Promise((r) => setTimeout(r, 10));

      await client.connect();
      const socket2 = client.socket;

      // Should be same socket instance
      expect(socket1).toBe(socket2);
    });

    it("passes token in socket params", async () => {
      await client.connect();
      const socket = client.socket as unknown as MockSocket;
      expect(socket.params).toEqual(
        expect.objectContaining({ token: "test-token-123" })
      );
    });

    it("passes additional params to socket", async () => {
      const customClient = new SyncForgeClient({
        endpoint: "ws://localhost:4000/socket",
        token: "tok",
        params: { org_id: "org-1" },
      });
      await customClient.connect();
      const socket = customClient.socket as unknown as MockSocket;
      expect(socket.params).toEqual(
        expect.objectContaining({ token: "tok", org_id: "org-1" })
      );
    });
  });

  describe("disconnect()", () => {
    it("sets state to disconnected", async () => {
      await client.connect();
      client.disconnect();
      expect(client.state).toBe("disconnected");
      expect(client.socket).toBeNull();
    });

    it("emits disconnected event", async () => {
      const listener = vi.fn();
      await client.connect();
      client.on("disconnected", listener);
      client.disconnect();
      expect(listener).toHaveBeenCalledWith({ reason: "manual" });
    });
  });

  describe("joinRoom()", () => {
    it("throws if not connected", () => {
      expect(() => client.joinRoom("room-1")).toThrow(
        "SyncForgeClient is not connected"
      );
    });

    it("creates a channel with correct topic", async () => {
      await client.connect();
      const result = client.joinRoom("room-uuid-123");
      expect(result.roomId).toBe("room-uuid-123");
      expect(result.channel).toBeDefined();
    });

    it("passes join params to channel", async () => {
      await client.connect();
      const result = client.joinRoom("room-1", {
        params: { role: "editor" },
      });
      expect(result.channel.params).toEqual({ role: "editor" });
    });
  });

  describe("joinNotifications()", () => {
    it("throws if not connected", () => {
      expect(() => client.joinNotifications("user-1")).toThrow(
        "SyncForgeClient is not connected"
      );
    });

    it("creates a channel with correct topic", async () => {
      await client.connect();
      const result = client.joinNotifications("user-uuid-456");
      expect(result.userId).toBe("user-uuid-456");
      expect(result.channel).toBeDefined();
    });
  });

  describe("socket error handling", () => {
    it("emits error event on socket error", async () => {
      const errorListener = vi.fn();
      client.on("error", errorListener);

      await client.connect();
      const socket = client.socket as unknown as MockSocket;
      socket.simulateError(new Error("Connection refused"));

      expect(errorListener).toHaveBeenCalledWith({ message: "Socket error" });
      expect(client.state).toBe("errored");
    });

    it("emits disconnected on socket close", async () => {
      const disconnectListener = vi.fn();
      await client.connect();
      client.on("disconnected", disconnectListener);

      const socket = client.socket as unknown as MockSocket;
      socket.simulateClose();

      expect(disconnectListener).toHaveBeenCalledWith({ reason: "closed" });
      expect(client.state).toBe("disconnected");
    });
  });
});

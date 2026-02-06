/**
 * SyncForgeProvider — React context for the SyncForge client.
 *
 * Manages the client lifecycle (connect on mount, disconnect on unmount)
 * and provides the client instance to all child hooks.
 */

import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import {
  SyncForgeClient,
  type ClientOptions,
  type ConnectionState,
} from "@syncforge/core";

interface SyncForgeContextValue {
  client: SyncForgeClient | null;
  connectionState: ConnectionState;
}

const SyncForgeContext = createContext<SyncForgeContextValue>({
  client: null,
  connectionState: "disconnected",
});

export interface SyncForgeProviderProps {
  children: ReactNode;
  /** Client connection options (endpoint, token, etc.) */
  options: ClientOptions;
  /** If false, don't auto-connect on mount (default: true) */
  autoConnect?: boolean;
}

export function SyncForgeProvider({
  children,
  options,
  autoConnect = true,
}: SyncForgeProviderProps) {
  const clientRef = useRef<SyncForgeClient | null>(null);
  const [connectionState, setConnectionState] =
    useState<ConnectionState>("disconnected");

  useEffect(() => {
    const client = new SyncForgeClient(options);
    clientRef.current = client;

    client.on("connected", () => setConnectionState("connected"));
    client.on("disconnected", () => setConnectionState("disconnected"));
    client.on("error", () => setConnectionState("errored"));

    if (autoConnect) {
      client.connect().catch(() => {
        // Error already emitted via event
      });
      setConnectionState("connecting");
    }

    return () => {
      client.disconnect();
      clientRef.current = null;
    };
    // Re-create client only when endpoint or token changes
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [options.endpoint, options.token, autoConnect]);

  return (
    <SyncForgeContext.Provider
      value={{ client: clientRef.current, connectionState }}
    >
      {children}
    </SyncForgeContext.Provider>
  );
}

/**
 * Access the SyncForge client from any child component.
 * Throws if used outside a SyncForgeProvider.
 */
export function useSyncForge(): SyncForgeContextValue {
  const ctx = useContext(SyncForgeContext);
  if (ctx.client === null && ctx.connectionState !== "disconnected") {
    throw new Error("useSyncForge must be used within a <SyncForgeProvider>");
  }
  return ctx;
}

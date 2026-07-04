import type { CoreBridge } from "./types";

export interface HttpBridgeOptions {
  /** Base URL of the core's HTTP endpoints (default "": same origin). */
  baseUrl?: string;
}

/**
 * createHttpBridge talks to a Go core exposed over HTTP + SSE (see
 * apps/desktop/bridge_handler.go):
 *
 *   POST <base>/invoke  {method, payload} -> JSON result
 *   GET  <base>/events                    -> Server-Sent Events
 *
 * This is the desktop binding: the Wails process imports core/ directly and mounts
 * these endpoints on its asset server, so the webview UI reaches the in-process core
 * with plain fetch/EventSource — the same CoreBridge the wasm shell implements.
 */
export function createHttpBridge(opts: HttpBridgeOptions = {}): CoreBridge {
  const base = opts.baseUrl ?? "";

  // One EventSource, fanned out to per-event listener sets registered via on().
  const source = new EventSource(`${base}/events`);
  const listeners = new Map<string, Set<(payload: unknown) => void>>();

  return {
    async invoke<T>(method: string, payload?: unknown): Promise<T> {
      const res = await fetch(`${base}/invoke`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ method, payload: payload ?? null }),
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error((data && data.error) || res.statusText);
      }
      return data as T;
    },

    on(event, cb) {
      let set = listeners.get(event);
      if (!set) {
        set = new Set();
        listeners.set(event, set);
        source.addEventListener(event, (e: MessageEvent) => {
          let payload: unknown = null;
          try {
            payload = e.data ? JSON.parse(e.data) : null;
          } catch {
            payload = e.data;
          }
          for (const fn of listeners.get(event) ?? []) fn(payload);
        });
      }
      set.add(cb);
      return () => {
        set!.delete(cb);
      };
    },

    close() {
      source.close();
    },
  };
}

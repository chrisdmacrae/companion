// The one CoreBridge API shape every platform implements (PLAN §3.1). UI code never
// calls invoke with raw strings — it goes through the typed helpers in ./notes.

/** CoreBridge is the universal handle to the Go core. */
export interface CoreBridge {
  /** Dispatch a core method; payload and result are JSON-serializable. */
  invoke<T>(method: string, payload?: unknown): Promise<T>;
  /** Subscribe to a core event (e.g. "notes.changed"); returns an unsubscribe fn. */
  on(event: string, cb: (payload: unknown) => void): () => void;
  /** Release the underlying core/store. */
  close(): void;
}

/** A value that can cross the SQLite bind/column boundary. */
export type SqlValue = string | number | Uint8Array | null;

/**
 * SqliteDriver is the JS-side SQLite implementation the wasm core drives through the
 * store.Driver seam (PLAN §3.2). Every method is async (awaited from Go).
 */
export interface SqliteDriver {
  exec(sql: string, params: SqlValue[]): Promise<{ rowsAffected: number }>;
  query(sql: string, params: SqlValue[]): Promise<{ rows: SqlValue[][] }>;
  close(): Promise<void>;
}

/** A note as returned by the core (mirrors core/domain.Note). */
export interface Note {
  id: string;
  title: string;
  contentMd: string;
  date?: string | null;
  createdAt: string;
  updatedAt: string;
  deletedAt?: string | null;
  version: number;
  dirty: boolean;
}

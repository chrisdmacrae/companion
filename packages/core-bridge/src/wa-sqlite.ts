/// <reference path="./wa-sqlite-shims.d.ts" />
import * as SQLite from "wa-sqlite";
import SQLiteAsyncFactory from "wa-sqlite/dist/wa-sqlite-async.mjs";
import { IDBBatchAtomicVFS } from "wa-sqlite/src/examples/IDBBatchAtomicVFS.js";

import type { SqliteDriver, SqlValue } from "./types";

export interface WaSqliteOptions {
  /** IndexedDB database + SQLite file name (default "companion"). */
  dbName?: string;
}

/**
 * createWaSqliteDriver builds the browser SQLite backend for the wasm core.
 *
 * It uses wa-sqlite's IndexedDB VFS (IDBBatchAtomicVFS): persistent across reloads,
 * runs on the main thread, and needs no cross-origin-isolation headers. OPFS
 * (PLAN §3.2/§10) is the documented upgrade — it is faster but requires a dedicated
 * worker + COOP/COEP headers, which this driver deliberately avoids for milestone 2.
 */
export async function createWaSqliteDriver(opts: WaSqliteOptions = {}): Promise<SqliteDriver> {
  const dbName = opts.dbName ?? "companion";
  const module = await SQLiteAsyncFactory();
  const sqlite3 = SQLite.Factory(module);
  const vfs = new IDBBatchAtomicVFS(dbName);
  sqlite3.vfs_register(vfs, true);
  const db = await sqlite3.open_v2(`${dbName}.db`);

  // wa-sqlite (Asyncify) is NOT reentrant: a second call while another is suspended
  // mid-await corrupts the wasm stack. The Go core dispatches each Invoke on its own
  // goroutine, so concurrent invokes (e.g. a mutation plus the notes.changed refresh)
  // can interleave here. Serialize every SQLite operation through a promise chain.
  let tail: Promise<unknown> = Promise.resolve();
  function serialize<T>(op: () => Promise<T>): Promise<T> {
    const result = tail.then(op, op);
    tail = result.catch(() => undefined);
    return result;
  }

  // run prepares each statement in sql (migrations are multi-statement), binds the
  // positional params to the single statement when present, and steps to completion.
  async function run(sql: string, params: SqlValue[], collect: boolean): Promise<SqlValue[][]> {
    const rows: SqlValue[][] = [];
    for await (const stmt of sqlite3.statements(db, sql)) {
      if (params.length) sqlite3.bind_collection(stmt, params);
      while ((await sqlite3.step(stmt)) === SQLite.SQLITE_ROW) {
        if (collect) rows.push(sqlite3.row(stmt) as SqlValue[]);
      }
    }
    return rows;
  }

  // Use an in-memory rollback journal. The IndexedDB VFS's on-disk journal open
  // path (opening "<db>-journal" without CREATE for hot-journal checks) is
  // unreliable; an in-memory journal avoids it and is faster for this workload.
  await run("PRAGMA journal_mode=MEMORY;", [], false);

  return {
    exec: (sql, params) =>
      serialize(async () => {
        await run(sql, params, false);
        return { rowsAffected: sqlite3.changes(db) };
      }),
    query: (sql, params) => serialize(async () => ({ rows: await run(sql, params, true) })),
    close: () =>
      serialize(async () => {
        await sqlite3.close(db);
        await vfs.close();
      }),
  };
}

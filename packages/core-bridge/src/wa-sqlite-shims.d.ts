// wa-sqlite 1.0.0 ships types for the main "wa-sqlite" entry (SQLiteAPI), but not for
// the Emscripten factory build or the example VFS classes; declare those loosely.

declare module "wa-sqlite/dist/wa-sqlite-async.mjs" {
  const factory: () => Promise<unknown>;
  export default factory;
}

declare module "wa-sqlite/src/examples/IDBBatchAtomicVFS.js" {
  // Typed loosely so it satisfies SQLiteAPI.vfs_register (which wants an SQLiteVFS).
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  export const IDBBatchAtomicVFS: any;
}

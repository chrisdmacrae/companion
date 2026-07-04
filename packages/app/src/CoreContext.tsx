import { createContext, useContext, useMemo, type ReactNode } from "react";
import { notesApi, type CoreBridge, type NotesApi } from "@companion/core-bridge";

interface CoreValue {
  core: CoreBridge;
  notes: NotesApi;
}

const CoreCtx = createContext<CoreValue | null>(null);

/** CoreProvider makes a platform-supplied CoreBridge available to the UI tree. */
export function CoreProvider({ core, children }: { core: CoreBridge; children: ReactNode }) {
  const value = useMemo<CoreValue>(() => ({ core, notes: notesApi(core) }), [core]);
  return <CoreCtx.Provider value={value}>{children}</CoreCtx.Provider>;
}

export function useCore(): CoreValue {
  const v = useContext(CoreCtx);
  if (!v) throw new Error("useCore must be used within a CoreProvider");
  return v;
}

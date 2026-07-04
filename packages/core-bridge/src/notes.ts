import type { CoreBridge, Note } from "./types";

export interface CreateNoteInput {
  title: string;
  contentMd?: string;
  date?: string | null;
}

export interface UpdateNoteInput {
  title?: string;
  contentMd?: string;
  date?: string | null;
}

/** Typed wrappers over the notes.* core methods. */
export function notesApi(core: CoreBridge) {
  return {
    list: () => core.invoke<Note[]>("notes.list"),
    get: (id: string) => core.invoke<Note>("notes.get", { id }),
    create: (input: CreateNoteInput) => core.invoke<Note>("notes.create", input),
    update: (id: string, fields: UpdateNoteInput) =>
      core.invoke<Note>("notes.update", { id, ...fields }),
    remove: (id: string) => core.invoke<{ ok: boolean }>("notes.delete", { id }),
  };
}

export type NotesApi = ReturnType<typeof notesApi>;

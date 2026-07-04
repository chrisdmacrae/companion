// Focus mode: a single note rendered without the app chrome (rail/toolbar), routed
// by a URL query param so it can live in its own tab or window.

export const FOCUS_PARAM = "note";

/** The note id to show in focus mode, if the current URL requests one. */
export function focusNoteId(): string | null {
  if (typeof window === "undefined") return null;
  return new URLSearchParams(window.location.search).get(FOCUS_PARAM);
}

/** The focus-mode URL for a note (same document, `?note=<id>`). */
export function focusUrl(id: string): string {
  const base = typeof window !== "undefined" ? window.location.pathname : "/";
  return `${base}?${FOCUS_PARAM}=${encodeURIComponent(id)}`;
}

/** Open a note in its own window/tab in focus mode. On web this is a new browser
 * tab; in the desktop webview it opens a new window. */
export function openNoteWindow(id: string): void {
  if (typeof window === "undefined") return;
  window.open(focusUrl(id), "_blank", "noopener,width=820,height=720");
}

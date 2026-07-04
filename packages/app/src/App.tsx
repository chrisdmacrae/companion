import type { CoreBridge } from "@companion/core-bridge";
import { CoreProvider } from "./CoreContext";
import { AppShell } from "./AppShell";
import { FocusView } from "./FocusView";
import { focusNoteId } from "./focus";

/**
 * App is the shared root. The platform shell creates the CoreBridge (wasm on web,
 * HTTP on desktop) and passes it in, along with any chrome insets (space for the
 * desktop window's native controls). When the URL requests ?note=<id>, the app
 * renders that note in chrome-less focus mode instead of the full shell.
 */
export function App({ core, topInset }: { core: CoreBridge; topInset?: number }) {
  const focusId = focusNoteId();
  return (
    <CoreProvider core={core}>
      {focusId ? <FocusView id={focusId} topInset={topInset} /> : <AppShell topInset={topInset} />}
    </CoreProvider>
  );
}

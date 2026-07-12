// Emits the bundled ProseMirror editor as web assets the native visionOS app loads into a
// WKWebView (the SwiftUI analogue of Editor.tsx's WebView on RN). The JS bundle and CSS are
// the same ones the mobile app embeds — only the host differs. Run after `build:editor`:
//   npm run generate:visionos -w @companion/editor   (or `make visionos-editor`)
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { EDITOR_JS } from "../src/editorBundle.generated.ts";
import { EDITOR_CSS } from "../src/styles.ts";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "../../..");
const outDir = resolve(repoRoot, "apps/visionos/Resources");
mkdirSync(outDir, { recursive: true });

const header = "/* GENERATED from @companion/editor — do not edit. Regenerate: make visionos-editor */\n";
writeFileSync(resolve(outDir, "editor.js"), header + EDITOR_JS);
writeFileSync(resolve(outDir, "editor.css"), header + EDITOR_CSS);

console.log(`wrote editor.js (${(EDITOR_JS.length / 1024).toFixed(1)} kB) + editor.css to ${outDir}`);

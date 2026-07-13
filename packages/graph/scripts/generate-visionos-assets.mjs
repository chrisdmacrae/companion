// Emits the bundled React Flow graph as web assets the native visionOS app loads into a
// WKWebView (the SwiftUI analogue of GraphCanvas.tsx's WebView on RN). Same offline bundle
// the mobile app embeds — only the host differs. Run after `build:graph`:
//   npm run generate:visionos -w @companion/graph   (or `make visionos-graph`)
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { GRAPH_JS, GRAPH_CSS } from "../src/graphBundle.generated.ts";

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, "../../..");
const outDir = resolve(repoRoot, "apps/visionos/Resources");
mkdirSync(outDir, { recursive: true });

const header = "/* GENERATED from @companion/graph — do not edit. Regenerate: make visionos-graph */\n";
writeFileSync(resolve(outDir, "graph.js"), header + GRAPH_JS);
writeFileSync(resolve(outDir, "graph.css"), header + GRAPH_CSS);

console.log(`wrote graph.js (${(GRAPH_JS.length / 1024).toFixed(1)} kB) + graph.css to ${outDir}`);

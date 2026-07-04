import { AppRegistry } from "react-native";
import { App } from "@companion/app";
import { createWaSqliteDriver, createWasmBridge } from "@companion/core-bridge/wasm";
import { createElement } from "react";

// Web shell (PLAN §3.2): build the SQLite driver (wa-sqlite/IndexedDB), hand it to
// the core compiled to wasm, then mount the shared React Native UI via RNW.
async function boot() {
  const sqlite = await createWaSqliteDriver({ dbName: "companion" });
  const core = await createWasmBridge({ sqlite, wasmUrl: "/core.wasm" });

  const rootTag = document.getElementById("root")!;
  rootTag.innerHTML = "";
  AppRegistry.registerComponent("Companion", () => () => createElement(App, { core }));
  AppRegistry.runApplication("Companion", { rootTag });
}

boot().catch((err: unknown) => {
  const root = document.getElementById("root");
  if (root) {
    root.innerHTML = `<div class="boot">Failed to start: ${
      err instanceof Error ? err.message : String(err)
    }</div>`;
  }
  // eslint-disable-next-line no-console
  console.error("boot failed", err);
});

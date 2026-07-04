# Companion — Desktop (Wails v3)

The cheapest binding in the plan (PLAN §3.2): this app imports the Go `core/`
module directly — no cgo/FFI boundary — and hosts a Wails v3 webview. It proves the
architecture end-to-end for milestone 1: **Notes CRUD** on desktop.

## How it fits together

```
frontend/index.html  ──fetch("/invoke")──▶  bridge_handler.go  ──▶  core/bridge.Invoke
        ▲                                          │
        └────── EventSource("/events") ◀───────────┘  (core "notes.changed" events)
```

- `core/bridge` speaks the universal contract: `Invoke(method, jsonBytes) -> jsonBytes`
  plus an event stream. Every platform reuses it.
- `bridge_handler.go` adapts that contract onto HTTP and mounts it on the Wails
  AssetServer, so the webview talks to the core with plain `fetch` / `EventSource`.
  (Generating typed Wails bindings is a later enhancement; HTTP keeps milestone 1
  free of the `wails3` codegen/npm-runtime step.)
- SQLite lives at `<user-config-dir>/Companion/companion.db`
  (macOS: `~/Library/Application Support/Companion/companion.db`).

## Run it

```bash
make desktop-run        # from the repo root, or:
cd apps/desktop && go run .
```

A native window opens with the Notes UI. Requires a desktop session (it opens a
WebKit/WebView window) and the platform webview toolchain that Wails needs.

## Build a binary

```bash
make desktop            # -> build/companion-desktop
```

## Test

The bridge is verified headlessly (no window needed) — the HTTP layer exercises the
real core through the same path the frontend uses:

```bash
go test .               # apps/desktop
go test ./core/...      # the shared core
```

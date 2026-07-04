// Command desktop is the Companion desktop client (PLAN §3.2). It is the cheapest
// binding: it imports core/ directly (no cgo/FFI boundary) and hosts a Wails v3
// webview. The webview runs the shared React Native (react-native-web) UI from
// packages/app, built by apps/desktop/frontend (Vite) into frontend/dist and
// embedded here. That UI reaches the in-process core through the string+JSON Invoke
// API, bridged over the Wails AssetServer handler (see bridge_handler.go).
package main

import (
	"embed"
	"io/fs"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"companion/core/bridge"
	"companion/core/store"

	"github.com/wailsapp/wails/v3/pkg/application"
)

// The Vite build output. Run `make desktop-frontend` (or `make desktop`) to
// populate frontend/dist before `go build`.
//
//go:embed all:frontend/dist
var assets embed.FS

func main() {
	dbPath, err := databasePath()
	if err != nil {
		log.Fatalf("resolve database path: %v", err)
	}
	st, err := store.Open(dbPath, nil)
	if err != nil {
		log.Fatalf("open store (%s): %v", dbPath, err)
	}
	defer st.Close()

	core := bridge.New(st)
	handler := newBridgeHandler(core)
	core.SetEventHandler(handler)

	app := application.New(application.Options{
		Name:        "Companion",
		Description: "Offline-first notes, tasks, habits, and calendar.",
		Services:    []application.Service{},
		Assets: application.AssetOptions{
			Handler: rootHandler(handler),
		},
	})

	// Transparent titlebar: the standard window controls stay, but the titlebar is
	// see-through and content extends to the top edge, so the app's own toolbar
	// reads as the window chrome. Background matches the app canvas (#f5f5f3).
	app.Window.NewWithOptions(application.WebviewWindowOptions{
		Title:            "Companion",
		Width:            1000,
		Height:           720,
		MinWidth:         600,
		MinHeight:        400,
		BackgroundColour: application.NewRGB(245, 245, 243),
		URL:              "/",
		Mac: application.MacWindow{
			TitleBar: application.MacTitleBarHiddenInset,
		},
	})

	if err := app.Run(); err != nil {
		log.Fatalf("run app: %v", err)
	}
}

// rootHandler serves the embedded frontend at "/" and routes the core bridge API
// (/invoke, /events) to the bridge handler.
func rootHandler(bridge *bridgeHandler) http.Handler {
	frontend, err := fs.Sub(assets, "frontend/dist")
	if err != nil {
		log.Fatalf("mount frontend assets: %v", err)
	}
	files := http.FileServer(http.FS(frontend))

	mux := http.NewServeMux()
	mux.Handle("/invoke", bridge)
	mux.Handle("/events", bridge)
	mux.Handle("/", files)
	return mux
}

// databasePath returns the per-user SQLite location, creating the parent directory.
func databasePath() (string, error) {
	dir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	appDir := filepath.Join(dir, "Companion")
	if err := os.MkdirAll(appDir, 0o700); err != nil {
		return "", err
	}
	return filepath.Join(appDir, "companion.db"), nil
}

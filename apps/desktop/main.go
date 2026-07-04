// Command desktop is the Companion desktop client (PLAN §3.2, milestone 1). It is
// the cheapest binding: it imports core/ directly (no cgo/FFI boundary) and hosts a
// Wails v3 webview. Go methods reach the frontend through the core's string+JSON
// Invoke API, bridged over the Wails AssetServer handler (see bridge_handler.go).
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

//go:embed all:frontend
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

	app.Window.NewWithOptions(application.WebviewWindowOptions{
		Title:     "Companion",
		Width:     1000,
		Height:    720,
		MinWidth:  600,
		MinHeight: 400,
		URL:       "/",
	})

	if err := app.Run(); err != nil {
		log.Fatalf("run app: %v", err)
	}
}

// rootHandler serves the embedded frontend at "/" and routes the core bridge API
// (/invoke, /events) to the bridge handler.
func rootHandler(bridge *bridgeHandler) http.Handler {
	frontend, err := fs.Sub(assets, "frontend")
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

# Companion build orchestration (PLAN §8). Go builds live here; npm scripts drive
# the JS side. The Go workspace (go.work) ties core + apps/desktop together.

GO ?= go
BUILD_DIR ?= build
WASM_EXEC := $(shell $(GO) env GOROOT)/lib/wasm/wasm_exec.js
WEB_PUBLIC := apps/web/public

.PHONY: all test test-go fmt vet desktop desktop-frontend desktop-run core-wasm web-assets clean

all: test

## test-go: run the Go core + server-side test suites (fast, headless)
test-go:
	$(GO) test ./core/... ./apps/desktop/...

test: test-go

## fmt: format all Go code
fmt:
	gofmt -w core apps/desktop

## vet: static analysis over all Go modules
vet:
	cd core && $(GO) vet ./...
	cd apps/desktop && $(GO) vet ./...

## desktop-frontend: build the react-native-web webview UI into frontend/dist
desktop-frontend:
	npm run build -w @companion/desktop-frontend

## desktop: build the Wails desktop binary (frontend is built + embedded)
desktop: desktop-frontend
	mkdir -p $(BUILD_DIR)
	cd apps/desktop && $(GO) build -o ../../$(BUILD_DIR)/companion-desktop .

## desktop-run: build the frontend, then run the desktop app from source (dev)
desktop-run: desktop-frontend
	cd apps/desktop && $(GO) run .

## core-wasm: build the web core (GOOS=js GOARCH=wasm) -> build/core.wasm
core-wasm:
	mkdir -p $(BUILD_DIR)
	cd core && GOOS=js GOARCH=wasm $(GO) build -ldflags="-s -w" -o ../$(BUILD_DIR)/core.wasm ./cmd/wasm

## web-assets: build core.wasm and stage it + wasm_exec.js into the web app's public dir
web-assets: core-wasm
	mkdir -p $(WEB_PUBLIC)
	cp $(BUILD_DIR)/core.wasm $(WEB_PUBLIC)/core.wasm
	cp "$(WASM_EXEC)" $(WEB_PUBLIC)/wasm_exec.js

clean:
	rm -rf $(BUILD_DIR)

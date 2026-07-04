# Companion build orchestration (PLAN §8). Go builds live here; npm scripts drive
# the JS side. The Go workspace (go.work) ties core + apps/desktop together.

GO ?= go
BUILD_DIR ?= build

.PHONY: all test test-go fmt vet desktop desktop-run clean

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

## desktop: build the Wails desktop binary (assets are embedded)
desktop:
	mkdir -p $(BUILD_DIR)
	cd apps/desktop && $(GO) build -o ../../$(BUILD_DIR)/companion-desktop .

## desktop-run: run the desktop app from source (dev)
desktop-run:
	cd apps/desktop && $(GO) run .

clean:
	rm -rf $(BUILD_DIR)

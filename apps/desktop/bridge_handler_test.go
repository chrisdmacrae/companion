package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"companion/core/bridge"
	"companion/core/store"
)

// post drives the /invoke endpoint the same way the webview frontend does.
func post(t *testing.T, h http.Handler, method string, payload any) (int, map[string]any) {
	t.Helper()
	var raw json.RawMessage
	if payload != nil {
		b, err := json.Marshal(payload)
		if err != nil {
			t.Fatalf("marshal payload: %v", err)
		}
		raw = b
	}
	body, _ := json.Marshal(map[string]any{"method": method, "payload": raw})
	req := httptest.NewRequest(http.MethodPost, "/invoke", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)

	var out map[string]any
	// notes.list returns an array; tolerate that by decoding into a generic value.
	if rec.Body.Len() > 0 && rec.Body.Bytes()[0] == '{' {
		json.Unmarshal(rec.Body.Bytes(), &out)
	}
	return rec.Code, out
}

func newHandler(t *testing.T) *bridgeHandler {
	t.Helper()
	st, err := store.Open(":memory:", nil)
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { st.Close() })
	core := bridge.New(st)
	h := newBridgeHandler(core)
	core.SetEventHandler(h)
	return h
}

func TestInvokeNotesCRUDOverHTTP(t *testing.T) {
	h := newHandler(t)

	code, created := post(t, h, "notes.create", map[string]any{"title": "Hello", "contentMd": "body"})
	if code != http.StatusOK {
		t.Fatalf("create status = %d", code)
	}
	id, _ := created["id"].(string)
	if id == "" || created["title"] != "Hello" {
		t.Fatalf("unexpected create response: %v", created)
	}

	// List returns a JSON array.
	req := httptest.NewRequest(http.MethodPost, "/invoke",
		bytes.NewReader([]byte(`{"method":"notes.list","payload":null}`)))
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	var list []map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &list); err != nil {
		t.Fatalf("decode list: %v (%s)", err, rec.Body.String())
	}
	if len(list) != 1 {
		t.Fatalf("list len = %d, want 1", len(list))
	}

	code, updated := post(t, h, "notes.update", map[string]any{"id": id, "title": "Renamed"})
	if code != http.StatusOK || updated["title"] != "Renamed" {
		t.Fatalf("update failed: %d %v", code, updated)
	}

	code, _ = post(t, h, "notes.delete", map[string]any{"id": id})
	if code != http.StatusOK {
		t.Fatalf("delete status = %d", code)
	}
}

func TestInvokeErrorMapsToBadRequest(t *testing.T) {
	h := newHandler(t)
	code, out := post(t, h, "notes.get", map[string]any{"id": "missing"})
	if code != http.StatusBadRequest {
		t.Fatalf("missing-note status = %d, want 400", code)
	}
	if out["error"] == nil {
		t.Errorf("expected error field, got %v", out)
	}
}

func TestUnknownMethod(t *testing.T) {
	h := newHandler(t)
	code, out := post(t, h, "bogus.method", nil)
	if code != http.StatusBadRequest || out["error"] == nil {
		t.Errorf("unknown method: code=%d out=%v", code, out)
	}
}

// TestEventBroadcast verifies the core's change event reaches SSE subscribers.
func TestEventBroadcast(t *testing.T) {
	h := newHandler(t)
	ch := make(chan sseMessage, 1)
	h.mu.Lock()
	h.clients[ch] = struct{}{}
	h.mu.Unlock()

	post(t, h, "notes.create", map[string]any{"title": "x"})
	select {
	case msg := <-ch:
		if msg.event != "notes.changed" {
			t.Errorf("event = %q, want notes.changed", msg.event)
		}
	default:
		t.Error("expected a broadcast event after create")
	}
}

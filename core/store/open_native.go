//go:build !js

package store

import "companion/core/domain"

// Open opens (or creates) a native SQLite database at dsn, applies migrations, and
// returns a ready Store. Use ":memory:" for tests. A nil clock defaults to the
// system clock. The wasm build has no Open — its shell constructs a JS-backed Driver
// and calls New (see core/cmd/wasm).
func Open(dsn string, clock domain.Clock) (*Store, error) {
	d, err := openNativeDriver(dsn)
	if err != nil {
		return nil, err
	}
	return New(d, clock)
}

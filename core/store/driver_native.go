//go:build !js

package store

import (
	"database/sql"
	"fmt"

	_ "modernc.org/sqlite" // pure-Go SQLite driver (PLAN §3.2)
)

// nativeDriver backs Driver with database/sql + modernc.org/sqlite on every native
// platform (desktop, mobile). The wasm build uses driver_wasm.go instead.
type nativeDriver struct{ db *sql.DB }

// openNativeDriver opens (or creates) a SQLite database at dsn. Use ":memory:" for
// tests.
func openNativeDriver(dsn string) (Driver, error) {
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}
	// modernc serializes access per connection; a single connection keeps an
	// in-memory DB alive and avoids "database is locked" under concurrency.
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON;"); err != nil {
		db.Close()
		return nil, fmt.Errorf("enable foreign keys: %w", err)
	}
	return &nativeDriver{db: db}, nil
}

func (d *nativeDriver) Exec(query string, args ...any) (Result, error) {
	return d.db.Exec(query, args...)
}

func (d *nativeDriver) Query(query string, args ...any) (Rows, error) {
	return d.db.Query(query, args...)
}

func (d *nativeDriver) Close() error { return d.db.Close() }

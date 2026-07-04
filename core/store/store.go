// Package store owns the client-side SQLite persistence: the embedded schema
// migrations and the per-entity repositories (PLAN §4.1, §7). Milestone 1 wires
// notes; other tables are created but not yet exercised.
package store

import (
	"database/sql"
	"fmt"

	"companion/core/domain"

	_ "modernc.org/sqlite" // pure-Go SQLite driver (PLAN §3.2)
)

// Store is the client's SQLite database plus its repositories.
type Store struct {
	db    *sql.DB
	clock domain.Clock

	Notes *NotesRepo
}

// Open opens (or creates) the SQLite database at dsn, applies pending migrations,
// and returns a ready Store. Use ":memory:" for tests. A nil clock defaults to the
// system clock.
func Open(dsn string, clock domain.Clock) (*Store, error) {
	if clock == nil {
		clock = domain.SystemClock{}
	}
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}
	// modernc's driver serializes access per connection; a single connection keeps
	// an in-memory DB alive and avoids "database is locked" under concurrency.
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON;"); err != nil {
		db.Close()
		return nil, fmt.Errorf("enable foreign keys: %w", err)
	}
	if err := migrate(db); err != nil {
		db.Close()
		return nil, err
	}
	s := &Store{db: db, clock: clock}
	s.Notes = &NotesRepo{db: db, clock: clock}
	return s, nil
}

// Close closes the underlying database.
func (s *Store) Close() error { return s.db.Close() }

package store

import (
	"embed"
	"fmt"
	"io/fs"
	"sort"
	"strings"
)

//go:embed migrations/*.sql
var migrationsFS embed.FS

// migrate applies every embedded migration whose version has not yet been recorded,
// in filename order, each wrapped in a BEGIN/COMMIT so a failure leaves no partial
// schema. Migration files are named "NNNN_description.sql"; NNNN is the version.
//
// Transactions are driven with plain SQL statements rather than a Driver method so
// the interface stays minimal across the native and wasm backends (PLAN §3.2).
func migrate(d Driver) error {
	if _, err := d.Exec(`CREATE TABLE IF NOT EXISTS schema_migrations (
		version TEXT PRIMARY KEY,
		applied_at TEXT NOT NULL DEFAULT (datetime('now'))
	);`); err != nil {
		return fmt.Errorf("create schema_migrations: %w", err)
	}

	applied, err := appliedVersions(d)
	if err != nil {
		return err
	}

	names, err := migrationNames()
	if err != nil {
		return err
	}

	for _, name := range names {
		version := versionOf(name)
		if applied[version] {
			continue
		}
		sqlBytes, err := migrationsFS.ReadFile("migrations/" + name)
		if err != nil {
			return fmt.Errorf("read migration %s: %w", name, err)
		}
		if err := applyMigration(d, name, version, string(sqlBytes)); err != nil {
			return err
		}
	}
	return nil
}

func applyMigration(d Driver, name, version, body string) (err error) {
	if _, err = d.Exec("BEGIN;"); err != nil {
		return fmt.Errorf("begin migration %s: %w", name, err)
	}
	defer func() {
		if err != nil {
			d.Exec("ROLLBACK;")
		}
	}()
	if _, err = d.Exec(body); err != nil {
		return fmt.Errorf("apply migration %s: %w", name, err)
	}
	if _, err = d.Exec(`INSERT INTO schema_migrations (version) VALUES (?);`, version); err != nil {
		return fmt.Errorf("record migration %s: %w", name, err)
	}
	if _, err = d.Exec("COMMIT;"); err != nil {
		return fmt.Errorf("commit migration %s: %w", name, err)
	}
	return nil
}

func appliedVersions(d Driver) (map[string]bool, error) {
	rows, err := d.Query(`SELECT version FROM schema_migrations;`)
	if err != nil {
		return nil, fmt.Errorf("read schema_migrations: %w", err)
	}
	defer rows.Close()
	applied := map[string]bool{}
	for rows.Next() {
		var v string
		if err := rows.Scan(&v); err != nil {
			return nil, fmt.Errorf("scan migration version: %w", err)
		}
		applied[v] = true
	}
	return applied, rows.Err()
}

func migrationNames() ([]string, error) {
	entries, err := fs.ReadDir(migrationsFS, "migrations")
	if err != nil {
		return nil, fmt.Errorf("read migrations dir: %w", err)
	}
	names := make([]string, 0, len(entries))
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".sql") {
			names = append(names, e.Name())
		}
	}
	sort.Strings(names)
	return names, nil
}

// versionOf extracts the leading "NNNN" version token from a migration filename.
func versionOf(name string) string {
	if i := strings.IndexByte(name, '_'); i > 0 {
		return name[:i]
	}
	return strings.TrimSuffix(name, ".sql")
}

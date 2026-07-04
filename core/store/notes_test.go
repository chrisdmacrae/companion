package store

import (
	"testing"
	"time"

	"companion/core/domain"
)

// fixedClock returns a controllable time for deterministic timestamps.
type fixedClock struct{ t time.Time }

func (c *fixedClock) Now() time.Time { return c.t }

func newTestStore(t *testing.T, clk domain.Clock) *Store {
	t.Helper()
	s, err := Open(":memory:", clk)
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { s.Close() })
	return s
}

func TestNotesCreateAndGet(t *testing.T) {
	clk := &fixedClock{t: time.Date(2026, 7, 4, 12, 0, 0, 0, time.UTC)}
	s := newTestStore(t, clk)

	n, err := s.Notes.Create(CreateNoteInput{Title: "Hello", ContentMD: "# Hi"})
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	if n.ID == "" {
		t.Fatal("expected generated id")
	}
	if !n.Dirty {
		t.Error("new note should be dirty")
	}
	if n.Version != 0 {
		t.Errorf("new note version = %d, want 0", n.Version)
	}
	if !n.CreatedAt.Equal(clk.t) || !n.UpdatedAt.Equal(clk.t) {
		t.Errorf("timestamps not stamped from clock: %v / %v", n.CreatedAt, n.UpdatedAt)
	}

	got, err := s.Notes.Get(n.ID)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.Title != "Hello" || got.ContentMD != "# Hi" {
		t.Errorf("round-trip mismatch: %+v", got)
	}
	if !got.CreatedAt.Equal(clk.t) {
		t.Errorf("created_at round-trip = %v, want %v", got.CreatedAt, clk.t)
	}
}

func TestNotesGetMissing(t *testing.T) {
	s := newTestStore(t, nil)
	if _, err := s.Notes.Get("nope"); err != ErrNotFound {
		t.Errorf("get missing err = %v, want ErrNotFound", err)
	}
}

func TestNotesList(t *testing.T) {
	clk := &fixedClock{t: time.Date(2026, 7, 4, 12, 0, 0, 0, time.UTC)}
	s := newTestStore(t, clk)

	if notes, err := s.Notes.List(); err != nil || len(notes) != 0 {
		t.Fatalf("empty list = %v, %v", notes, err)
	}

	a, _ := s.Notes.Create(CreateNoteInput{Title: "A"})
	clk.t = clk.t.Add(time.Minute)
	b, _ := s.Notes.Create(CreateNoteInput{Title: "B"})

	notes, err := s.Notes.List()
	if err != nil {
		t.Fatalf("list: %v", err)
	}
	if len(notes) != 2 {
		t.Fatalf("list len = %d, want 2", len(notes))
	}
	// Newest-updated first.
	if notes[0].ID != b.ID || notes[1].ID != a.ID {
		t.Errorf("list order wrong: got %s,%s", notes[0].Title, notes[1].Title)
	}
}

func TestNotesUpdate(t *testing.T) {
	clk := &fixedClock{t: time.Date(2026, 7, 4, 12, 0, 0, 0, time.UTC)}
	s := newTestStore(t, clk)

	n, _ := s.Notes.Create(CreateNoteInput{Title: "Old", ContentMD: "old"})
	clk.t = clk.t.Add(time.Hour)

	newTitle := "New"
	got, err := s.Notes.Update(n.ID, UpdateNoteInput{Title: &newTitle})
	if err != nil {
		t.Fatalf("update: %v", err)
	}
	if got.Title != "New" {
		t.Errorf("title = %q, want New", got.Title)
	}
	if got.ContentMD != "old" {
		t.Errorf("content should be unchanged, got %q", got.ContentMD)
	}
	if !got.UpdatedAt.Equal(clk.t) {
		t.Errorf("updated_at = %v, want %v", got.UpdatedAt, clk.t)
	}
	if got.CreatedAt.Equal(got.UpdatedAt) {
		t.Error("updated_at should differ from created_at after update")
	}
}

func TestNotesUpdateMissing(t *testing.T) {
	s := newTestStore(t, nil)
	title := "x"
	if _, err := s.Notes.Update("nope", UpdateNoteInput{Title: &title}); err != ErrNotFound {
		t.Errorf("update missing err = %v, want ErrNotFound", err)
	}
}

func TestNotesDeleteIsSoft(t *testing.T) {
	s := newTestStore(t, nil)
	n, _ := s.Notes.Create(CreateNoteInput{Title: "Doomed"})

	if err := s.Notes.Delete(n.ID); err != nil {
		t.Fatalf("delete: %v", err)
	}
	// Gone from Get/List...
	if _, err := s.Notes.Get(n.ID); err != ErrNotFound {
		t.Errorf("get after delete = %v, want ErrNotFound", err)
	}
	if notes, _ := s.Notes.List(); len(notes) != 0 {
		t.Errorf("list after delete has %d notes, want 0", len(notes))
	}
	// ...but the tombstone row still exists (soft delete).
	var deletedAt *string
	row := s.db.QueryRow(`SELECT deleted_at FROM notes WHERE id = ?;`, n.ID)
	if err := row.Scan(&deletedAt); err != nil {
		t.Fatalf("tombstone scan: %v", err)
	}
	if deletedAt == nil {
		t.Error("expected deleted_at to be set on tombstone")
	}
	// Double-delete is ErrNotFound.
	if err := s.Notes.Delete(n.ID); err != ErrNotFound {
		t.Errorf("double delete = %v, want ErrNotFound", err)
	}
}

func TestNotesDateValidation(t *testing.T) {
	s := newTestStore(t, nil)
	bad := "07/04/2026"
	if _, err := s.Notes.Create(CreateNoteInput{Title: "x", Date: &bad}); err == nil {
		t.Error("expected validation error for bad date format")
	}
	good := "2026-07-04"
	n, err := s.Notes.Create(CreateNoteInput{Title: "x", Date: &good})
	if err != nil {
		t.Fatalf("create with good date: %v", err)
	}
	if n.Date == nil || *n.Date != good {
		t.Errorf("date = %v, want %s", n.Date, good)
	}
}

func TestMigrationsIdempotent(t *testing.T) {
	// Re-running migrate against an already-migrated DB is a no-op.
	s := newTestStore(t, nil)
	if err := migrate(s.db); err != nil {
		t.Fatalf("second migrate: %v", err)
	}
}

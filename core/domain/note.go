package domain

import (
	"errors"
	"strings"
	"time"
)

// Note is a markdown note. Its canonical storage format is the markdown text in
// ContentMD; ProseMirror / editor state is an editor-local concern (see PLAN §6.1).
type Note struct {
	ID        string     `json:"id"`
	Title     string     `json:"title"`
	ContentMD string     `json:"contentMd"`
	Date      *string    `json:"date,omitempty"` // optional 'YYYY-MM-DD'; surfaces on calendar
	CreatedAt time.Time  `json:"createdAt"`
	UpdatedAt time.Time  `json:"updatedAt"`
	DeletedAt *time.Time `json:"deletedAt,omitempty"`
	Version   int64      `json:"version"`
	Dirty     bool       `json:"dirty"`
}

// ErrInvalidNote is returned when a note fails validation.
var ErrInvalidNote = errors.New("invalid note")

// Validate checks the invariants that must hold before a note is persisted.
func (n *Note) Validate() error {
	if strings.TrimSpace(n.ID) == "" {
		return errors.Join(ErrInvalidNote, errors.New("id is required"))
	}
	if n.Date != nil {
		if _, err := time.Parse("2006-01-02", *n.Date); err != nil {
			return errors.Join(ErrInvalidNote, errors.New("date must be YYYY-MM-DD"))
		}
	}
	return nil
}

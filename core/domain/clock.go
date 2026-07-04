package domain

import "time"

// Clock abstracts the current time so logic that stamps created_at/updated_at is
// testable and deterministic (see PLAN §3.3).
type Clock interface {
	Now() time.Time
}

// SystemClock reports the real wall-clock time in UTC.
type SystemClock struct{}

// Now returns the current UTC time.
func (SystemClock) Now() time.Time { return time.Now().UTC() }

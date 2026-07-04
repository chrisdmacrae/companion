-- Client-side SQLite schema (PLAN §4.1). Owned by core/store.
-- Every syncable table carries: created_at, updated_at, deleted_at (tombstone),
-- version (last-seen server version; 0 = never synced), dirty (unpushed local edit).

CREATE TABLE sync_state (
  id             INTEGER PRIMARY KEY CHECK (id = 1),
  device_id      TEXT NOT NULL,
  server_cursor  INTEGER NOT NULL DEFAULT 0,   -- last server_seq pulled
  last_synced_at TEXT
);

CREATE TABLE notes (
  id          TEXT PRIMARY KEY,
  title       TEXT NOT NULL DEFAULT '',
  content_md  TEXT NOT NULL DEFAULT '',        -- canonical format is markdown
  date        TEXT,                            -- optional; surfaces note on calendar
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL,
  deleted_at  TEXT,
  version     INTEGER NOT NULL DEFAULT 0,
  dirty       INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX idx_notes_updated_at ON notes (updated_at);

CREATE TABLE tasks (
  id             TEXT PRIMARY KEY,
  title          TEXT NOT NULL,
  notes_md       TEXT NOT NULL DEFAULT '',
  status         TEXT NOT NULL DEFAULT 'open',    -- open | done | cancelled
  due_at         TEXT,
  remind_at      TEXT,                            -- reminder -> local notification
  completed_at   TEXT,
  repeat_rule    TEXT,           -- RFC5545 RRULE; set ONLY on seed tasks
  repeat_seed_id TEXT,           -- occurrences point at their seed; NULL on seeds/one-offs
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 0,
  dirty   INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE habits (
  id           TEXT PRIMARY KEY,
  name         TEXT NOT NULL,
  cadence      TEXT NOT NULL,     -- RRULE subset: daily / weekly on M,W,F / etc.
  target_count INTEGER NOT NULL DEFAULT 1,
  color        TEXT,
  archived_at  TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 0,
  dirty   INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE habit_entries (
  id         TEXT PRIMARY KEY,
  habit_id   TEXT NOT NULL,
  date       TEXT NOT NULL,       -- local calendar date 'YYYY-MM-DD'
  count      INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 0,
  dirty   INTEGER NOT NULL DEFAULT 1,
  UNIQUE (habit_id, date)
);

CREATE TABLE calendar_feeds (
  id    TEXT PRIMARY KEY,
  name  TEXT NOT NULL,
  url   TEXT NOT NULL,            -- ICS URL; fetched by the SERVER, not clients
  color TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 0,
  dirty   INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE calendar_events (    -- server-owned clone; READ-ONLY on clients
  id        TEXT PRIMARY KEY,
  feed_id   TEXT NOT NULL,
  ics_uid   TEXT NOT NULL,
  title     TEXT NOT NULL,
  starts_at TEXT NOT NULL,
  ends_at   TEXT,
  all_day   INTEGER NOT NULL DEFAULT 0,
  location  TEXT,
  description TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 0
  -- no dirty column: clients never write these
);

CREATE TABLE llm_configs (
  id          TEXT PRIMARY KEY,
  scope       TEXT NOT NULL,      -- 'device' (local LLM) | 'account' (remote LLM)
  name        TEXT NOT NULL,
  base_url    TEXT NOT NULL,
  provider    TEXT NOT NULL,      -- 'openai-compatible' | 'anthropic' | ...
  model       TEXT NOT NULL,
  api_key_ref TEXT,               -- key lives in OS keychain / SecureStore, NOT in the DB
  is_default  INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  version INTEGER NOT NULL DEFAULT 0,
  dirty   INTEGER NOT NULL DEFAULT 1
);

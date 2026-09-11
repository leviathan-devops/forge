import Foundation
import SQLite3

// MARK: - SQLite transient destructor constant (file-private).
// Mirrors SQLite's SQLITE_TRANSIENT = ((sqlite3_destructor_type)-1).
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - SessionSchema

/// Verbatim DDL, pragmas, and project seeding for the FORGE SQLite session store.
///
/// All SQL is transcribed from `packages/core/src/database/database.ts` (pragmas),
/// `packages/core/src/session/sql.sql` (7-table DDL, hash `e572ed…`), and the
/// `project` table (spec §3.3). Do NOT hand-edit the SQL — diff against the source.
enum SessionSchema {

    // MARK: Pragmas (spec §3.1, verbatim from database.ts hash `c44fbd…`)

    /// Six pragmas executed once per connection open, in declaration order.
    static let pragmas = """
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;
        PRAGMA busy_timeout = 5000;
        PRAGMA cache_size = -64000;
        PRAGMA foreign_keys = ON;
        PRAGMA wal_checkpoint(PASSIVE);
        """

    // MARK: project table (spec §3.3) — dependency of session.project_id

    static let projectDDL = """
        CREATE TABLE IF NOT EXISTS "project" (
          "id" text PRIMARY KEY NOT NULL,
          "worktree" text NOT NULL,
          "vcs" text,
          "name" text,
          "icon_url" text,
          "icon_url_override" text,
          "icon_color" text,
          "time_created" integer NOT NULL,
          "time_updated" integer NOT NULL,
          "time_initialized" integer,
          "sandboxes" text,
          "commands" text
        );
        """

    // MARK: 7-table DDL (spec §3.2, verbatim from sql.sql hash `e572ed…`)

    /// `session`, `message`, `part`, `todo`, `session_message`,
    /// `session_input`, `session_context_epoch` + every index, in creation order.
    static let ddl = """
        CREATE TABLE IF NOT EXISTS "session" (
          "id" text PRIMARY KEY NOT NULL,
          "project_id" text NOT NULL REFERENCES "project"("id") ON DELETE cascade,
          "workspace_id" text,
          "parent_id" text,
          "slug" text NOT NULL,
          "directory" text NOT NULL,
          "path" text,
          "title" text NOT NULL,
          "version" text NOT NULL,
          "share_url" text,
          "summary_additions" integer,
          "summary_deletions" integer,
          "summary_files" integer,
          "summary_diffs" text,
          "metadata" text,
          "cost" real NOT NULL DEFAULT 0,
          "tokens_input" integer NOT NULL DEFAULT 0,
          "tokens_output" integer NOT NULL DEFAULT 0,
          "tokens_reasoning" integer NOT NULL DEFAULT 0,
          "tokens_cache_read" integer NOT NULL DEFAULT 0,
          "tokens_cache_write" integer NOT NULL DEFAULT 0,
          "revert" text,
          "permission" text,
          "agent" text,
          "model" text,
          "time_created" integer NOT NULL,
          "time_updated" integer NOT NULL,
          "time_compacting" integer,
          "time_archived" integer
        );
        CREATE INDEX IF NOT EXISTS "session_project_idx" ON "session" ("project_id");
        CREATE INDEX IF NOT EXISTS "session_workspace_idx" ON "session" ("workspace_id");
        CREATE INDEX IF NOT EXISTS "session_parent_idx" ON "session" ("parent_id");

        CREATE TABLE IF NOT EXISTS "message" (
          "id" text PRIMARY KEY NOT NULL,
          "session_id" text NOT NULL REFERENCES "session"("id") ON DELETE cascade,
          "time_created" integer NOT NULL,
          "time_updated" integer NOT NULL,
          "data" text NOT NULL
        );
        CREATE INDEX IF NOT EXISTS "message_session_time_created_id_idx"
          ON "message" ("session_id", "time_created", "id");

        CREATE TABLE IF NOT EXISTS "part" (
          "id" text PRIMARY KEY NOT NULL,
          "message_id" text NOT NULL REFERENCES "message"("id") ON DELETE cascade,
          "session_id" text NOT NULL,
          "time_created" integer NOT NULL,
          "time_updated" integer NOT NULL,
          "data" text NOT NULL
        );
        CREATE INDEX IF NOT EXISTS "part_message_id_id_idx" ON "part" ("message_id", "id");
        CREATE INDEX IF NOT EXISTS "part_session_idx" ON "part" ("session_id");

        CREATE TABLE IF NOT EXISTS "todo" (
          "session_id" text NOT NULL REFERENCES "session"("id") ON DELETE cascade,
          "content" text NOT NULL,
          "status" text NOT NULL,
          "priority" text NOT NULL,
          "position" integer NOT NULL,
          "time_created" integer NOT NULL,
          "time_updated" integer NOT NULL,
          PRIMARY KEY ("session_id", "position")
        );
        CREATE INDEX IF NOT EXISTS "todo_session_idx" ON "todo" ("session_id");

        CREATE TABLE IF NOT EXISTS "session_message" (
          "id" text PRIMARY KEY NOT NULL,
          "session_id" text NOT NULL REFERENCES "session"("id") ON DELETE cascade,
          "type" text NOT NULL,
          "seq" integer NOT NULL,
          "time_created" integer NOT NULL,
          "time_updated" integer NOT NULL,
          "data" text NOT NULL
        );
        CREATE UNIQUE INDEX IF NOT EXISTS "session_message_session_seq_idx"
          ON "session_message" ("session_id", "seq");
        CREATE INDEX IF NOT EXISTS "session_message_session_type_seq_idx"
          ON "session_message" ("session_id", "type", "seq");
        CREATE INDEX IF NOT EXISTS "session_message_session_time_created_id_idx"
          ON "session_message" ("session_id", "time_created", "id");
        CREATE INDEX IF NOT EXISTS "session_message_time_created_idx"
          ON "session_message" ("time_created");

        CREATE TABLE IF NOT EXISTS "session_input" (
          "id" text PRIMARY KEY NOT NULL,
          "session_id" text NOT NULL REFERENCES "session"("id") ON DELETE cascade,
          "prompt" text NOT NULL,
          "delivery" text NOT NULL,
          "admitted_seq" integer NOT NULL,
          "promoted_seq" integer,
          "time_created" integer NOT NULL DEFAULT (unixepoch() * 1000)
        );
        CREATE INDEX IF NOT EXISTS "session_input_session_pending_delivery_seq_idx"
          ON "session_input" ("session_id", "promoted_seq", "delivery", "admitted_seq");
        CREATE UNIQUE INDEX IF NOT EXISTS "session_input_session_admitted_seq_idx"
          ON "session_input" ("session_id", "admitted_seq");
        CREATE UNIQUE INDEX IF NOT EXISTS "session_input_session_promoted_seq_idx"
          ON "session_input" ("session_id", "promoted_seq");

        CREATE TABLE IF NOT EXISTS "session_context_epoch" (
          "session_id" text PRIMARY KEY NOT NULL REFERENCES "session"("id") ON DELETE cascade,
          "baseline" text NOT NULL,
          "snapshot" text NOT NULL,
          "baseline_seq" integer NOT NULL
        );
        """

    // MARK: Project seed (spec §3.3)

    /// `INSERT OR IGNORE` the seed project row so the `session.project_id` FK resolves on
    /// first launch. Idempotent — safe to call every open. Uses a prepared statement.
    /// Worktree/name are the spec-verbatim demo values; timestamps are unix-ms at call time.
    static func seedProjectIfNeeded(db: OpaquePointer?, projectID: String) {
        let sql = """
            INSERT OR IGNORE INTO "project"
              ("id", "worktree", "name", "time_created", "time_updated")
            VALUES (?, ?, ?, ?, ?);
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            sqlite3_finalize(stmt)
            return
        }
        defer { sqlite3_finalize(stmt) }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let worktree = "Documents/projects/FORGE-Demo"
        let name = "FORGE-Demo"

        sqlite3_bind_text(stmt, 1, projectID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, worktree, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 4, now)
        sqlite3_bind_int64(stmt, 5, now)
        _ = sqlite3_step(stmt)
    }
}

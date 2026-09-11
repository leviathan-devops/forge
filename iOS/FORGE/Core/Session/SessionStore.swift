import Foundation
import SQLite3
import Combine

// MARK: - SQLite transient destructor constant (file-private).
// Mirrors SQLite's SQLITE_TRANSIENT = ((sqlite3_destructor_type)-1).
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - SessionStoreError

enum SessionStoreError: Error, LocalizedError {
    case deallocated
    case prepareFailed(String)
    case stepFailed(String)

    var errorDescription: String? {
        switch self {
        case .deallocated:               return "SessionStore was deallocated mid-operation"
        case .prepareFailed(let why):    return "SQLite prepare failed: \(why)"
        case .stepFailed(let why):       return "SQLite step failed: \(why)"
        }
    }
}

// MARK: - SessionStore

/// SQLite3-backed session store. Wraps the C API behind a serial dispatch queue so
/// every DB touch happens on one thread, while `@Published` state is republished on
/// the main actor for SwiftUI consumption.
///
/// Schema lives in `SessionSchema`; id generation in `SessionID`; row models in
/// `SessionModels`. This file is pure plumbing: open, prepare, bind, step, map.
final class SessionStore: ObservableObject {

    // MARK: Connection & published state

    /// The single SQLite connection. Touched ONLY on `queue`.
    private var db: OpaquePointer?

    /// The session currently in focus (selected/resumed/just-created). Main-thread only.
    @Published private(set) var currentSession: SessionInfo?

    /// Root sessions (`parent_id IS NULL`) for the demo project, newest first.
    @Published private(set) var roots: [SessionInfo] = []

    /// All DB work funnels through this serial queue → no locks needed around `db`.
    private let queue = DispatchQueue(label: "forge.sqlite", qos: .userInitiated)

    // MARK: Demo project constants

    /// The seeded project id (`project.id = 'proj_demo'` per spec §3.3).
    static let demoProjectID = "proj_demo"

    /// `session.directory` for new sessions — sandbox-relative demo worktree (spec §3.3).
    var demoProjectPath: String { "Documents/projects/FORGE-Demo" }

    /// Convenience: number of root sessions currently held in memory.
    var rootsCount: Int { roots.count }

    // MARK: Init

    /// Open the connection, apply pragmas + DDL, seed the demo project.
    /// - Parameter inMemory: `true` for `:memory:` (tests/previews); default file-backed.
    init(inMemory: Bool = false) {
        let path = inMemory ? ":memory:" : Self.dbPath()
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let openRC = sqlite3_open_v2(path, &db, flags, nil)
        precondition(openRC == SQLITE_OK, "SessionStore: sqlite3_open_v2 failed for \(path)")

        execute(SessionSchema.pragmas)              // 6 pragmas (WAL, FK, …)
        execute(SessionSchema.projectDDL)           // project table (FK target)
        execute(SessionSchema.ddl)                  // 7 session tables + indexes
        SessionSchema.seedProjectIfNeeded(db: db, projectID: Self.demoProjectID)
    }

    deinit {
        if db != nil { sqlite3_close_v2(db) }
    }

    /// Absolute path to `Documents/opencode.db` (WAL sidecars land alongside).
    static func dbPath() -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("opencode.db").path
    }

    // MARK: - Schema exec (pragmas + DDL only — never user SQL)

    /// `sqlite3_exec` wrapper for idempotent schema statements. Asserts on failure so
    /// a malformed DDL blows up loudly in dev rather than silently corrupting state.
    private func execute(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if rc != SQLITE_OK {
            let detail = errMsg.map { String(cString: $0) } ?? "rc=\(rc)"
            sqlite3_free(errMsg)
            assertionFailure("SessionStore.exec failed: \(detail)\nSQL:\n\(sql)")
        }
    }

    // MARK: - Resume (spec §13.1)

    /// Load up to 100 root sessions (`parent_id IS NULL`) for the demo project,
    /// newest-first. Async on `queue`; publishes `roots` on main when done.
    func loadRoots() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let sql = """
                SELECT * FROM session
                WHERE project_id = ? AND parent_id IS NULL
                ORDER BY time_updated DESC LIMIT 100
                """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                sqlite3_finalize(stmt); return
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, Self.demoProjectID, -1, SQLITE_TRANSIENT)

            var rows: [SessionInfo] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                rows.append(self.readSession(stmt))
            }
            DispatchQueue.main.async { self.roots = rows }
        }
    }

    /// The most recently updated root session, or nil if none loaded.
    /// Call `loadRoots()` first — this only inspects the in-memory cache.
    func resumeLatest() -> SessionInfo? { roots.first }

    /// Make `session` the active session (e.g. after Switch Session). Updates
    /// `currentSession` on the main thread; does not touch the DB row.
    func select(_ session: SessionInfo) {
        DispatchQueue.main.async { self.currentSession = session }
    }

    // MARK: - CRUD

    /// Create & persist a new session row. Generates a descending id (newest sorts first),
    /// derives a default title if none supplied, and publishes it as `currentSession`.
    func create(parentID: String?,
                title: String?,
                agent: String?,
                model: ModelRef?) async throws -> SessionInfo {

        let id = SessionID.descending(.session)
        let resolvedTitle = title ?? defaultTitle(parentID: parentID)
        let now = nowMs()
        let slug = slugBase62(8)
        let directory = demoProjectPath

        let modelJSON: String?
        if let model = model {
            if let v = model.variant {
                modelJSON = "{\"id\":\"\(model.id)\",\"providerID\":\"\(model.providerID)\",\"variant\":\"\(v)\"}"
            } else {
                modelJSON = "{\"id\":\"\(model.id)\",\"providerID\":\"\(model.providerID)\"}"
            }
        } else {
            modelJSON = nil
        }

        let session = SessionInfo(
            id: id, projectID: Self.demoProjectID, workspaceID: nil, parentID: parentID,
            slug: slug, directory: directory, path: nil, title: resolvedTitle,
            version: "1.0.0", shareURL: nil, summaryAdditions: nil, summaryDeletions: nil,
            summaryFiles: nil, summaryDiffs: nil, metadata: nil, cost: 0,
            tokensInput: 0, tokensOutput: 0, tokensReasoning: 0,
            tokensCacheRead: 0, tokensCacheWrite: 0,
            revert: nil, permission: nil, agent: agent, model: modelJSON,
            timeCreated: now, timeUpdated: now, timeCompacting: nil, timeArchived: nil
        )

        try await insertSessionRow(session)

        DispatchQueue.main.async { self.currentSession = session }
        return session
    }

    /// `UPDATE session SET title=?, time_updated=? WHERE id=?`.
    func setTitle(_ id: String, _ title: String) async throws {
        try await runParameterized(
            "UPDATE session SET title = ?, time_updated = ? WHERE id = ?;"
        ) { stmt in
            sqlite3_bind_text(stmt, 1, title, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(stmt, 2, self.nowMs())
            sqlite3_bind_text(stmt, 3, id, -1, SQLITE_TRANSIENT)
        }
        touch(id)
    }

    /// `UPDATE session SET agent=?, model=?, time_updated=? WHERE id=?`.
    func setAgentModel(_ id: String, agent: String, model: ModelRef) async throws {
        let modelJSON: String
        if let v = model.variant {
            modelJSON = "{\"id\":\"\(model.id)\",\"providerID\":\"\(model.providerID)\",\"variant\":\"\(v)\"}"
        } else {
            modelJSON = "{\"id\":\"\(model.id)\",\"providerID\":\"\(model.providerID)\"}"
        }
        try await runParameterized(
            "UPDATE session SET agent = ?, model = ?, time_updated = ? WHERE id = ?;"
        ) { stmt in
            sqlite3_bind_text(stmt, 1, agent, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, modelJSON, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(stmt, 3, self.nowMs())
            sqlite3_bind_text(stmt, 4, id, -1, SQLITE_TRANSIENT)
        }
        touch(id)
    }

    /// Bump `time_updated` to now for the given session (keeps it first in lists).
    func touch(_ id: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let sql = "UPDATE session SET time_updated = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                sqlite3_finalize(stmt); return
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, self.nowMs())
            sqlite3_bind_text(stmt, 2, id, -1, SQLITE_TRANSIENT)
            _ = sqlite3_step(stmt)
        }
    }

    /// `DELETE FROM session WHERE id=?` — FK `ON DELETE cascade` purges messages/parts/etc.
    func remove(_ id: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let sql = "DELETE FROM session WHERE id = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                sqlite3_finalize(stmt); return
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            _ = sqlite3_step(stmt)
        }
    }

    /// Fetch a single session row by id, or nil if absent.
    func get(_ id: String) async throws -> SessionInfo? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: SessionStoreError.deallocated); return
                }
                let sql = "SELECT * FROM session WHERE id = ? LIMIT 1;"
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    sqlite3_finalize(stmt)
                    continuation.resume(throwing: SessionStoreError.prepareFailed("get session"))
                    return
                }
                defer { sqlite3_finalize(stmt) }
                sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)

                let row = sqlite3_step(stmt) == SQLITE_ROW ? self.readSession(stmt) : nil
                continuation.resume(returning: row)
            }
        }
    }

    // MARK: - Messages & parts

    /// Page backwards through a session's messages.
    /// Returns rows in chronological order (oldest → newest) for display; paging uses
    /// ascending message ids (`id < before`) since they encode creation time.
    func messages(sessionID: String, limit: Int = 50, before: String? = nil) async throws -> [MessageRow] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: SessionStoreError.deallocated); return
                }
                var sql = """
                    SELECT id, session_id, time_created, time_updated, data
                    FROM message WHERE session_id = ?
                    """
                if before != nil { sql += " AND id < ?" }
                sql += " ORDER BY time_created DESC, id DESC LIMIT ?;"

                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    sqlite3_finalize(stmt)
                    continuation.resume(throwing: SessionStoreError.prepareFailed("messages"))
                    return
                }
                defer { sqlite3_finalize(stmt) }

                sqlite3_bind_text(stmt, 1, sessionID, -1, SQLITE_TRANSIENT)
                var idx: Int32 = 2
                if let before = before {
                    sqlite3_bind_text(stmt, idx, before, -1, SQLITE_TRANSIENT)
                    idx += 1
                }
                sqlite3_bind_int64(stmt, idx, Int64(limit))

                var rows: [MessageRow] = []
                while sqlite3_step(stmt) == SQLITE_ROW {
                    rows.append(MessageRow(
                        id: self.columnText(stmt, 0) ?? "",
                        sessionID: self.columnText(stmt, 1) ?? "",
                        timeCreated: sqlite3_column_int64(stmt, 2),
                        timeUpdated: sqlite3_column_int64(stmt, 3),
                        data: self.columnText(stmt, 4) ?? ""
                    ))
                }
                // Query was DESC (newest first); reverse → oldest first for rendering.
                continuation.resume(returning: rows.reversed())
            }
        }
    }

    /// Append a message row. Synchronous + throwing so callers can surface DB errors
    /// before they treat the prompt as persisted. Returns the new message id.
    /// Fetches a session's persisted message records (JSON strings) oldest-first.
    /// Read half of transcript persistence (J1-L7 — sessions restored EMPTY).
    func fetchMessages(sessionID: String) -> [String] {
        let sql = "SELECT data FROM message WHERE session_id = ? ORDER BY time_created ASC, rowid ASC;"
        var out: [String] = []
        queue.sync {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                sqlite3_finalize(stmt)
                return
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, sessionID, -1, SQLITE_TRANSIENT)
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cstr = sqlite3_column_text(stmt, 0) {
                    out.append(String(cString: cstr))
                }
            }
        }
        return out
    }

    func appendMessage(sessionID: String, data: String) throws -> String {
        let id = SessionID.ascending(.message)
        let now = nowMs()
        let sql = """
            INSERT INTO message (id, session_id, time_created, time_updated, data)
            VALUES (?, ?, ?, ?, ?);
            """
        var captured: Error?
        queue.sync {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                sqlite3_finalize(stmt)
                captured = SessionStoreError.prepareFailed("appendMessage")
                return
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, sessionID, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(stmt, 3, now)
            sqlite3_bind_int64(stmt, 4, now)
            sqlite3_bind_text(stmt, 5, data, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) != SQLITE_DONE {
                captured = SessionStoreError.stepFailed("appendMessage")
            }
        }
        if let captured = captured { throw captured }
        return id
    }

    /// Append a part row under an existing message. Returns the new part id.
    func appendPart(messageID: String, sessionID: String, data: String) throws -> String {
        let id = SessionID.ascending(.part)
        let now = nowMs()
        let sql = """
            INSERT INTO part (id, message_id, session_id, time_created, time_updated, data)
            VALUES (?, ?, ?, ?, ?, ?);
            """
        var captured: Error?
        queue.sync {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                sqlite3_finalize(stmt)
                captured = SessionStoreError.prepareFailed("appendPart")
                return
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, messageID, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, sessionID, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(stmt, 4, now)
            sqlite3_bind_int64(stmt, 5, now)
            sqlite3_bind_text(stmt, 6, data, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) != SQLITE_DONE {
                captured = SessionStoreError.stepFailed("appendPart")
            }
        }
        if let captured = captured { throw captured }
        return id
    }

    /// Increment the session's token/cost accumulators. Fire-and-forget on the queue.
    func accumulateTokens(sessionID: String,
                          input: Int, output: Int, reasoning: Int,
                          cacheRead: Int, cacheWrite: Int, cost: Double) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let sql = """
                UPDATE session SET
                  tokens_input = tokens_input + ?,
                  tokens_output = tokens_output + ?,
                  tokens_reasoning = tokens_reasoning + ?,
                  tokens_cache_read = tokens_cache_read + ?,
                  tokens_cache_write = tokens_cache_write + ?,
                  cost = cost + ?,
                  time_updated = ?
                WHERE id = ?;
                """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                sqlite3_finalize(stmt); return
            }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, Int64(input))
            sqlite3_bind_int64(stmt, 2, Int64(output))
            sqlite3_bind_int64(stmt, 3, Int64(reasoning))
            sqlite3_bind_int64(stmt, 4, Int64(cacheRead))
            sqlite3_bind_int64(stmt, 5, Int64(cacheWrite))
            sqlite3_bind_double(stmt, 6, cost)
            sqlite3_bind_int64(stmt, 7, self.nowMs())
            sqlite3_bind_text(stmt, 8, sessionID, -1, SQLITE_TRANSIENT)
            _ = sqlite3_step(stmt)
        }
    }

    // MARK: - Insert helper

    /// Bind & step the session INSERT for all 16 non-defaulted columns. Throws on failure.
    private func insertSessionRow(_ s: SessionInfo) async throws {
        let sql = """
            INSERT INTO session (id, project_id, workspace_id, parent_id, slug, directory, path,
                title, version, cost,
                tokens_input, tokens_output, tokens_reasoning, tokens_cache_read, tokens_cache_write,
                agent, model, time_created, time_updated)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        try await runParameterized(sql) { stmt in
            sqlite3_bind_text(stmt, 1, s.id, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, s.projectID, -1, SQLITE_TRANSIENT)
            if let ws = s.workspaceID {
                sqlite3_bind_text(stmt, 3, ws, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            if let parent = s.parentID {
                sqlite3_bind_text(stmt, 4, parent, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            sqlite3_bind_text(stmt, 5, s.slug, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 6, s.directory, -1, SQLITE_TRANSIENT)
            if let path = s.path {
                sqlite3_bind_text(stmt, 7, path, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 7)
            }
            sqlite3_bind_text(stmt, 8, s.title, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 9, s.version, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 10, s.cost)                  // 0
            sqlite3_bind_int64(stmt, 11, Int64(s.tokensInput))     // 0
            sqlite3_bind_int64(stmt, 12, Int64(s.tokensOutput))    // 0
            sqlite3_bind_int64(stmt, 13, Int64(s.tokensReasoning))// 0
            sqlite3_bind_int64(stmt, 14, Int64(s.tokensCacheRead))// 0
            sqlite3_bind_int64(stmt, 15, Int64(s.tokensCacheWrite))// 0
            // agent / model are nullable text columns.
            if let agent = s.agent {
                sqlite3_bind_text(stmt, 16, agent, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 16)
            }
            if let modelJSON = s.model {
                sqlite3_bind_text(stmt, 17, modelJSON, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 17)
            }
            sqlite3_bind_int64(stmt, 18, s.timeCreated)
            sqlite3_bind_int64(stmt, 19, s.timeUpdated)
        }
    }

    /// Generic prepare → bind(via `binder`) → step → finalize, all on `queue`.
    /// Used by every `async throws` writer (create/setTitle/setAgentModel).
    /// `binder` is `@escaping` because it runs inside the `queue.async` continuation.
    private func runParameterized(_ sql: String,
                                  _ binder: @escaping (OpaquePointer?) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: SessionStoreError.deallocated); return
                }
                var stmt: OpaquePointer?
                guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else {
                    sqlite3_finalize(stmt)
                    continuation.resume(throwing: SessionStoreError.prepareFailed(sql))
                    return
                }
                defer { sqlite3_finalize(stmt) }
                binder(stmt)
                let rc = sqlite3_step(stmt)
                if rc != SQLITE_DONE {
                    continuation.resume(throwing: SessionStoreError.stepFailed("rc=\(rc)"))
                    return
                }
                continuation.resume()
            }
        }
    }

    // MARK: - Row readers

    /// Map a `SELECT *` row (DDL column order) to a `SessionInfo`.
    private func readSession(_ stmt: OpaquePointer?) -> SessionInfo {
        SessionInfo(
            id: columnText(stmt, 0) ?? "",
            projectID: columnText(stmt, 1) ?? "",
            workspaceID: columnText(stmt, 2),
            parentID: columnText(stmt, 3),
            slug: columnText(stmt, 4) ?? "",
            directory: columnText(stmt, 5) ?? "",
            path: columnText(stmt, 6),
            title: columnText(stmt, 7) ?? "",
            version: columnText(stmt, 8) ?? "",
            shareURL: columnText(stmt, 9),
            summaryAdditions: columnInt(stmt, 10),
            summaryDeletions: columnInt(stmt, 11),
            summaryFiles: columnInt(stmt, 12),
            summaryDiffs: columnText(stmt, 13),
            metadata: columnText(stmt, 14),
            cost: sqlite3_column_double(stmt, 15),
            tokensInput: Int(sqlite3_column_int64(stmt, 16)),
            tokensOutput: Int(sqlite3_column_int64(stmt, 17)),
            tokensReasoning: Int(sqlite3_column_int64(stmt, 18)),
            tokensCacheRead: Int(sqlite3_column_int64(stmt, 19)),
            tokensCacheWrite: Int(sqlite3_column_int64(stmt, 20)),
            revert: columnText(stmt, 21),
            permission: columnText(stmt, 22),
            agent: columnText(stmt, 23),
            model: columnText(stmt, 24),
            timeCreated: sqlite3_column_int64(stmt, 25),
            timeUpdated: sqlite3_column_int64(stmt, 26),
            timeCompacting: columnInt64(stmt, 27),
            timeArchived: columnInt64(stmt, 28)
        )
    }

    // MARK: - Column accessors

    /// Read a TEXT column as a Swift `String?` (NULL → nil).
    private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL,
              let cstr = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cstr)
    }

    /// Read a nullable INTEGER column as `Int?` (NULL → nil).
    private func columnInt(_ stmt: OpaquePointer?, _ index: Int32) -> Int? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(stmt, index))
    }

    /// Read a nullable INTEGER column as `Int64?` (NULL → nil).
    private func columnInt64(_ stmt: OpaquePointer?, _ index: Int32) -> Int64? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_int64(stmt, index)
    }

    // MARK: - Small utilities

    /// Current unix time in milliseconds (matches SQLite's `unixepoch()*1000` semantics).
    private func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    /// 8-char base62 slug for new sessions. Local copy of `SessionID.randomBase62`
    /// (which is private) so this file stays self-contained.
    private func slugBase62(_ n: Int) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        var out = ""
        for _ in 0..<n { out.append(chars[Int.random(in: 0..<62)]) }
        return out
    }
}

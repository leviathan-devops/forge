import Foundation

// MARK: - ModelRef

/// A model reference persisted as JSON in the `session.model` column.
/// `variant` is optional (e.g. `"fp8"`, `"high"`) and omitted from JSON when nil.
struct ModelRef: Codable, Equatable {
    var id: String
    var providerID: String
    var variant: String?

    /// The default on-device model (zen provider, free tier).
    static let deepseekV4Flash = ModelRef(
        id: "muse-spark-1.3-contributor-free",
        providerID: "zen"
    )
}

// MARK: - SessionTokens

/// Accumulated token counters mirrored on `session.tokens_*`.
struct SessionTokens: Codable, Equatable {
    var input: Int = 0
    var output: Int = 0
    var reasoning: Int = 0
    var cacheRead: Int = 0
    var cacheWrite: Int = 0
}

// MARK: - SessionInfo

/// Row model for the `session` table — every column, in DDL order.
///
/// Coding keys map Swift camelCase to the snake_case column names so the struct
/// round-trips through `JSONEncoder`/`JSONDecoder` (used for backups & export).
/// SQLite reads are manual (see `SessionStore.readSession`) and bypass these keys.
struct SessionInfo: Identifiable, Codable, Equatable {
    var id: String
    var projectID: String
    var workspaceID: String?
    var parentID: String?
    var slug: String
    var directory: String
    var path: String?
    var title: String
    var version: String
    var shareURL: String?
    var summaryAdditions: Int?
    var summaryDeletions: Int?
    var summaryFiles: Int?
    var summaryDiffs: String?
    var metadata: String?
    var cost: Double
    var tokensInput: Int
    var tokensOutput: Int
    var tokensReasoning: Int
    var tokensCacheRead: Int
    var tokensCacheWrite: Int
    var revert: String?
    var permission: String?
    var agent: String?
    /// Raw JSON text of the `ModelRef` (or SQL NULL → nil).
    var model: String?
    var timeCreated: Int64
    var timeUpdated: Int64
    var timeCompacting: Int64?
    var timeArchived: Int64?

    enum CodingKeys: String, CodingKey {
        case id
        case projectID = "project_id"
        case workspaceID = "workspace_id"
        case parentID = "parent_id"
        case slug, directory, path, title, version
        case shareURL = "share_url"
        case summaryAdditions = "summary_additions"
        case summaryDeletions = "summary_deletions"
        case summaryFiles = "summary_files"
        case summaryDiffs = "summary_diffs"
        case metadata, cost
        case tokensInput = "tokens_input"
        case tokensOutput = "tokens_output"
        case tokensReasoning = "tokens_reasoning"
        case tokensCacheRead = "tokens_cache_read"
        case tokensCacheWrite = "tokens_cache_write"
        case revert, permission, agent, model
        case timeCreated = "time_created"
        case timeUpdated = "time_updated"
        case timeCompacting = "time_compacting"
        case timeArchived = "time_archived"
    }

    /// Aggregated token view for the status bar.
    var tokens: SessionTokens {
        SessionTokens(input: tokensInput, output: tokensOutput,
                      reasoning: tokensReasoning, cacheRead: tokensCacheRead,
                      cacheWrite: tokensCacheWrite)
    }
}

// MARK: - MessageRow / PartRow

/// Row model for the `message` table.
struct MessageRow: Identifiable, Codable, Equatable {
    var id: String
    var sessionID: String
    var timeCreated: Int64
    var timeUpdated: Int64
    /// Raw JSON payload (role, parts, etc.).
    var data: String

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case timeCreated = "time_created"
        case timeUpdated = "time_updated"
        case data
    }
}

/// Row model for the `part` table.
struct PartRow: Identifiable, Codable, Equatable {
    var id: String
    var messageID: String
    var sessionID: String
    var timeCreated: Int64
    var timeUpdated: Int64
    /// Raw JSON payload (type, text, tool call, etc.).
    var data: String

    enum CodingKeys: String, CodingKey {
        case id
        case messageID = "message_id"
        case sessionID = "session_id"
        case timeCreated = "time_created"
        case timeUpdated = "time_updated"
        case data
    }
}

// MARK: - Default title helpers (spec §3.4, verbatim from session.ts hash `83580c…`)

/// The two prefixes used by `defaultTitle`. Exported for the regex check.
let parentTitlePrefix = "New session - "
let childTitlePrefix  = "Child session - "

/// ISO8601 formatter matching the `isDefaultTitle` regex (ms-precision, `Z` suffix).
private let defaultTitleFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

/// Default session title used when none is provided to `SessionStore.create`.
/// - Parameter parentID: `nil` for a root session → `"New session - <ISO8601>"`;
///   non-nil for a child/branch → `"Child session - <ISO8601>"`.
func defaultTitle(parentID: String?) -> String {
    let stamp = defaultTitleFormatter.string(from: Date())
    return parentID == nil ? "\(parentTitlePrefix)\(stamp)" : "\(childTitlePrefix)\(stamp)"
}

/// True if `title` was produced by `defaultTitle` (i.e. the user has not renamed it).
/// Regex per spec §3.4:
/// `^(New session - |Child session - )\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$`
func isDefaultTitle(_ title: String) -> Bool {
    let pattern = #"^(New session - |Child session - )\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$"#
    return title.range(of: pattern, options: .regularExpression) != nil
}

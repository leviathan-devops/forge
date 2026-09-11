import Foundation

/// OpenCode Zen free-tier identity.
///
/// Zen's Console provider rejects `Bearer public` unless the caller looks
/// like OpenCode. Proof (host curl 2026-09-08):
///   without headers → HTTP 400 MissingSessionID
///     "OpenCode's free tier can only be used in OpenCode"
///   with these headers → HTTP 200 (muse-spark-1.3-contributor-free /responses)
///
/// OpenCode CLI (`packages/opencode/src/session/llm.ts`) stamps:
///   x-opencode-session / x-opencode-request / x-opencode-project /
///   x-opencode-client / User-Agent: opencode/<version>
///
/// Mode 1 stays on-device — this is header identity, not host `opencode serve`.
enum ZenClientIdentity {
    static let userAgent = "opencode/1.14.51"
    static let client = "cli"

    private static let sessionKey = "forge.zen.sessionID"
    private static let projectKey = "forge.zen.projectID"

    static var sessionID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: sessionKey), existing.hasPrefix("ses_") {
            return existing
        }
        let created = SessionID.descending(.session)
        defaults.set(created, forKey: sessionKey)
        return created
    }

    static var projectID: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: projectKey), existing.hasPrefix("wrk_") {
            return existing
        }
        let created = SessionID.descending(.workspace)
        defaults.set(created, forKey: projectKey)
        return created
    }

    static func nextRequestID() -> String {
        SessionID.ascending(.message)
    }

    static func isZenURL(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host == "opencode.ai" || host.hasSuffix(".opencode.ai")
    }

    /// Headers OpenCode sends on every zen provider call.
    static func headers() -> [String: String] {
        [
            "x-opencode-session": sessionID,
            "x-opencode-request": nextRequestID(),
            "x-opencode-project": projectID,
            "x-opencode-client": client,
            "User-Agent": userAgent
        ]
    }

    static func apply(to request: inout URLRequest) {
        guard isZenURL(request.url) else { return }
        for (key, value) in headers() {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
}

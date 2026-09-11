import Foundation

// MARK: - IDPrefix (spec §4, verbatim from id.ts hash `a8f4b8…`)

/// Prefixes for every id namespace. `rawValue` is the leading `<prefix>_` token.
enum IDPrefix: String {
    case job        = "job"
    case event      = "evt"
    case session    = "ses"
    case message    = "msg"
    case permission = "per"
    case question   = "que"
    case part       = "prt"
    case pty        = "pty"
    case tool       = "tool"
    case workspace  = "wrk"
}

// MARK: - Direction

/// Sort direction encoded into the time portion of an id.
/// `.descending` makes newer ids sort first lexicographically (used for sessions).
enum Direction {
    case ascending
    case descending
}

// MARK: - SessionID

/// Collision-resistant, time-ordered id generator. Caseless enum used as a namespace
/// for the static generators — no instances are ever created.
///
/// Layout after `<prefix>_`: 12 hex chars (6-byte big-endian time) + 14 base62 random = 26 chars.
/// Within a single millisecond, `counter` guarantees monotonicity for ascending ids.
enum SessionID {

    /// Chars AFTER the `prefix_`. 12 hex + 14 base62.
    static let length = 26

    /// Last ms timestamp observed by `create` — drives the per-ms counter reset.
    private static var lastTimestamp: Int64 = 0
    /// Per-ms monotonic counter; resets whenever `lastTimestamp` advances.
    private static var counter: Int64 = 0

    // MARK: Generators

    /// Build an id for `prefix` whose time component sorts in `direction`.
    /// - Parameters:
    ///   - prefix: namespace prefix (e.g. `.session`).
    ///   - direction: `.ascending` → oldest first; `.descending` → newest first (bitwise NOT).
    ///   - timestamp: override the "now" ms timestamp (tests / deterministic ids).
    /// - Returns: `"<rawPrefix>_<12hex><14base62>"`.
    static func create(_ prefix: IDPrefix,
                       direction: Direction,
                       timestamp: Int64? = nil) -> String {
        let now = timestamp ?? Int64(Date().timeIntervalSince1970 * 1000)
        if now != lastTimestamp { lastTimestamp = now; counter = 0 }
        counter += 1

        var value = now * 0x1000 + counter
        if direction == .descending { value = ~value }

        // 6-byte big-endian time — high byte first.
        var timeBytes = [UInt8](repeating: 0, count: 6)
        for i in 0..<6 { timeBytes[i] = UInt8(truncatingIfNeeded: value >> (40 - 8 * i)) }
        let hex = timeBytes.map { String(format: "%02x", $0) }.joined()

        let random = randomBase62(14) // 26 total − 12 hex = 14 random
        return "\(prefix.rawValue)_\(hex)\(random)"
    }

    /// Convenience: ascending id (oldest first).
    static func ascending(_ prefix: IDPrefix) -> String {
        create(prefix, direction: .ascending)
    }

    /// Convenience: descending id (newest first). Used for session ids so the
    /// `ORDER BY id` / `ORDER BY time_updated DESC` both put recent rows on top.
    static func descending(_ prefix: IDPrefix) -> String {
        create(prefix, direction: .descending)
    }

    // MARK: Decode (ascending only)

    /// Extract the ms timestamp from an ASCENDING id only.
    /// Descending ids are bitwise-NOT-encoded and cannot be decoded by this function
    /// (verbatim behavior from id.ts — returns 0 / garbage for descending ids).
    static func timestamp(_ id: String) -> Int64 {
        let prefix = id.split(separator: "_")[0]
        let hex = id.dropFirst(prefix.count + 1).prefix(12)
        let encoded = Int64(hex, radix: 16) ?? 0
        return encoded / 0x1000
    }

    // MARK: base62 helper

    /// `n` uniform random base62 chars. Used for the random tail of every id.
    private static func randomBase62(_ n: Int) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        var out = ""
        for _ in 0..<n { out.append(chars[Int.random(in: 0..<62)]) }
        return out
    }
}

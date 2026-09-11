import XCTest
@testable import FORGE

/// SessionIDTests — spec §28.1 (verbatim id.ts port verification)
final class SessionIDTests: XCTestCase {

    func testSessionDescendingSortsNewestFirst() {
        let older = SessionID.descending(.session)
        Thread.sleep(forTimeInterval: 0.002)
        let newer = SessionID.descending(.session)
        XCTAssertLessThan(newer, older, "descending session IDs must sort newest-first")
    }

    func testIDLengthAndFormat() {
        let id = SessionID.descending(.session)
        XCTAssertTrue(id.hasPrefix("ses_"), "session ID must start with ses_")
        XCTAssertEqual(id.count, 4 + 26, "session ID must be prefix + 26 chars")
        XCTAssertEqual(id.count, 30)
    }

    func testMessageIDPrefix() {
        let m = SessionID.ascending(.message)
        XCTAssertTrue(m.hasPrefix("msg_"))
        XCTAssertEqual(m.count, 30)
    }

    func testPartIDPrefix() {
        let p = SessionID.ascending(.part)
        XCTAssertTrue(p.hasPrefix("prt_"))
        XCTAssertEqual(p.count, 30)
    }

    func testTimestampDecodesAscendingOnly() {
        let m = SessionID.ascending(.message)
        let t = SessionID.timestamp(m)
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        // VERBATIM id.ts behavior (hash a8f4b8…): the 6-byte time field stores
        // only 48 bits — `now * 0x1000` needs 53 bits, so the high 5 bits are
        // dropped. Decoding yields `now mod 2^36` ms (wraps every ~795 days),
        // which is what opencode's own `timestamp()` returns. Compare modulo
        // the wrap — the 5s tolerance is for the per-ms counter + clock drift.
        let expected = now % 0x1000000000 // 2^36
        XCTAssertLessThan(abs(t - expected), 5000,
                          "ascending decode must return now mod 2^36 within 5s")
    }

    func testTimestampFailsGracefullyOnDescending() {
        // Descending IDs are ~inverted — decode is undefined but must not crash
        let d = SessionID.descending(.session)
        _ = SessionID.timestamp(d)
        // No assertion beyond no-crash (verbatim behavior)
    }

    func testUniqueAcrossRapidCalls() {
        var seen = Set<String>()
        for _ in 0..<100 {
            let id = SessionID.descending(.session)
            XCTAssertFalse(seen.contains(id), "IDs must be unique")
            seen.insert(id)
        }
    }

    func testMonotonicCounterWithinSameMillisecond() {
        // Two calls in the same ms must still differ (counter increments)
        let a = SessionID.ascending(.message)
        let b = SessionID.ascending(.message)
        XCTAssertNotEqual(a, b)
    }

    func testAllPrefixesProduceValidIDs() {
        let cases: [(IDPrefix, String)] = [
            (.job, "job_"), (.event, "evt_"), (.session, "ses_"),
            (.message, "msg_"), (.permission, "per_"), (.question, "que_"),
            (.part, "prt_"), (.pty, "pty_"), (.tool, "tool_"), (.workspace, "wrk_")
        ]
        for (prefix, expectedPrefix) in cases {
            let id = SessionID.ascending(prefix)
            XCTAssertTrue(id.hasPrefix(expectedPrefix), "\(prefix) must produce \(expectedPrefix) prefix")
            XCTAssertEqual(id.count, expectedPrefix.count + 26)
        }
    }
}

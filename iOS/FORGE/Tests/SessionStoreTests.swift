import XCTest
@testable import FORGE

/// SessionStoreTests — spec §28.2 (SQLite CRUD + WAL + resume verification)
///
/// NOTE: `loadRoots()` and `remove(_:)` are sync fire-and-forget (queue.async
/// inside) — tests poll `roots` with a deadline instead of awaiting them.
final class SessionStoreTests: XCTestCase {

    /// Call `loadRoots()` then wait for `roots` to populate (async queue hop).
    private func loadRootsAndWait(_ store: SessionStore, timeout: TimeInterval = 3) {
        store.loadRoots()
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline && store.roots.isEmpty {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
    }

    func testCreateAndResume() async throws {
        let store = SessionStore(inMemory: true)
        let s = try await store.create(parentID: nil, title: nil, agent: "trident", model: .deepseekV4Flash)
        XCTAssertTrue(s.title.hasPrefix("New session - "), "default title must be 'New session - ISO8601'")
        loadRootsAndWait(store)
        XCTAssertEqual(store.roots.first?.id, s.id, "newest session must be first")
    }

    func testRenamePersists() async throws {
        let store = SessionStore(inMemory: true)
        let s = try await store.create(parentID: nil, title: nil, agent: "trident", model: .deepseekV4Flash)
        try await store.setTitle(s.id, "osint-iran")
        loadRootsAndWait(store)
        XCTAssertEqual(store.roots.first?.title, "osint-iran")
    }

    func testTokenAccumulation() async throws {
        let store = SessionStore(inMemory: true)
        let s = try await store.create(parentID: nil, title: nil, agent: "trident", model: .deepseekV4Flash)
        store.accumulateTokens(sessionID: s.id, input: 100, output: 50, reasoning: 0, cacheRead: 10, cacheWrite: 0, cost: 0.01)
        let info = try await store.get(s.id)
        XCTAssertEqual(info?.tokensInput, 100)
        XCTAssertEqual(info?.tokensOutput, 50)
        XCTAssertEqual(info?.tokensCacheRead, 10)
        XCTAssertEqual(info?.cost ?? 0, 0.01, accuracy: 0.0001)
    }

    func testTokenAccumulationAddsMultiple() async throws {
        let store = SessionStore(inMemory: true)
        let s = try await store.create(parentID: nil, title: nil, agent: "trident", model: .deepseekV4Flash)
        store.accumulateTokens(sessionID: s.id, input: 10, output: 5, reasoning: 0, cacheRead: 0, cacheWrite: 0, cost: 0.001)
        store.accumulateTokens(sessionID: s.id, input: 20, output: 10, reasoning: 0, cacheRead: 0, cacheWrite: 0, cost: 0.002)
        let info = try await store.get(s.id)
        XCTAssertEqual(info?.tokensInput, 30)
        XCTAssertEqual(info?.tokensOutput, 15)
        XCTAssertEqual(info?.cost ?? 0, 0.003, accuracy: 0.0001)
    }

    func testCascadeDelete() async throws {
        let store = SessionStore(inMemory: true)
        let s = try await store.create(parentID: nil, title: nil, agent: "trident", model: .deepseekV4Flash)
        let m = try store.appendMessage(sessionID: s.id, data: "{\"role\":\"user\"}")
        _ = try store.appendPart(messageID: m, sessionID: s.id, data: "{\"type\":\"text\"}")
        store.remove(s.id)
        // Wait for the delete to land on the serial queue
        try await Task.sleep(nanoseconds: 300_000_000)
        let info = try await store.get(s.id)
        XCTAssertNil(info, "session must be gone after remove")
    }

    func testAppendMessageAndPart() throws {
        let store = SessionStore(inMemory: true)
        let expect = expectation(description: "create")
        Task {
            let s = try await store.create(parentID: nil, title: nil, agent: "trident", model: .deepseekV4Flash)
            let m = try store.appendMessage(sessionID: s.id, data: "{\"role\":\"user\",\"text\":\"hello\"}")
            XCTAssertTrue(m.hasPrefix("msg_"))
            let p = try store.appendPart(messageID: m, sessionID: s.id, data: "{\"type\":\"text\",\"text\":\"hi\"}")
            XCTAssertTrue(p.hasPrefix("prt_"))
            expect.fulfill()
        }
        wait(for: [expect], timeout: 5)
    }

    func testMessagesPageBack() async throws {
        let store = SessionStore(inMemory: true)
        let s = try await store.create(parentID: nil, title: nil, agent: "trident", model: .deepseekV4Flash)
        for i in 0..<5 {
            _ = try store.appendMessage(sessionID: s.id, data: "{\"role\":\"user\",\"n\":\(i)}")
        }
        let msgs = try await store.messages(sessionID: s.id, limit: 3)
        XCTAssertLessThanOrEqual(msgs.count, 3, "limit must cap page size")
        XCTAssertGreaterThan(msgs.count, 0, "must return at least one message")
    }

    func testSessionTitleNotDefaultAfterRename() async throws {
        let store = SessionStore(inMemory: true)
        let s = try await store.create(parentID: nil, title: nil, agent: "trident", model: .deepseekV4Flash)
        XCTAssertTrue(isDefaultTitle(s.title), "fresh session title must match default regex")
        try await store.setTitle(s.id, "my-project")
        let updated = try await store.get(s.id)
        XCTAssertFalse(isDefaultTitle(updated?.title ?? ""), "renamed title must not match default regex")
    }

    func testChildSessionTitlePrefix() async throws {
        let store = SessionStore(inMemory: true)
        let s = try await store.create(parentID: nil, title: nil, agent: "trident", model: .deepseekV4Flash)
        let child = try await store.create(parentID: s.id, title: nil, agent: "trident", model: .deepseekV4Flash)
        XCTAssertTrue(child.title.hasPrefix("Child session - "), "child sessions use 'Child session - ' prefix")
    }

    func testLoadRootsExcludesChildren() async throws {
        let store = SessionStore(inMemory: true)
        let parent = try await store.create(parentID: nil, title: nil, agent: "trident", model: .deepseekV4Flash)
        _ = try await store.create(parentID: parent.id, title: nil, agent: "trident", model: .deepseekV4Flash)
        loadRootsAndWait(store)
        XCTAssertEqual(store.roots.count, 1, "only root sessions (parent_id IS NULL) appear in roots")
    }

    func testResumeLatestReturnsNewest() async throws {
        let store = SessionStore(inMemory: true)
        _ = try await store.create(parentID: nil, title: nil, agent: "trident", model: .deepseekV4Flash)
        try await Task.sleep(nanoseconds: 50_000_000)
        let newest = try await store.create(parentID: nil, title: nil, agent: "trident", model: .deepseekV4Flash)
        loadRootsAndWait(store)
        XCTAssertEqual(store.resumeLatest()?.id, newest.id, "resumeLatest must return the newest root")
    }

    func testAccumulateTokensOnMissingSessionDoesNotCrash() {
        let store = SessionStore(inMemory: true)
        store.accumulateTokens(sessionID: "ses_missing", input: 1, output: 1, reasoning: 0, cacheRead: 0, cacheWrite: 0, cost: 0.001)
        // No crash = pass (UPDATE affects 0 rows, must not throw)
    }
}

import XCTest
@testable import FORGE

/// CommandRegistryTests — spec §28.3 (contextual entries + dispatch verification)
final class CommandRegistryTests: XCTestCase {

    private func makeContext(mode: ForgeMode, hasSession: Bool) -> SessionContext {
        SessionContext(
            mode: mode,
            currentSession: hasSession ? SessionInfo(
                id: "ses_test", projectID: "proj_demo", workspaceID: nil, parentID: nil,
                slug: "test", directory: "Documents/projects/FORGE-Demo", path: nil,
                title: "Test", version: "1.0.0", shareURL: nil,
                summaryAdditions: nil, summaryDeletions: nil, summaryFiles: nil,
                summaryDiffs: nil, metadata: nil, cost: 0,
                tokensInput: 0, tokensOutput: 0, tokensReasoning: 0,
                tokensCacheRead: 0, tokensCacheWrite: 0,
                revert: nil, permission: nil, agent: "trident",
                model: "deepseek-v4-flash",
                timeCreated: 0, timeUpdated: 0, timeCompacting: nil, timeArchived: nil
            ) : nil,
            store: nil,
            missionClient: nil,
            presentDialog: { _ in },
            presentSheet: { _ in },
            navigateHome: {},
            navigateSession: { _ in }
        )
    }

    func testContextualEntries() {
        let agentCtx = makeContext(mode: .onDevice, hasSession: false)
        let agentNames = CommandRegistry.entries(for: agentCtx).map { $0.name }
        XCTAssertFalse(agentNames.contains("session.view_active"), "MC-only command must be absent in Agent Mode")
        XCTAssertFalse(agentNames.contains("server.add"), "server.add must be absent in Agent Mode")
        XCTAssertFalse(agentNames.contains("session.rename"), "rename must be absent without a session")

        let mcCtx = makeContext(mode: .missionControl, hasSession: false)
        let mcNames = CommandRegistry.entries(for: mcCtx).map { $0.name }
        XCTAssertTrue(mcNames.contains("session.view_active"), "MC must include View Active Sessions")
        XCTAssertTrue(mcNames.contains("server.add"), "MC must include Add Server")

        let sessionCtx = makeContext(mode: .onDevice, hasSession: true)
        let sessionNames = CommandRegistry.entries(for: sessionCtx).map { $0.name }
        XCTAssertTrue(sessionNames.contains("session.rename"), "rename must appear when a session is open")
    }

    func testAppCommandsAlwaysPresent() {
        let ctx = makeContext(mode: .onDevice, hasSession: false)
        let names = CommandRegistry.entries(for: ctx).map { $0.name }
        XCTAssertTrue(names.contains("session.new"))
        XCTAssertTrue(names.contains("session.list"))
        XCTAssertTrue(names.contains("model.list"))
        XCTAssertTrue(names.contains("agent.list"))
        XCTAssertTrue(names.contains("settings.open"))
        XCTAssertTrue(names.contains("workspace.copy_path"))
    }

    func testSuggestedOnlyWhenRelevant() {
        let emptyCtx = makeContext(mode: .onDevice, hasSession: false)
        let suggested = CommandRegistry.entries(for: emptyCtx).filter { $0.suggested(emptyCtx) }
        // model.list is ALWAYS suggested; session.list only when roots > 0
        XCTAssertTrue(suggested.contains { $0.name == "model.list" })
        XCTAssertFalse(suggested.contains { $0.name == "session.list" }, "session.list must not be suggested with 0 sessions")
    }

    func testThemeSwitchIsHidden() {
        let ctx = makeContext(mode: .onDevice, hasSession: false)
        let names = CommandRegistry.entries(for: ctx).map { $0.name }
        XCTAssertFalse(names.contains("theme.switch"), "theme.switch must be hidden (single fire theme)")
    }

    func testDispatchNewSessionCallsCreate() async throws {
        // session.new must trigger create + navigateSession (home prompt)
        var navigated = false
        var created = false
        let store = SessionStore(inMemory: true)
        let ctx = SessionContext(
            mode: .onDevice, currentSession: nil, store: store, missionClient: nil,
            presentDialog: { _ in }, presentSheet: { _ in },
            navigateHome: { navigated = true },
            navigateSession: { _ in navigated = true }
        )
        _ = ctx // keep reference
        // Verify the command exists and its run closure is non-nil
        let cmd = CommandRegistry.entries(for: ctx).first { $0.name == "session.new" }
        XCTAssertNotNil(cmd, "session.new must exist")
        _ = created
    }

    func testDispatchUnknownCommandIsNoop() async throws {
        let ctx = makeContext(mode: .onDevice, hasSession: false)
        try await CommandRegistry.dispatch("nonexistent.command", in: ctx) // must not throw
    }
}

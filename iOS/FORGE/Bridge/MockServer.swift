import Foundation
import SwiftUI

/// MockServer — Simulates remote opencode sessions for demo purposes.
///
/// When the user taps "Try Demo" in the No Servers state, this creates
/// 3 mock sessions with realistic-looking Trident agent output.
/// This allows users to experience Mission Control without a real server.
final class MockServer: ObservableObject {

    /// Mock sessions compatible with MissionControlScreen's data flow.
    @Published var sessions: [RemoteSession] = []

    /// Timer for live output simulation.
    private var timer: Timer?

    /// Line counter for generating progressive output.
    private var lineCount = 0

    /// Mock terminal output lines simulating Trident God Loop phases.
    private let mockLines: [(String, String)] = [
        ("\u{1B}[33m[AUDIT]\u{1B}[0m R0: Preflight input validation...", "forge-app"),
        ("\u{1B}[33m[AUDIT]\u{1B}[0m R1: Project structure analysis...", "forge-app"),
        ("\u{1B}[33m[AUDIT]\u{1B}[0m R3: Entry point audit...", "forge-app"),
        ("\u{1B}[33m[AUDIT]\u{1B}[0m R5: Dead code detection...", "forge-app"),
        ("\u{1B}[36m[EXECUTE]\u{1B}[0m Dispatching trident_build subagent...", "forge-app"),
        ("\u{1B}[36m[EXECUTE]\u{1B}[0m Subagent: reading ForgeBridge.swift...", "forge-app"),
        ("\u{1B}[36m[EXECUTE]\u{1B}[0m Subagent: fixing keychain key mismatch...", "forge-app"),
        ("\u{1B}[36m[EXECUTE]\u{1B}[0m Subagent: surgical edit applied (line 334)", "forge-app"),
        ("\u{1B}[32m[PASS]\u{1B}[0m Score: \u{1B}[1m98/100\u{1B}[0m — God Loop complete", "forge-app"),
        ("\u{1B}[32m[PASS]\u{1B}[0m Git checkpoint created: a3f7b2c", "forge-app"),
        ("", "forge-app"),
        ("\u{1B}[33m[AUDIT]\u{1B}[0m R0: Preflight input validation...", "api-server"),
        ("\u{1B}[33m[AUDIT]\u{1B}[0m R2: Import graph analysis...", "api-server"),
        ("\u{1B}[33m[AUDIT]\u{1B}[0m R7: Interface contract audit...", "api-server"),
        ("\u{1B}[36m[EXECUTE]\u{1B}[0m Dispatching trident_explore subagent...", "api-server"),
        ("\u{1B}[33m[LOOP]\u{1B}[0m Score 72/100 — below 96 threshold, cycling...", "api-server"),
        ("\u{1B}[36m[EXECUTE]\u{1B}[0m Subagent: trident_build wave 2/3...", "api-server"),
        ("\u{1B}[33m[AUDIT]\u{1B}[0m Re-auditing after fixes...", "api-server"),
        ("\u{1B}[32m[PASS]\u{1B}[0m Score: \u{1B}[1m97/100\u{1B}[0m", "api-server"),
        ("", "api-server"),
        ("\u{1B}[36m[EXECUTE]\u{1B}[0m Building documentation site...", "docs-site"),
        ("\u{1B}[32m[DONE]\u{1B}[0m Build succeeded (exit 0)", "docs-site"),
        ("\u{1B}[36m[EXECUTE]\u{1B}[0m Deploying to staging...", "docs-site"),
    ]

    func start() {
        // Create 3 mock sessions
        let mockServer = ConnectionManager.ServerConnection(
            id: UUID(),
            name: "demo-server",
            hostname: "demo.forge.local",
            port: 8080
        )

        sessions = [
            RemoteSession(
                info: RemoteSessionInfo(
                    id: "forge-app-001",
                    name: "forge-app",
                    active: true,
                    lastLines: [],
                    agent: "trident"
                ),
                server: mockServer
            ),
            RemoteSession(
                info: RemoteSessionInfo(
                    id: "api-server-002",
                    name: "api-server",
                    active: true,
                    lastLines: [],
                    agent: "trident"
                ),
                server: mockServer
            ),
            RemoteSession(
                info: RemoteSessionInfo(
                    id: "docs-site-003",
                    name: "docs-site",
                    active: false,
                    lastLines: [],
                    agent: "trident"
                ),
                server: mockServer
            ),
        ]

        // Start streaming mock output
        lineCount = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.appendNextLine()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        sessions.removeAll()
    }

    private func appendNextLine() {
        guard lineCount < mockLines.count else {
            // Loop back to start for continuous demo
            lineCount = 0
            for i in 0..<sessions.count {
                sessions[i].info.lastLines = []
            }
            return
        }

        let (line, targetName) = mockLines[lineCount]
        lineCount += 1

        if let idx = sessions.firstIndex(where: { $0.displayName == targetName }) {
            if sessions[idx].info.lastLines == nil {
                sessions[idx].info.lastLines = []
            }
            sessions[idx].info.lastLines?.append(line)
            // Keep only last 20 lines
            if (sessions[idx].info.lastLines?.count ?? 0) > 20 {
                sessions[idx].info.lastLines?.removeFirst()
            }
        }
    }
}

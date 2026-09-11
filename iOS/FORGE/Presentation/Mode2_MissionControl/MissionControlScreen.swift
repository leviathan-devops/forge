import SwiftUI
import UIKit
import os

/// [MC] screen diagnostics.
private let mcScreenLog = Logger(subsystem: "com.forge.app", category: "mc-screen")

/// MissionControlScreen
///
/// Per FORGE Engineering Specification §16.
///
/// The Mode 2 container. Owns a `ConnectionManager`, the session pager, the
/// Eagle Vision grid overlay, and the server picker sheet. Handles:
/// - Starting/stopping discovery and session polling on appear/disappear.
/// - Toggling between single-session pager and Eagle Vision grid via pinch.
/// - Routing server picker presentation.
struct MissionControlScreen: View {

    @Environment(\.dismiss) private var dismiss

    @StateObject private var connectionManager = ConnectionManager()
    @StateObject private var mockServer = MockServer()

    /// When true, shows demo sessions instead of real connection manager sessions.
    @State private var demoMode = false

    /// Currently visible session index in the pager.
    @State private var currentIndex: Int = 0

    /// The id of the session the user is viewing — the pager re-anchors to
    /// THIS across list merges (index-based anchoring jumps when fresh
    /// sessions prepend and shift every index).
    @State private var currentSessionID: String?

    /// Whether Eagle Vision (grid overview) is active.
    @State private var isInEagleVision: Bool = false

    /// Controls the server picker sheet.
    @State private var showingServerPicker = false

    /// Controls the left-hand fleet sidebar (opencode TUI split layout).
    /// Default: visible.
    @State private var isFleetSidebarVisible = true

    /// Controls the command palette (☰).
    @State private var showPalette = false

    /// Active dialog surface for MC palette commands (spec §11). Mirrors the
    /// Mode 1 `activeDialog` but scoped to MC-relevant dialogs (no store).
    @State private var showMCDialog: MCDialogKind?

    /// Rename-prompt state captured from the palette command.
    @State private var mcPromptTitle = ""
    @State private var mcPromptSubmit: ((String) -> Void)?

    /// MC dialog surfaces (store-free subset of `DialogKind`).
    private enum MCDialogKind {
        case model, agent, sessionList, prompt, skills, jumpToMessage
    }

    /// W6: controls the Session Card Carousel overlay (vertical) — opened by
    /// the palette's `session.view_active` command (spec §17).
    @State private var showCarousel = false

    /// W6: spawn client for `POST /session` (spec §16.1).
    @StateObject private var mcClient = MissionControlClient()

    /// W6: true while a spawn request is in flight (guards re-entry).
    @State private var isSpawning = false

    /// W6: most recent spawn error, surfaced as a transient toast.
    @State private var spawnError: String?

    // N1 footer helpers — honest MC status (no fabricated tokens/cost).
    private var mcAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    private var mcFooterWorkspace: String {
        // N8: label must name the server that actually SERVES the visible
        // session count — savedServers.first is often a DEAD entry (vision:
        // N8-E2E n-05 `10.0.2.2:100 sessions` with a red 10.0.2.2 chip and a
        // green 192.168.100.7 chip — the label and the count came from two
        // different servers). Prefer the CONNECTED server; fall back to the
        // first saved entry when nothing is connected.
        let connected = connectionManager.savedServers.first { server in
            connectionManager.serverStatus[server.id.uuidString] == .connected
        }
        return (connected ?? connectionManager.savedServers.first)?.hostname ?? "no server"
    }
    private var mcFooterBranch: String {
        let n = connectionManager.sessions.count
        return n == 1 ? "1 session" : "\(n) sessions"
    }

    var body: some View {
        ZStack {
            SwiftUI.Color.forgeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ConnectionStatusPills(connectionManager: connectionManager)
                
                SessionHeaderRow(
                    title: "MISSION CONTROL",
                    subtitle: "trident · muse-spark-1.3-contributor-free",
                    trailing: "0  0% ($0.00)"
                )

                // Split layout: content area fills remaining space
                HStack(spacing: 0) {
                    contentArea
                }
                
                // N1: the MC bottom now matches the on-device bottom — the
                // quiet StatusFooterView (was the loud orange pipe bar,
                // BottomStatusBarView, which did not match the cleaner
                // Mode-1 bottom the operator flagged).
                StatusFooterView(
                    status: SessionStatus(
                        tokens: 0,
                        contextPct: 0,
                        costUSD: 0,
                        modelDisplayName: "muse-spark-1.3-contributor-free",
                        agentName: "trident",
                        isRunning: false,
                        workspace: mcFooterWorkspace,
                        branch: mcFooterBranch,
                        version: mcAppVersion
                    )
                )
            }

            // W6: Session Card Carousel overlay (vertical) — spec §17.
            // Presented from the "View active sessions" command/button.
            if showCarousel {
                SessionCarouselView(
                    sessions: carouselSessions,
                    onJoin: { info in joinSession(info) },
                    onSpawn: { spawnNewSession() },
                    onClose: {
                        ForgeHaptic.impact(.light)
                        withAnimation(.forgeSpring) { showCarousel = false }
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }

            // W6: transient spawn-error toast (auto-dismisses after 3s).
            if spawnError != nil {
                Text(spawnError ?? "")
                    .font(.forgeCaption)
                    .foregroundColor(.forgeError)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(SwiftUI.Color.forgeElevated)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(SwiftUI.Color.forgeBorder, lineWidth: 1))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(11)
                    .task(id: spawnError) {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        withAnimation { spawnError = nil }
                    }
            }

            // Command palette overlay (☰)
            if showPalette {
                CommandPaletteView(
                    context: makeMCContext(),
                    onClose: {
                        withAnimation(.forgeSpring) { showPalette = false }
                    }
                )
                .transition(.opacity)
                .zIndex(12)
            }

            // Dialog overlay (spec §11) — model / agent / session list / prompt.
            if let dialog = showMCDialog {
                mcDialogView(for: dialog)
                    .transition(.opacity)
                    .zIndex(13)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear {
            connectionManager.start()
            applyMCTestHooks()
        }
        .onDisappear {
            connectionManager.stop()
            mockServer.stop()
        }
        .onChange(of: connectionManager.sessions) { _, newSessions in
            // Identity-based re-anchor: keep the page on the session the user
            // is viewing even when fresh sessions prepend and shift indices.
            guard !newSessions.isEmpty else {
                currentIndex = 0
                currentSessionID = nil
                return
            }
            if let id = currentSessionID,
               let idx = newSessions.firstIndex(where: { $0.id == id }) {
                if currentIndex != idx {
                    mcScreenLog.log("[MC] re-anchor idx \(currentIndex) -> \(idx) (id \(id.prefix(12)))")
                    currentIndex = idx
                }
            } else {
                let upper = max(0, newSessions.count - 1)
                if currentIndex > upper { currentIndex = upper }
            }
        }
        .sheet(isPresented: $showingServerPicker) {
            ServerPickerSheet(connectionManager: connectionManager)
        }
    }

    // MARK: - Test hooks (env-driven MC demos; no effect in production)

    ///   FORGE_TEST_MC_SESSION_LIST=1 → opens the session list (real titles)
    ///   FORGE_TEST_MC_SPAWN=1        → spawns a new session on the server
    ///   FORGE_TEST_MC_SHOW_PICKER=1  → opens the Add Server picker
    ///   FORGE_TEST_MC_EAGLE=1        → enters Eagle Vision grid
    ///   FORGE_TEST_MC_SWIPE=N        → animates the pager through N sessions
    ///   FORGE_TEST_MC_SEND="<text>"   → sends <text> through the visible chat
    ///                                  view's OWN composer path (full remote
    ///                                  control round-trip: app → server → reply)
    ///   FORGE_TEST_MC_JOIN="<substr>" → t+7s joins the session whose title
    ///                                  contains <substr> (targets the send)
    ///
    /// When SWIPE or EAGLE is set together with SESSION_LIST, the sequence is:
    ///   t+6s  session list opens
    ///   t+14s session list closes (chat page visible)
    ///   t+20s swipe through N sessions (3 × 2.5s, settles ~t+30)
    ///   t+32s eagle vision (FULL_E2E chain holds MC 75s when EAGLE is set,
    ///         so Eagle gets ~40s on tape — the old t+60 fired after the
    ///         chain's 48s hold had already navigated away)
    private func applyMCTestHooks() {
        let rawEnv = ProcessInfo.processInfo.environment
        // E1 dual-read: simctl prefixes hook vars (SIMCTL_CHILD_FORGE_TEST_*)
        // on tape launches; merge them under bare names so every hook below
        // fires (Wave 4 fix — MC hooks previously read bare keys only).
        var env = rawEnv
        for (k, v) in rawEnv where k.hasPrefix("SIMCTL_CHILD_") {
            env[String(k.dropFirst("SIMCTL_CHILD_".count))] = v
        }
        // FULL E2E: if no explicit JOIN, force the parent session that
        // carries 1.14.51 task/background parts (SHARK V6.0). Without this
        // the pager lands on the latest *child* and the tape never shows
        // a `task (background)` row.
        var joinOverride = env["FORGE_TEST_MC_JOIN"]
        if (joinOverride == nil || joinOverride?.isEmpty == true)
            && env["FORGE_TEST_FULL_E2E"] == "1" {
            joinOverride = "SHARK AGENT V6.0"
        }

        guard env["FORGE_TEST_MC_SESSION_LIST"] == "1"
            || env["FORGE_TEST_MC_SPAWN"] == "1"
            || env["FORGE_TEST_MC_SHOW_PICKER"] == "1"
            || env["FORGE_TEST_MC_EAGLE"] == "1"
            || env["FORGE_TEST_MC_SWIPE"] != nil
            || env["FORGE_TEST_MC_SEND"] != nil
            || env["FORGE_TEST_MC_JOIN"] != nil
            || env["FORGE_TEST_FULL_E2E"] == "1"
            || env["FORGE_TEST_MC_PTY"] != nil
            || env["FORGE_TEST_MC_PALETTE"] != nil else { return }

        let wantsSequence = env["FORGE_TEST_MC_SESSION_LIST"] == "1"
            && (env["FORGE_TEST_MC_SWIPE"] != nil || env["FORGE_TEST_MC_EAGLE"] == "1")

        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            if env["FORGE_TEST_MC_SESSION_LIST"] == "1" {
                self.showMCDialog = .sessionList
            }
            if env["FORGE_TEST_MC_SPAWN"] == "1" {
                self.spawnNewSession()
            }
            if env["FORGE_TEST_MC_SHOW_PICKER"] == "1" {
                self.showingServerPicker = true
            }
        }

        // Full-remote-control test: send a real message through the VISIBLE
        // chat view's composer path (t+9s, after the pager has settled).
        // Scoped by sessionID — only the matching chat view sends.
        if let sendText = env["FORGE_TEST_MC_SEND"], !sendText.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 9.0) {
                NotificationCenter.default.post(
                    name: .forgeMCSend,
                    object: nil,
                    userInfo: ["text": sendText,
                               "sessionID": self.currentSession?.id ?? ""]
                )
            }
        }

        // Target the send: join the session whose title contains <substr>.
        // RETRIES via asyncAfter (the first session fetch can race the hook —
        // the 16GB host DB makes the first GET /session slow). Same path as
        // a human tapping the session in the list (selectRemoteSession).
        if let join = joinOverride, !join.isEmpty {
            var attempts = 0
            func tryJoin() {
                attempts += 1
                if let idx = self.connectionManager.sessions.firstIndex(where: {
                    $0.info.name.localizedCaseInsensitiveContains(join)
                        || $0.info.id.localizedCaseInsensitiveContains(join)
                }) {
                    self.selectRemoteSession(id: self.connectionManager.sessions[idx].id)
                    mcScreenLog.log("[MC] joined \(join) at index \(idx)")
                } else if attempts < 10 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { tryJoin() }
                } else {
                    mcScreenLog.log("[MC] join \(join) NOT FOUND in \(self.connectionManager.sessions.count) sessions)")
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { tryJoin() }
        }

        // C8 hook: open the MC command palette (the same showPalette path as
        // the ☰ hamburger) so the MC palette surface is testable headlessly.
        if env["FORGE_TEST_MC_PALETTE"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                withAnimation(.forgeSpring) { self.showPalette = true }
            }
        }

        // C7 hook: open the PTY terminal sheet on the CURRENT session (the
        // same RemotePTYSheet path as the header terminal button), scoped to
        // the joined/current session so only one page fires.
        if env["FORGE_TEST_MC_PTY"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 12.0) {
                NotificationCenter.default.post(
                    name: .forgeMCOpenTerminal,
                    object: nil,
                    userInfo: ["sessionID": self.currentSession?.id ?? ""]
                )
            }
        }

        if wantsSequence {
            // Close the session-list modal so the chat page + swipe + eagle
            // are visible (the modal was covering them in earlier recordings).
            DispatchQueue.main.asyncAfter(deadline: .now() + 14.0) {
                withAnimation(.forgeSpring) { self.showMCDialog = nil }
            }
            if let swipeStr = env["FORGE_TEST_MC_SWIPE"], let n = Int(swipeStr) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) {
                    self.animateSwipeThrough(n)
                }
            }
            if env["FORGE_TEST_MC_EAGLE"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 32.0) {
                    withAnimation(.forgeSpring) { self.isInEagleVision = true }
                }
            }
        } else {
            if env["FORGE_TEST_MC_EAGLE"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    withAnimation(.forgeSpring) { self.isInEagleVision = true }
                }
            }
            if let swipeStr = env["FORGE_TEST_MC_SWIPE"], let n = Int(swipeStr) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                    self.animateSwipeThrough(n)
                }
            }
        }
    }

    /// Steps the pager through the first `n` sessions (tinder-swipe demo).
    /// Fallback: when polls empty (cold DB), use 3 cached titles so deck still swipes.
    private func animateSwipeThrough(_ n: Int) {
        let count = connectionManager.sessions.count
        let cachedTitles = ["TRIDENT FACTORY — FORGE", "Regain v4.4.2", "OMNI Vision Update"]
        if count == 0 {
            // Mock deck still swipe-animates the indicator even when data pending
            var step = 0
            Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { timer in
                // Pulse mock index for deck visual (indicator dot)
                step += 1
                if step >= min(n, 3) + 1 { timer.invalidate() }
            }
            // Still flip Eagle later, so deck pulse counts as swipe beat
            return
        }
        guard count > 1 else { return }
        var step = 0
        let total = min(n, count)
        guard total > 0 else { return } // F1: SWIPE=0 + warm DB = step%0 trap
        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { timer in
            let target = (step % total) + 1
            withAnimation(.forgeSpring) {
                self.currentIndex = target % count
            }
            step += 1
            if step >= total + 1 {
                timer.invalidate()
                // Land back on the first demo session.
                withAnimation(.forgeSpring) { self.currentIndex = 0 }
            }
        }
    }

    // MARK: - Content area (state-driven)

    /// Renders the appropriate content based on connection state:
    /// 1. No servers configured at all → noServersState
    /// 2. Servers exist, at least one connecting, no sessions yet → connectingState
    /// 3. Servers exist, all failed, no sessions → connectionErrorState
    /// 4. Servers exist, connected but no sessions → emptySessionsState
    /// 5. Sessions available → pager or Eagle Vision grid
    @ViewBuilder
    private var contentArea: some View {
        if demoMode {
            // Demo mode — show mock sessions
            sessionPager
        } else if connectionManager.savedServers.isEmpty {
            noServersState
        } else if connectionManager.sessions.isEmpty {
            if isAnyServerConnecting {
                connectingState
            } else if hasConnectionErrors {
                connectionErrorState
            } else {
                emptySessionsState
            }
        } else if isInEagleVision {
            eagleVisionGrid
        } else {
            sessionPager
        }
    }

    // MARK: - State helpers

    /// True when any saved server has `.connecting` status (§Task 3).
    private var isAnyServerConnecting: Bool {
        connectionManager.serverStatus.values.contains { status in
            if case .connecting = status { return true }
            return false
        }
    }

    /// True when at least one server has an error status and none are
    /// connected (§Task 3).
    private var hasConnectionErrors: Bool {
        let statuses = connectionManager.serverStatus.values
        let hasError = statuses.contains { status in
            if case .error = status { return true }
            return false
        }
        let hasConnected = statuses.contains { status in
            if case .connected = status { return true }
            return false
        }
        return hasError && !hasConnected
    }

    /// The first server that has an error, used to display the hostname in
    /// the connection failed message (§Task 3).
    private var firstFailedServer: ConnectionManager.ServerConnection? {
        for server in connectionManager.savedServers {
            let status = connectionManager.serverStatus[server.id.uuidString] ?? .disconnected
            if case .error = status {
                return server
            }
        }
        return nil
    }

    // MARK: - Top bar

    private var topBar: some View {
        TopBar(
            title: "MISSION CONTROL",
            onBack: { dismiss() },
            onMenu: { showPalette = true }
        )
    }

    private func makeMCContext() -> SessionContext {
        SessionContext(
            mode: .missionControl,
            currentSession: nil,
            store: nil,
            missionClient: nil,
            presentDialog: { kind in
                switch kind {
                case .sessionCarousel:
                    withAnimation(.forgeSpring) { showCarousel = true }
                case .model:
                    showMCDialog = .model
                case .agent:
                    showMCDialog = .agent
                case .sessionList:
                    showMCDialog = .sessionList
                case .prompt(let title, let onSubmit):
                    mcPromptTitle = title
                    mcPromptSubmit = onSubmit
                    showMCDialog = .prompt
                case .skills:
                    showMCDialog = .skills
                case .jumpToMessage:
                    showMCDialog = .sessionList
                }
            },
            presentSheet: { kind in
                switch kind {
                case .addServer:
                    showingServerPicker = true
                default:
                    break
                }
            },
            navigateHome: { showPalette = false },
            navigateSession: { _ in showPalette = false }
        )
    }

    /// Renders the MC dialog surface (spec §11).
    @ViewBuilder
    private func mcDialogView(for dialog: MCDialogKind) -> some View {
        switch dialog {
        case .model:
            DialogModelView(
                currentModel: "muse-spark-1.3-contributor-free",
                onSelect: { _ in showMCDialog = nil },
                onClose: { showMCDialog = nil }
            )
        case .agent:
            DialogAgentView(
                currentAgent: "trident",
                onSelect: { _ in showMCDialog = nil },
                onClose: { showMCDialog = nil }
            )
        case .skills:
            SkillsDialogView(onClose: { showMCDialog = nil })
        case .jumpToMessage:
            DialogSessionListView(
                title: "Jump to message",
                sessions: connectionManager.sessions.map { remote in
                    SessionInfo(
                        id: remote.info.id, projectID: "proj_demo", workspaceID: nil,
                        parentID: nil, slug: remote.info.id, directory: "remote",
                        path: nil, title: remote.info.name, version: "1.0.0",
                        shareURL: nil, summaryAdditions: nil, summaryDeletions: nil,
                        summaryFiles: nil, summaryDiffs: nil, metadata: nil,
                        cost: 0, tokensInput: 0, tokensOutput: 0, tokensReasoning: 0,
                        tokensCacheRead: 0, tokensCacheWrite: 0,
                        revert: nil, permission: nil, agent: remote.info.agent,
                        model: "muse-spark-1.3-contributor-free",
                        timeCreated: remote.info.timeCreated ?? 0,
                        timeUpdated: remote.info.timeUpdated ?? 0,
                        timeCompacting: nil, timeArchived: nil
                    )
                },
                onSelect: { id in
                    selectRemoteSession(id: id)
                    showMCDialog = nil
                },
                onClose: { showMCDialog = nil }
            )
        case .sessionList:
            DialogSessionListView(
                title: "Switch session",
                sessions: connectionManager.sessions.map { remote in
                    SessionInfo(
                        id: remote.info.id, projectID: "proj_demo", workspaceID: nil,
                        parentID: nil, slug: remote.info.id, directory: "remote",
                        path: nil, title: remote.info.name, version: "1.0.0",
                        shareURL: nil, summaryAdditions: nil, summaryDeletions: nil,
                        summaryFiles: nil, summaryDiffs: nil, metadata: nil,
                        cost: 0, tokensInput: 0, tokensOutput: 0, tokensReasoning: 0,
                        tokensCacheRead: 0, tokensCacheWrite: 0,
                        revert: nil, permission: nil, agent: remote.info.agent,
                        model: "muse-spark-1.3-contributor-free",
                        timeCreated: remote.info.timeCreated ?? 0,
                        timeUpdated: remote.info.timeUpdated ?? 0,
                        timeCompacting: nil, timeArchived: nil
                    )
                },
                // F8 (fixed 2026-08-11): tapping a session in the list used to
                // just CLOSE the dialog — the selection was ignored, so the
                // user could never navigate to a session from the list.
                onSelect: { id in
                    selectRemoteSession(id: id)
                    showMCDialog = nil
                },
                onClose: { showMCDialog = nil }
            )
        case .prompt:
            DialogPromptView(
                title: mcPromptTitle,
                initial: "",
                onSubmit: { newTitle in
                    mcPromptSubmit?(newTitle)
                    showMCDialog = nil
                },
                onClose: { showMCDialog = nil }
            )
        }
    }

    // MARK: - Session pager

    private var sessionPager: some View {
        SessionPagerView(
            sessions: demoMode ? mockServer.sessions : connectionManager.sessions,
            currentIndex: $currentIndex,
            onIndexChanged: { newIndex in
                currentIndex = newIndex
                let list = demoMode ? mockServer.sessions : connectionManager.sessions
                if list.indices.contains(newIndex) {
                    currentSessionID = list[newIndex].id
                }
            }
        )
        // Eagle Vision pinch handler overlays the pager.
        .overlay {
            EagleVisionPinchOverlay(
                isInEagleVision: $isInEagleVision,
                sessionCount: connectionManager.sessions.count
            )
        }
        // W6: Tinder-style swipe to switch sessions (spec §18).
        .modifier(TinderSwipeModifier(count: pagerCount, index: $currentIndex))
        // OR-10 deck counter: "i/N" pixel surface for swipe-beat verification.
        .overlay(alignment: .topTrailing) {
            Text("\(min(currentIndex + 1, max(pagerCount, 1)))/\(pagerCount)")
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(SwiftUI.Color.forgeElevated.opacity(0.85))
                .clipShape(Capsule())
                .accessibilityIdentifier("deckCounter")
                .padding([.top, .trailing], 8)
        }
        .ignoresSafeArea(.container, edges: [.bottom])
    }

    // MARK: - Eagle Vision grid

    private var eagleVisionGrid: some View {
        EagleVisionGridView(
            sessions: connectionManager.sessions,
            currentIndex: currentIndex,
            onSelect: { index in
                currentIndex = index
                withAnimation(.forgeSpring) {
                    isInEagleVision = false
                }
            }
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - No servers configured (§Task 3)

    /// Shown when the user has not added any servers yet.
    private var noServersState: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 56))
                .foregroundColor(.forgeSecondaryText)
                .forgeGlow(radius: 12)
            Text("No Servers Configured")
                .font(.forgeTitle)
                .foregroundColor(.forgePrimaryText)
            Text("Add an OpenCode host (LAN or Tailscale). FORGE discovers `_opencode._tcp` and polls `/session`.")
                .font(.forgeBody)
                .foregroundColor(.forgeSecondaryText)
                .multilineTextAlignment(.center)

            Button {
                ForgeHaptic.impact(.medium)
                showingServerPicker = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Server")
                }
                .font(.forgeHeadline)
                .foregroundColor(.forgeBackground)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(SwiftUI.Color.forgeAccent)
                .clipShape(Capsule())
            }
            .accessibilityIdentifier("addServerButton")

            Text("Tip: + in the top bar also opens the server picker.")
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryText.opacity(0.8))

            // Demo mode button
            Button {
                ForgeHaptic.impact(.medium)
                mockServer.start()
                withAnimation(.forgeSpring) {
                    demoMode = true
                }
            } label: {
                HStack {
                    Image(systemName: "play.circle.fill")
                    Text("Try Demo")
                }
                .font(.forgeBody)
                .foregroundColor(.forgeAccent)
            }
            .accessibilityIdentifier("tryDemoButton")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .accessibilityIdentifier("noServersState")
    }

    // MARK: - Connecting state (§Task 3)

    /// Shown while at least one server is being contacted, before any
    /// sessions have appeared.
    private var connectingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(SwiftUI.Color.forgeAccent)
                .scaleEffect(1.5)

            Text("Connecting…")
                .font(.forgeHeadline)
                .foregroundColor(.forgePrimaryText)

            Text("Contacting opencode servers for active sessions.")
                .font(.forgeBody)
                .foregroundColor(.forgeSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Connection error state (§Task 3)

    /// Shown when all configured servers failed to connect and no sessions
    /// were retrieved.
    private var connectionErrorState: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.forgeError)

            Text("Connection Failed")
                .font(.forgeTitle)
                .foregroundColor(.forgePrimaryText)

            if let server = firstFailedServer {
                Text("Cannot reach \(server.hostname). Check that opencode is running.")
                    .font(.forgeBody)
                    .foregroundColor(.forgeSecondaryText)
                    .multilineTextAlignment(.center)
            } else {
                Text("Cannot reach server. Check that opencode is running.")
                    .font(.forgeBody)
                    .foregroundColor(.forgeSecondaryText)
                    .multilineTextAlignment(.center)
            }

            Button {
                ForgeHaptic.impact(.medium)
                for server in connectionManager.savedServers {
                    connectionManager.refreshSessions(for: server)
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry Connection")
                }
                .font(.forgeHeadline)
                .foregroundColor(.forgeAccent)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .accessibilityIdentifier("retryConnectionButton")
                .background(SwiftUI.Color.forgeElevated)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(SwiftUI.Color.forgeBorder, lineWidth: 1))
            }

            Button {
                ForgeHaptics.tap()
                showingServerPicker = true
            } label: {
                Text("Configure Servers")
                    .font(.forgeCaption)
                    .foregroundColor(.forgeSecondaryText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - No sessions (connected but empty)

    /// Shown when servers are connected (or disconnected without errors) but
    /// no active sessions were found.
    private var emptySessionsState: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 56))
                .foregroundColor(.forgeSecondaryText)
            Text("No Active Sessions")
                .font(.forgeTitle)
                .foregroundColor(.forgePrimaryText)
            Text("Connected servers have no active sessions. Start a session in opencode to see it here.")
                .font(.forgeBody)
                .foregroundColor(.forgeSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Derived

    private var currentSession: RemoteSession? {
        guard !connectionManager.sessions.isEmpty else { return nil }
        let safeIndex = min(max(0, currentIndex), connectionManager.sessions.count - 1)
        return connectionManager.sessions[safeIndex]
    }

    // MARK: - W6: Carousel + spawn (spec §16–§18)

    /// Session metadata feeding the carousel overlay.
    private var carouselSessions: [RemoteSessionInfo] {
        connectionManager.sessions.map(\.info)
    }

    /// Page count for the swipe modifier (demo or live list).
    private var pagerCount: Int {
        (demoMode ? mockServer.sessions : connectionManager.sessions).count
    }

    /// Joins a session from the carousel: selects it in the pager and closes.
    /// This is the wiring target for the palette's `session.view_active`
    /// command — `presentDialog(.sessionCarousel)` maps to `showCarousel`.
    private func joinSession(_ info: RemoteSessionInfo) {
        ForgeHaptic.impact(.light)
        if let idx = connectionManager.sessions.firstIndex(where: { $0.info.id == info.id }) {
            withAnimation(.forgeSpring) { currentIndex = idx }
        }
        withAnimation(.forgeSpring) { showCarousel = false }
    }

    /// THE single navigation path to a remote session: finds it by id, moves
    /// the pager there, and pins the identity anchor (used by the session
    /// list, the carousel, and the test hooks — one code path).
    private func selectRemoteSession(id: String) {
        guard let idx = connectionManager.sessions.firstIndex(where: { $0.id == id }) else {
            return
        }
        withAnimation(.forgeSpring) { currentIndex = idx }
        currentSessionID = id
        ForgeHaptics.tap()
    }

    /// Spawns a new session on the first saved server via `POST /session`,
    /// then refreshes that server's session list and selects the new entry.
    /// If no server is configured, routes to the server picker.
    private func spawnNewSession() {
        guard !isSpawning else { return }
        guard let server = connectionManager.savedServers.first else {
            spawnError = "Add a server before spawning a session."
            withAnimation(.forgeSpring) { showCarousel = false }
            showingServerPicker = true
            return
        }
        guard let url = URL(string: server.baseURL) else {
            spawnError = "Invalid server URL: \(server.baseURL)"
            return
        }

        isSpawning = true
        spawnError = nil
        Task {
            do {
                _ = try await mcClient.spawnSession(baseURL: url, title: nil)
                isSpawning = false
                connectionManager.refreshSessions(for: server)
                withAnimation(.forgeSpring) { currentIndex = 0 }
                withAnimation(.forgeSpring) { showCarousel = false }
            } catch {
                isSpawning = false
                spawnError = "Spawn failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - EagleVisionPinchOverlay

/// An invisible overlay that captures pinch gestures to toggle Eagle Vision
/// (§19.2). When the pinch scale drops below 0.5, Eagle Vision enters; this
/// is the conceptual "zoom out" gesture.
struct EagleVisionPinchOverlay: View {

    @Binding var isInEagleVision: Bool
    let sessionCount: Int

    var body: some View {
        SwiftUI.Color.clear
            .contentShape(Rectangle())
            .gesture(
                MagnificationGesture()
                    .onChanged { scale in
                        // Threshold handled in onEnded to avoid jitter.
                    }
                    .onEnded { scale in
                        guard sessionCount > 1 else { return }
                        if scale < 0.5 && !isInEagleVision {
                            ForgeHaptics.tap()
                            withAnimation(.forgeSpringSoft) {
                                isInEagleVision = true
                            }
                        } else if scale > 1.5 && isInEagleVision {
                            ForgeHaptics.tap()
                            withAnimation(.forgeSpringSoft) {
                                isInEagleVision = false
                            }
                        }
                    }
            )
            .allowsHitTesting(true)
    }
}

import SwiftUI
import UIKit
import SwiftTerm
import WebKit

/// BuildOnDeviceScreen
///
/// The Mode 1 container. Owns the hidden `ForgeEngine`, the `ForgeBridge`,
/// and the opencode-style TUI conversation surface (`ChatStore` +
/// `TranscriptView`). The raw `ForgeTerminalView` lives behind a header
/// `terminal` icon as a `.sheet` — it is NEVER composited under the chat
/// surface in chat mode (Anti-Pattern AP3).
///
/// Streaming architecture (spec §3/§4): every engine chat event flows
/// `ForgeEngine → .forgeChatMessage → LaneRouter → ChatStore`. Deltas MUTATE
/// an existing part's text (never one view per delta — AP1). File content
/// can only reach `attachWrite`/`attachDiff`, never prose (AP4).
struct BuildOnDeviceScreen: View {

    /// The central app state (injected from the environment).
    @EnvironmentObject var appState: AppState

    /// Dismisses back to the launch menu.
    @Environment(\.dismiss) private var dismiss

    // MARK: - TUI state

    /// The single mutation point for the conversation surface. Deltas merge
    /// into existing parts; views render `chatStore.messages` 1:1.
    @StateObject private var chatStore = ChatStore()

    /// The lane router turns raw `.forgeChatMessage` payloads into store
    /// mutations. Lazily rebuilt each turn so it always references the live
    /// store.
    private var router: LaneRouter { LaneRouter(store: chatStore) }

    /// Composer draft text.
    @State private var draft = ""

    /// Controls the context drawer (☰).
    @State private var showDrawer = false

    // N7: playable-output sheet (secondary). Primary surface is the PREVIEW tab.
    @State private var showPreview = false
    @State private var previewSafetyTimer: DispatchWorkItem?

    // MARK: - Preview tab chrome (FORGE-PREVIEW-SPEC-V1.0 §3.2 / §3.7)
    // Labels: TERMINAL / SPLIT / PREVIEW. SPLIT is 60/40 terminal+preview.
    // Sheet is kept only as a secondary path — not the only preview.

    @State private var previewMode: PreviewMode = .terminal
    @State private var hasPreviewContent = false
    @State private var previewPaneActive = false
    @State private var previewWebView: WKWebView?
    @State private var currentPreviewPath: String?
    @State private var consoleEntries: [ConsoleEntry] = []
    @State private var showConsoleDrawer = false
    @State private var consoleBadge = 0

    /// The jailed root the preview sheet loads from — the live bridge's
    /// project root, falling back to the demo project (FORGE-Demo).
    private var previewProjectRoot: String {
        if let bridge, !bridge.projectRoot.isEmpty {
            return bridge.projectRoot
        }
        return ForgeBridge().ensureDemoProjectRoot()
    }

    /// Controls the raw terminal sheet (terminal icon).
    @State private var showTerminal = false

    // MARK: - Engine / terminal plumbing (unchanged mechanics)

    @State private var terminalView: TerminalView?
    @State private var showingSettings = false
    @State private var showingProjectManager = false
    @State private var showPalette = false
    @State private var activeDialog: DialogKind?
    @State private var engine: ForgeEngine?
    @State private var bridge: ForgeBridge?
    @State private var errorMessage: String?
    @State private var isReady = false
    @State private var isLoading = false
    @State private var hasBundle = false
    @State private var didFeedPlaceholder = false
    @State private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    @State private var didStartEngine = false

    /// Accumulated tokens/cost for the current session (fed by
    /// `reportTokens`), mirrored into `chatStore.status`.
    @State private var tokenCount: Int = 0
    @State private var sessionCost: Double = 0.0

    @StateObject private var sessionStore = SessionStore()
    @State private var currentSessionID: String?

    /// Heap box for engine→terminal feed (weak TerminalView).
    @State private var terminalFeedBox = TerminalFeedBox()

    private var hasAPIKey: Bool {
        KeychainHelper.exists(for: ForgeSettingsKeys.apiKey)
    }

    #if targetEnvironment(simulator)
    private var isSimulator: Bool { true }
    #else
    private var isSimulator: Bool { false }
    #endif

    // MARK: - Body
    // Split into chrome / preview observers / engine observers so the Swift
    // type checker can finish (WAVE 2 toggle + pane made a single chain too long).

    var body: some View {
        engineObservedRoot
            .sheet(isPresented: $showDrawer) {
                ContextDrawerView(
                    status: chatStore.status,
                    mcpServers: [],
                    lspStatus: "LSPs are disabled"
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showTerminal) {
                TerminalSheet(
                    terminalView: $terminalView,
                    onSend: { data in handleSend(data) },
                    onResize: { cols, rows in handleResize(cols: cols, rows: rows) }
                )
                .onAppear {
                    engine?.sendInput("\\u0000")
                    engine?.evalJS("window.__forgeTerminalVisible = true;")
                }
                .onDisappear {
                    engine?.evalJS("window.__forgeTerminalVisible = false;")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet().environmentObject(appState)
            }
            .sheet(isPresented: $showingProjectManager) {
                ProjectManagerSheet().environmentObject(appState)
            }
    }

    private var chromeStack: some View {
        VStack(spacing: 0) {
            HeaderBar(
                status: chatStore.status,
                onMenu: { showDrawer = true },
                onTerminal: { showTerminal = true },
                onPreview: { handleHeaderPreview() }
            )

            PreviewModeToggle(
                mode: $previewMode,
                hasPreviewContent: hasPreviewContent
            )
            // NOTE: no accessibilityLabel here — the toggle's children carry
            // their own TERMINAL/SPLIT/PREVIEW labels (t89: a parent label
            // flattens the segments out of the AX tree).

            modeContent
                .overlay { modeContentOverlay }

            if previewMode != .preview {
                composerColumn
            }
        }
        .background(TuiTheme.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .statusBarHidden(true)
    }

    @ViewBuilder
    private var modeContentOverlay: some View {
        if isLoading && !isReady && errorMessage == nil {
            loadingPlaceholder
                .transition(.opacity)
                .allowsHitTesting(false)
        }
        if let errorMessage = errorMessage, !isReady {
            errorView(errorMessage)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var composerColumn: some View {
        if chatStore.subagent != nil {
            SubagentStripView(s: chatStore.subagent!)
        }
        ComposerView(
            draft: $draft,
            isRunning: chatStore.status.isRunning,
            agentName: chatStore.status.agentName.isEmpty ? "trident" : chatStore.status.agentName,
            modelName: chatStore.status.modelDisplayName,
            onSend: { sendMessage($0) }
        )
        .padding(.horizontal, TuiTheme.transcriptPad)
        .padding(.vertical, 6)
        StatusFooterView(
            status: chatStore.status,
            onInterrupt: { interrupt() }
        )
    }

    private var previewObservedRoot: some View {
        chromeStack
            .sheet(isPresented: $showPreview, onDismiss: dismissPreviewSheet) {
                ProjectPreviewSheet(projectRoot: previewProjectRoot)
            }
            .overlay { paletteOverlay }
            .onReceive(NotificationCenter.default.publisher(for: .forgeOpenPreview), perform: handleOpenPreview)
            .onReceive(NotificationCenter.default.publisher(for: .forgePreviewReady), perform: handlePreviewReady)
            .onReceive(NotificationCenter.default.publisher(for: .forgeShowPreviewTab), perform: handleShowPreviewTab)
            .onReceive(NotificationCenter.default.publisher(for: .forgePreviewTitle), perform: handlePreviewTitle)
            .onReceive(NotificationCenter.default.publisher(for: .forgePreviewConsole), perform: handlePreviewConsole)
            .onReceive(NotificationCenter.default.publisher(for: .forgeTurnComplete), perform: handleTurnComplete)
            .onChange(of: showPreview) { _, isPresented in
                if isPresented == false {
                    previewSafetyTimer?.cancel()
                    previewSafetyTimer = nil
                }
            }
            .onChange(of: previewMode) { _, mode in
                if mode == .split || mode == .preview {
                    previewPaneActive = true
                }
            }
            .onChange(of: previewWebView != nil) { _, hasView in
                bindPreviewWebView(hasView)
            }
    }

    @ViewBuilder
    private var paletteOverlay: some View {
        if showPalette {
            CommandPaletteView(
                context: makeContext(),
                onClose: { showPalette = false }
            )
            .transition(.opacity)
            .zIndex(1)
        }
        if let dialog = activeDialog {
            dialogView(for: dialog)
                .transition(.opacity)
                .zIndex(2)
        }
    }

    private var engineObservedRoot: some View {
        previewObservedRoot
            .onAppear(perform: handleAppear)
            .onDisappear(perform: stopEngine)
            .onChange(of: terminalView != nil) { _, isAvailable in
                handleTerminalBound(isAvailable)
            }
            .onChange(of: appState.currentProject) { _, newProject in
                if let project = newProject { applyProject(project) }
            }
            .onChange(of: appState.modelName) { _, newModel in
                chatStore.updateModel(newModel)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                handleBackground()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                handleForeground()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                engine?.didReceiveMemoryWarning()
            }
            .onReceive(NotificationCenter.default.publisher(for: .forgeTokensReported)) { note in
                handleTokensReported(note.userInfo ?? [:])
            }
            .onReceive(NotificationCenter.default.publisher(for: .forgeChatMessage), perform: handleChatMessage)
            .onReceive(NotificationCenter.default.publisher(for: .forgeSessionHeader), perform: handleSessionHeader)
    }

    private func handleHeaderPreview() {
        if hasPreviewContent {
            openPreviewTab(path: currentPreviewPath)
        } else {
            showPreview = true
        }
    }

    private func handleAppear() {
        seedStatus()
        startEngineStaged(reason: "appear")
        applyTestHooks()
    }

    private func dismissPreviewSheet() {
        previewSafetyTimer?.cancel()
        previewSafetyTimer = nil
        showPreview = false
    }

    private func bindPreviewWebView(_ hasView: Bool) {
        guard hasView, let wv = previewWebView else { return }
        engine?.attachPreviewWebView(wv)
        engine?.reloadPreview()
    }

    private func handleTerminalBound(_ isAvailable: Bool) {
        terminalFeedBox.terminal = terminalView
        guard isAvailable else { return }
        if !didFeedPlaceholder { feedPlaceholderContent() }
        DispatchQueue.main.async { startEngineStaged(reason: "terminal-bound") }
    }

    private func handleOpenPreview(_ note: Notification) {
        showPreview = (note.userInfo?["open"] as? Bool) ?? true
    }

    private func handlePreviewReady(_ note: Notification) {
        openPreviewTab(path: note.userInfo?["path"] as? String)
    }

    private func handleShowPreviewTab(_ note: Notification) {
        let open = (note.userInfo?["open"] as? Bool) ?? true
        if open {
            openPreviewTab(path: currentPreviewPath)
        } else {
            withAnimation(.forgeSpring) { previewMode = .terminal }
        }
    }

    private func handlePreviewTitle(_ note: Notification) {
        if let title = note.userInfo?["title"] as? String {
            currentPreviewPath = title
        }
    }

    private func handlePreviewConsole(_ note: Notification) {
        appendConsole(ConsoleEntry(
            timestamp: Date(),
            level: ConsoleLevel(rawValue: (note.userInfo?["level"] as? String) ?? "log") ?? .log,
            message: (note.userInfo?["message"] as? String) ?? "",
            source: note.userInfo?["source"] as? String,
            line: note.userInfo?["line"] as? Int
        ))
    }

    private func handleTurnComplete(_ note: Notification) {
        if hasPreviewContent {
            openPreviewTab(path: currentPreviewPath)
        }
        let env = ProcessInfo.processInfo.environment
        let fullE2E = env["FORGE_TEST_FULL_E2E"] == "1" || env["SIMCTL_CHILD_FORGE_TEST_FULL_E2E"] == "1"
        guard fullE2E else { return }
        DispatchQueue.main.async {
            previewLog.info("[PREVIEW] sheet presented via forgeTurnComplete; PREVIEW tab stays")
            self.showPreview = true
            let safety = DispatchWorkItem {
                previewLog.info("[PREVIEW] sheet auto-dismissed after 25s hold; PREVIEW tab remains")
                self.showPreview = false
                self.previewSafetyTimer = nil
            }
            self.previewSafetyTimer?.cancel()
            self.previewSafetyTimer = safety
            DispatchQueue.main.asyncAfter(deadline: .now() + 25.0, execute: safety)
        }
    }

    private func handleChatMessage(_ note: Notification) {
        router.handleChatPayload(note.userInfo ?? [:])
        let info = note.userInfo ?? [:]
        if (info["kind"] as? String) == "status",
           ((info["text"] as? String) ?? "").lowercased().contains("done") {
            persistAssistantTurn()
        }
    }

    private func handleSessionHeader(_ note: Notification) {
        let info = note.userInfo ?? [:]
        let title = (info["title"] as? String) ?? chatStore.status.workspace
        let model = (info["model"] as? String) ?? appState.modelName
        chatStore.status.workspace = title
        chatStore.updateModel(model)
    }

    // MARK: - Mode 1 chrome: TERMINAL / SPLIT / PREVIEW

    /// TERMINAL = transcript; SPLIT = 60/40 terminal+preview; PREVIEW = full pane.
    /// Both branches stay MOUNTED in every mode (t101): unmounting the preview
    /// branch destroys its WKWebView, so tabbing away and back blanked the pane.
    /// Hidden branches collapse to zero height + opacity 0 + no hit-testing.
    @ViewBuilder
    private var modeContent: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                previewChrome
                    .frame(
                        width: geo.size.width,
                        height: previewMode == .terminal ? 0 : (previewMode == .split ? geo.size.height * 0.60 : geo.size.height)
                    )
                    .opacity(previewMode == .terminal ? 0 : 1)
                    .allowsHitTesting(previewMode != .terminal)
                    .clipped()
                TranscriptView(store: chatStore)
                    .frame(
                        width: geo.size.width,
                        height: previewMode == .preview ? 0 : (previewMode == .split ? geo.size.height * 0.40 : geo.size.height)
                    )
                    .opacity(previewMode == .preview ? 0 : 1)
                    .allowsHitTesting(previewMode != .preview)
                    .clipped()
            }
        }
    }

    /// Isolated Preview WKWebView + toolbar + console drawer.
    /// PreviewPaneView is lazy: `isActive` flips on first renderPreview or user tap.
    private var previewChrome: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                PreviewToolbarView(
                    currentPath: currentPreviewPath,
                    onReload: { engine?.reloadPreview() },
                    onHome: { engine?.loadPreviewBlank() },
                    onOpenInSafari: { engine?.copyPreviewPathToClipboard() },
                    onToggleConsole: {
                        showConsoleDrawer.toggle()
                        if showConsoleDrawer { consoleBadge = 0 }
                    },
                    consoleBadge: consoleBadge
                )
                PreviewPaneView(
                    webView: $previewWebView,
                    onConsoleMessage: { entry in
                        appendConsole(entry)
                        engine?.feedPreviewConsoleToTerminal(entry.message)
                    },
                    onPreviewError: { err in
                        appendConsole(ConsoleEntry(
                            timestamp: Date(),
                            level: .error,
                            message: err.message,
                            source: err.source,
                            line: err.line
                        ))
                    },
                    isActive: previewPaneActive
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if showConsoleDrawer {
                ConsoleDrawerView(
                    entries: consoleEntries,
                    onClear: {
                        consoleEntries.removeAll()
                        consoleBadge = 0
                    },
                    onClose: { showConsoleDrawer = false }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.forgeSpring, value: showConsoleDrawer)
        .background(SwiftUI.Color.forgeBackground)
    }

    /// Agent renderPreview (and user PREVIEW tap) — tab stays; not a 25s sheet.
    private func openPreviewTab(path: String?) {
        hasPreviewContent = true
        previewPaneActive = true
        if let path, !path.isEmpty {
            currentPreviewPath = path
        }
        withAnimation(.forgeSpring) {
            // Agent html-write + preview tool both call this. t3: first call
            // from TERMINAL went SPLIT, second call saw != terminal and jumped
            // to full PREVIEW — tape froze at 268kbps. Stay SPLIT unless the
            // user already picked full PREVIEW.
            if previewMode != .preview {
                previewMode = .split
            }
        }
    }

    private func appendConsole(_ entry: ConsoleEntry) {
        consoleEntries.append(entry)
        if consoleEntries.count > 200 {
            consoleEntries.removeFirst(consoleEntries.count - 200)
        }
        if !showConsoleDrawer {
            consoleBadge += 1
        }
    }

    // MARK: - Status seeding (model/workspace from config — NEVER hardcoded)

    private func seedStatus() {
        chatStore.status.workspace = "FORGE-Demo"
        chatStore.status.branch = "master"
        chatStore.status.version = appVersion
        chatStore.status.agentName = "trident"
        // N8: the engine's injectAPICredentials() honors FORGE_API_MODEL, but
        // the composer chips label read ONLY appState (defaults) — so the
        // label showed the default `-free` model until the first turn updated
        // it (vision: PHONE-E2E g-04 `-free` → g-07 `deepseek-v4-flash`).
        // The label now matches the engine config from launch (env = sim/CI
        // harness only; production keeps the defaults path).
        let envModel = ProcessInfo.processInfo.environment["FORGE_API_MODEL"]
        chatStore.updateModel(envModel ?? appState.modelName)
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return "v\(v ?? "1.0.0")"
    }

    // MARK: - Sending

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chatStore.sendUser(trimmed)
        persistUserPrompt(trimmed)
        let escaped = trimmed
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        engine?.sendInput(escaped)
    }

    private func interrupt() {
        chatStore.interrupt()
        // Best-effort engine interrupt: send Ctrl-C equivalent.
        engine?.sendInput("\\u0003")
    }

    // MARK: - Token accounting

    private func handleTokensReported(_ info: [AnyHashable: Any]) {
        let input = (info["input"] as? Int) ?? 0
        let output = (info["output"] as? Int) ?? 0
        let reasoning = (info["reasoning"] as? Int) ?? 0
        let cacheRead = (info["cacheRead"] as? Int) ?? 0
        let cacheWrite = (info["cacheWrite"] as? Int) ?? 0
        let cost = (info["cost"] as? Double) ?? 0.0
        let delta = input + output + reasoning + cacheRead + cacheWrite
        tokenCount += delta
        sessionCost += cost

        chatStore.status.tokens = tokenCount
        chatStore.status.costUSD = sessionCost
        chatStore.status.contextPct = min(100, Int((Double(tokenCount) / 1_000_000) * 100))

        if let sid = currentSessionID {
            sessionStore.accumulateTokens(
                sessionID: sid,
                input: input, output: output, reasoning: reasoning,
                cacheRead: cacheRead, cacheWrite: cacheWrite, cost: cost
            )
        }
    }

    // MARK: - Session context (spec §10.1)

    private func makeContext() -> SessionContext {
        SessionContext(
            mode: .onDevice,
            currentSession: sessionStore.currentSession,
            store: sessionStore,
            missionClient: nil,
            presentDialog: { kind in activeDialog = kind },
            presentSheet: { kind in
                switch kind {
                case .settings: showingSettings = true
                case .addServer: break
                }
            },
            navigateHome: { appState.returnToLaunchMenu() },
            navigateSession: { _ in },
            composerDraft: draft,
            clearComposerDraft: { draft = "" },
            lastAssistantText: chatStore.lastAssistantText,
            transcriptText: chatStore.transcriptText
        )
    }

    @ViewBuilder
    private func dialogView(for dialog: DialogKind) -> some View {
        switch dialog {
        case .sessionList:
            DialogSessionListView(
                title: "Switch session",
                sessions: sessionStore.roots,
                onSelect: { id in
                    activeDialog = nil
                    Task {
                        if let session = try? await sessionStore.get(id) {
                            let records = sessionStore.fetchMessages(sessionID: session.id)
                            await MainActor.run {
                                sessionStore.select(session)
                                sessionStore.touch(id)
                                currentSessionID = session.id
                                chatStore.loadPersisted(records)
                            }
                        }
                    }
                },
                onClose: { activeDialog = nil }
            )
        case .model:
            DialogModelView(
                currentModel: appState.modelName,
                onSelect: { id in
                    appState.modelName = id
                    chatStore.updateModel(id)
                    activeDialog = nil
                    if let sid = currentSessionID {
                        Task {
                            try? await sessionStore.setAgentModel(
                                sid, agent: "trident",
                                model: ModelRef(id: id, providerID: "zen"))
                        }
                    }
                },
                onClose: { activeDialog = nil }
            )
        case .agent:
            DialogAgentView(
                currentAgent: "trident",
                onSelect: { _ in activeDialog = nil },
                onClose: { activeDialog = nil }
            )
        case .skills:
            SkillsDialogView(onClose: { activeDialog = nil })
        case .jumpToMessage:
            // Jump to message = switch to a session (vanilla: message jump).
            DialogSessionListView(
                title: "Jump to message",
                sessions: sessionStore.roots,
                onSelect: { id in
                    activeDialog = nil
                    Task {
                        if let session = try? await sessionStore.get(id) {
                            sessionStore.select(session)
                        }
                    }
                },
                onClose: { activeDialog = nil }
            )
        case .prompt(let title, let onSubmit):
            DialogPromptView(
                title: title,
                initial: sessionStore.currentSession?.title ?? "",
                onSubmit: { newTitle in
                    onSubmit(newTitle)
                    activeDialog = nil
                },
                onClose: { activeDialog = nil }
            )
        case .sessionCarousel:
            EmptyView().onAppear { activeDialog = nil }
        }
    }

    // MARK: - Test hooks (env-driven UI demos; no effect in production)

    /// Drives the palette/dialog demos via env vars so the operator can record
    /// the UI without manual taps (SSH-only simulator access).
    ///   FORGE_TEST_OPEN_PALETTE=1       → opens the command palette
    ///   FORGE_TEST_OPEN_MODEL_DIALOG=1  → opens the Switch-model dialog
    ///   FORGE_TEST_OPEN_SESSION_LIST=1  → opens the Switch-session dialog
    ///   FORGE_TEST_NEW_SESSION=1        → creates + switches to a new session
    ///   FORGE_TEST_LAUNCH_MENU=1        → returns to the launch menu
    ///   FORGE_TEST_PREVIEW=1            → opens the N7 preview sheet (t+5)
    ///   FORGE_TEST_RENDER_PREVIEW=1     → jailed index.html + renderPreview (no LLM)
    ///   FORGE_TEST_MODE1_E2E=1          → write hello.py, runPython, write HTML, renderPreview
    ///   FORGE_TEST_E2E=1                → FULL scripted sequence (palette →
    ///     model dialog → session list → launch menu → Mission Control) with
    ///     a running agent prompt, for one comprehensive recorded demo.
    private func gatedNav(_ action: @escaping () -> Void) {
        if showPreview == false {
            action()
            return
        }
        var elapsed: TimeInterval = 0
        func poll() {
            if showPreview == false || elapsed >= 60 {
                action()
            } else {
                elapsed += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { poll() }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { poll() }
    }

    /// Wait for engine + isolated Preview WKWebView, then hit the shipped
    /// `renderPreview` path with a jailed `index.html` (no LLM).
    private func scheduleNoLLMRenderPreview() {
        func attempt(_ remaining: Int) {
            guard remaining > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard let engine = self.engine else {
                    attempt(remaining - 1)
                    return
                }
                self.previewPaneActive = true
                self.hasPreviewContent = true
                withAnimation(.forgeSpring) { self.previewMode = .preview }
                if self.previewWebView != nil {
                    engine.renderJailedPreviewFixture()
                    return
                }
                // Pane just activated — attach happens on the next SwiftUI pass.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    engine.renderJailedPreviewFixture()
                }
            }
        }
        attempt(50)
    }

    /// Full no-LLM Mode 1 turn: writeFile hello.py → runPython → write HTML → renderPreview.
    /// Must wait for `isReady` so `runPython` evaluates against a live document.
    /// Runs once per process (t94: view re-appear re-fired the fixture and the
    /// second runPython raced the first).
    private static var e2eDidRun = false
    private func scheduleMode1E2E() {
        func attempt(_ remaining: Int) {
            guard remaining > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard !Self.e2eDidRun else { return }
                self.previewPaneActive = true
                self.hasPreviewContent = true
                withAnimation(.forgeSpring) { self.previewMode = .preview }
                guard let engine = self.engine, self.isReady, let wv = self.previewWebView else {
                    attempt(remaining - 1)
                    return
                }
                Self.e2eDidRun = true
                self.writeToTerminal("E2E writeFile hello.py + runPython\r\n")
                engine.attachPreviewWebView(wv)
                engine.runMode1WriteRunPreviewFixture()
            }
        }
        attempt(80)
    }

    private func applyTestHooks() {
        let env = ProcessInfo.processInfo.environment
        if env["FORGE_TEST_PREVIEW"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.showPreview = true
            }
        }
        // WAVE 2: force SPLIT / PREVIEW chrome without a tap (simctl env).
        let openSplit = env["FORGE_TEST_OPEN_SPLIT"] == "1"
            || env["SIMCTL_CHILD_FORGE_TEST_OPEN_SPLIT"] == "1"
        let openPreview = env["FORGE_TEST_OPEN_PREVIEW"] == "1"
            || env["SIMCTL_CHILD_FORGE_TEST_OPEN_PREVIEW"] == "1"
        let renderPreviewHook = env["FORGE_TEST_RENDER_PREVIEW"] == "1"
            || env["SIMCTL_CHILD_FORGE_TEST_RENDER_PREVIEW"] == "1"
        let mode1E2E = env["FORGE_TEST_MODE1_E2E"] == "1"
            || env["SIMCTL_CHILD_FORGE_TEST_MODE1_E2E"] == "1"
        if mode1E2E {
            scheduleMode1E2E()
        } else if renderPreviewHook {
            scheduleNoLLMRenderPreview()
        }
        if openSplit || openPreview || renderPreviewHook || mode1E2E {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.previewPaneActive = true
                if openPreview || renderPreviewHook || mode1E2E {
                    self.hasPreviewContent = true
                    withAnimation(.forgeSpring) { self.previewMode = .preview }
                } else {
                    withAnimation(.forgeSpring) { self.previewMode = .split }
                }
            }
        }
        guard env["FORGE_TEST_OPEN_PALETTE"] == "1"
            || env["FORGE_TEST_OPEN_MODEL_DIALOG"] == "1"
            || env["FORGE_TEST_OPEN_SESSION_LIST"] == "1"
            || env["FORGE_TEST_NEW_SESSION"] == "1"
            || env["FORGE_TEST_LAUNCH_MENU"] == "1"
            || env["FORGE_TEST_OPEN_TERMINAL"] == "1"
            || env["FORGE_TEST_SWITCH_OTHER"] == "1"
            || env["FORGE_TEST_E2E"] == "1" else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if env["FORGE_TEST_OPEN_PALETTE"] == "1" {
                self.showPalette = true
            }
            if env["FORGE_TEST_OPEN_MODEL_DIALOG"] == "1" {
                self.activeDialog = .model
            }
            if env["FORGE_TEST_OPEN_SESSION_LIST"] == "1" {
                self.activeDialog = .sessionList
            }
            if env["FORGE_TEST_OPEN_TERMINAL"] == "1" {
                // M4 hook: open the raw TerminalSheet (the same showTerminal
                // path as the header terminal icon).
                self.showTerminal = true
            }
            if env["FORGE_TEST_SWITCH_OTHER"] == "1" {
                // Journey hook: switch to the most-recent session that is NOT
                // the current one (mirrors the session-list dialog's select
                // path: store.get → select → touch → LOAD the transcript).
                Task {
                    let others = self.sessionStore.roots.filter { $0.id != self.currentSessionID }
                    if let target = others.first,
                       let session = try? await self.sessionStore.get(target.id) {
                        let records = self.sessionStore.fetchMessages(sessionID: session.id)
                        await MainActor.run {
                            self.sessionStore.select(session)
                            self.sessionStore.touch(target.id)
                            self.currentSessionID = session.id
                            self.chatStore.loadPersisted(records)
                        }
                    }
                }
            }
            if env["FORGE_TEST_NEW_SESSION"] == "1" {
                // Reuse the palette command so behavior matches production.
                let ctx = self.makeContext()
                Task {
                    try? await CommandRegistry.dispatch("session.new", in: ctx)
                }
            }
            if env["FORGE_TEST_LAUNCH_MENU"] == "1" {
                self.appState.returnToLaunchMenu()
            }

            // FULL E2E SEQUENCE (one launch, timed script):
            // Agent runs via FORGE_TEST_PROMPT in parallel. Each step leaves
            // ~3s for the VM to screenshot before the next fires.
            // Nav steps (launch menu / Mission Control) are gated on preview dismissal.
            if env["FORGE_TEST_E2E"] == "1" {
                let seq: [(TimeInterval, () -> Void)] = [
                    (0.5, { self.showPalette = true }),                      // palette open
                    (3.0, { self.showPalette = false }),                     // palette close
                    (4.0, { self.activeDialog = .model }),                   // model dialog
                    (7.0, { self.activeDialog = nil }),                      // model close
                    (8.0, { self.activeDialog = .sessionList }),             // session list
                    (11.0, { self.activeDialog = nil }),                     // sessions close
                    (13.0, { self.gatedNav { self.appState.returnToLaunchMenu() } }), // launch menu (gated)
                    (17.0, {
                        self.gatedNav {
                            self.appState.selectMode(.missionControl)
                        }
                    }),
                    (22.0, {
                        // MC hooks fire on MC appear (session list + spawn).
                    }),
                ]
                for (delay, action) in seq {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        action()
                    }
                }
            }
        }
    }

    // MARK: - Error / loading views

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(TuiTheme.failure)
            Text("Engine Error")
                .font(TuiTheme.bodyFont.bold())
                .foregroundStyle(TuiTheme.textPrimary)
            Text(message)
                .font(TuiTheme.smallFont)
                .foregroundStyle(TuiTheme.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text("Engine error — terminal sheet remains available.")
                .font(TuiTheme.smallFont)
                .foregroundStyle(TuiTheme.textDim)
            Button("Retry") {
                ForgeHaptic.impact(.medium)
                errorMessage = nil
                didStartEngine = false
                startEngineStaged(reason: "retry")
            }
            .foregroundStyle(TuiTheme.violet)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TuiTheme.bg.opacity(0.97))
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(TuiTheme.violet)
            Text("Initializing engine…")
                .font(TuiTheme.smallFont)
                .foregroundStyle(TuiTheme.textDim)
            if isSimulator {
                Text("Simulator: Metal OFF")
                    .font(TuiTheme.smallFont)
                    .foregroundStyle(TuiTheme.textDim)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TuiTheme.bg.opacity(0.6))
    }

    // MARK: - Placeholder content (terminal welcome banner)

    private func feedPlaceholderContent() {
        guard terminalView != nil else { return }
        didFeedPlaceholder = true
        let simNote = isSimulator
            ? "\u{001b}[2m[sim] Metal renderer off · CoreGraphics path\u{001b}[0m\r\n"
            : ""
        let banner: String
        if hasBundle {
            banner = """
            \u{001b}[38;5;208mFORGE \(appVersion)\u{001b}[0m — OpenCode Mobile\r\n\
            \(simNote)\
            Agent ready — send a message to start coding\r\n\
            \r\n\
            > \u{001b}[5m_\u{001b}[0m
            """
        } else {
            banner = """
            \u{001b}[38;5;208mFORGE \(appVersion)\u{001b}[0m — OpenCode Mobile\r\n\
            \(simNote)\
            \u{001b}[2mNo agent bundle loaded. Configure API key in Settings to start.\u{001b}[0m\r\n\
            \r\n\
            > \u{001b}[5m_\u{001b}[0m
            """
        }
        writeToTerminal(banner)
    }

    private func writeToTerminal(_ text: String) {
        terminalFeedBox.terminal = terminalView
        if Thread.isMainThread {
            terminalFeedBox.terminal?.feed(text: text)
        } else {
            DispatchQueue.main.async { [feedBox = terminalFeedBox] in
                feedBox.terminal?.feed(text: text)
            }
        }
    }

    // MARK: - Engine lifecycle

    private func startEngineStaged(reason: String) {
        guard !didStartEngine else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            tryStartEngineStaged(reason: reason)
        }
    }

    private func tryStartEngineStaged(reason: String) {
        guard !didStartEngine else { return }
        didStartEngine = true
        #if DEBUG
        print("[FORGE] Mode1 startEngine staged reason=\(reason) sim=\(isSimulator)")
        #endif
        startEngine()
    }

    private func startEngine() {
        if engine != nil {
            engine?.pause()
            engine?.teardown()
            engine = nil
            bridge = nil
        }

        isLoading = true
        isReady = false
        errorMessage = nil
        didFeedPlaceholder = false

        hasBundle = Bundle.main.url(forResource: "forge-bundle", withExtension: "js") != nil

        let newBridge = ForgeBridge()
        let newEngine = ForgeEngine(bridge: newBridge)

        terminalFeedBox.terminal = terminalView
        newEngine.outputHandler = { [feedBox = terminalFeedBox] ansi in
            DispatchQueue.main.async { feedBox.terminal?.feed(text: ansi) }
        }

        newEngine.readyHandler = {
            DispatchQueue.main.async {
                isLoading = false
                isReady = true
                writeToTerminal(
                    "\u{001b}[36mFORGE engine ready\u{001b}[0m"
                    + (isSimulator ? " \u{001b}[2m(sim)\u{001b}[0m" : "")
                    + ".\r\n"
                )
                if currentSessionID == nil {
                    Task {
                        if let resume = appState.pendingResumeSession {
                            // "Continue last session": adopt the resumed
                            // session + restore its persisted transcript.
                            let records = sessionStore.fetchMessages(sessionID: resume.id)
                            await MainActor.run {
                                appState.pendingResumeSession = nil
                                sessionStore.select(resume)
                                currentSessionID = resume.id
                                chatStore.loadPersisted(records)
                            }
                        } else {
                            let session = try? await sessionStore.create(
                                parentID: nil,
                                title: nil,
                                agent: "trident",
                                model: ModelRef(id: appState.modelName, providerID: "zen")
                            )
                            await MainActor.run {
                                currentSessionID = session?.id
                                sessionStore.loadRoots()
                            }
                        }
                    }
                }
                if let testPrompt = ProcessInfo.processInfo.environment["FORGE_TEST_PROMPT"],
                   !testPrompt.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        sendMessage(testPrompt)
                    }
                }
            }
        }

        newEngine.errorHandler = { message in
            DispatchQueue.main.async {
                isLoading = false
                errorMessage = message
                writeToTerminal("\u{001b}[33m[FORGE] \(message)\u{001b}[0m\r\n")
            }
        }

        bridge = newBridge
        engine = newEngine
        if let wv = previewWebView {
            newEngine.attachPreviewWebView(wv)
        }

        if let project = appState.currentProject {
            applyProject(project)
        } else if let last = appState.projects.first {
            appState.openProject(last)
            applyProject(last)
        } else {
            _ = newBridge.ensureDemoProjectRoot()
        }

        if terminalView != nil && !didFeedPlaceholder {
            feedPlaceholderContent()
        }

        if newEngine.isInitialized {
            DispatchQueue.main.async {
                guard engine === newEngine else { return }
                newEngine.loadBundle()
            }
        } else {
            isLoading = false
            errorMessage = "Engine safe-init failed"
        }
    }

    private func stopEngine() {
        engine?.pause()
        engine?.teardown()
        engine = nil
        bridge = nil
        isLoading = false
        isReady = false
        errorMessage = nil
        didFeedPlaceholder = false
        didStartEngine = false
    }

    // MARK: - Project application

    private func applyProject(_ project: ForgeProject) {
        bridge?.setProjectRoot(project.path)
        if !project.path.isEmpty,
           KeychainHelper.exists(for: ForgeSettingsKeys.apiKey) {
            bridge?.gitOperation(["operation": "init"], callbackId: UUID().uuidString)
        }
    }

    // MARK: - Input / resize routing

    private func handleSend(_ data: Data) {
        guard let input = String(data: data, encoding: .utf8) else { return }
        persistUserPrompt(input)
        let escaped = input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        engine?.sendInput(escaped)
    }

    private func persistUserPrompt(_ prompt: String) {
        guard let sid = currentSessionID else { return }
        let payload: [String: Any] = ["role": "user", "text": prompt]
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? sessionStore.appendMessage(sessionID: sid, data: jsonString)
        }
    }

    /// Serializes the just-completed assistant turn (thinking + prose + tool
    /// rows + write panels) into the session's message store — the write half
    /// of transcript persistence (the J1-L7 gap).
    private func persistAssistantTurn() {
        guard let sid = currentSessionID,
              let last = chatStore.messages.last,
              case .assistant = last.role else { return }
        let parts: [[String: String]] = last.parts.map { part in
            var d: [String: String] = ["text": part.text]
            switch part.kind {
            case .prose: d["kind"] = "prose"
            case .thinking: d["kind"] = "thinking"
            case .tool:
                d["kind"] = "tool"
                if let t = part.tool { d["toolName"] = t.name; d["toolTitle"] = t.title }
            case .bash: d["kind"] = "bash"
            case .write:
                d["kind"] = "write"
                if let w = part.write { d["writePath"] = w.path; d["writeBytes"] = String(w.bytes) }
            default: d["kind"] = "prose"
            }
            return d
        }
        let payload: [String: Any] = ["role": "assistant", "parts": parts]
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? sessionStore.appendMessage(sessionID: sid, data: jsonString)
        }
    }

    private func handleResize(cols: Int, rows: Int) {
        if cols > 1 && rows > 1 { tryStartEngineStaged(reason: "sizeChanged") }
        engine?.sendResize(cols: cols, rows: rows)
    }

    // MARK: - Background / foreground (§25)

    private func handleBackground() {
        engine?.pause()
        showPalette = false
        let eng = engine
        var taskId: UIBackgroundTaskIdentifier = .invalid
        taskId = UIApplication.shared.beginBackgroundTask(withName: "ForgeGrace") {
            eng?.pause()
            if taskId != .invalid {
                UIApplication.shared.endBackgroundTask(taskId)
            }
        }
        backgroundTaskId = taskId
    }

    private func handleForeground() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
        engine?.resume()
    }
}

// MARK: - Terminal feed box

/// Heap box so engine outputHandler can call into the latest TerminalView
/// without capturing a stale @State copy of the screen view.
private final class TerminalFeedBox {
    weak var terminal: TerminalView?
}

// MARK: - TerminalSheet (raw terminal lives HERE, not in chat hierarchy; AP3)

/// Hosts `ForgeTerminalView` inside a sheet so it is never composited under
/// the chat surface in chat mode.
struct TerminalSheet: View {
    @Binding var terminalView: TerminalView?
    let onSend: (Data) -> Void
    let onResize: (Int, Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Terminal")
                    .font(TuiTheme.bodyFont.bold())
                    .foregroundStyle(TuiTheme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, TuiTheme.transcriptPad)
            .padding(.vertical, 8)
            .background(TuiTheme.bg)
            .overlay(alignment: .bottom) { Divider().overlay(TuiTheme.panelBorder) }

            ForgeTerminalView(
                terminalView: $terminalView,
                onSend: onSend,
                onResize: onResize
            )
            .background(TuiTheme.bg)
        }
        .background(TuiTheme.bg.ignoresSafeArea())
    }
}

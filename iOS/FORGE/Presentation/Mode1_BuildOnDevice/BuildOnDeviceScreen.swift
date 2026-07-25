import SwiftUI
import UIKit
import SwiftTerm

/// BuildOnDeviceScreen
///
/// Per FORGE Engineering Specification §15.
///
/// The Mode 1 container. Owns the hidden `ForgeEngine`, the `ForgeBridge`,
/// and the visible `ForgeTerminalView`. Handles:
/// - Engine initialization on appear.
/// - Project selection via the shared `ProjectManagerSheet`.
/// - Routing ANSI output from the engine to SwiftTerm.
/// - Routing keyboard input from SwiftTerm to the engine.
/// - Settings sheet presentation from the gear icon (shared `SettingsSheet`).
/// - Background/foreground lifecycle (pause/resume the God Loop).
struct BuildOnDeviceScreen: View {

    /// The central app state (injected from the environment).
    @EnvironmentObject var appState: AppState

    /// Dismisses back to the launch menu.
    @Environment(\.dismiss) private var dismiss

    /// The active terminal view, published so the engine can feed it.
    @State private var terminalView: TerminalView?

    /// Controls the settings sheet.
    @State private var showingSettings = false

    /// Controls the project manager sheet.
    @State private var showingProjectManager = false

    /// The currently active engine.
    @State private var engine: ForgeEngine?

    /// The bridge backing the engine.
    @State private var bridge: ForgeBridge?

    /// Shows a transient banner when the engine reports an error.
    @State private var errorMessage: String?

    /// Tracks whether the engine has signalled ready.
    @State private var isReady = false

    /// Tracks whether the engine is currently loading (between startEngine
    /// and either readyHandler or errorHandler).
    @State private var isLoading = false

    /// Tracks whether the forge-bundle.js resource exists in the app bundle.
    /// Determined once at startup so the welcome message can reflect reality.
    @State private var hasBundle = false

    /// Whether the placeholder content has already been fed to the terminal.
    /// Prevents duplicate feeds when the view re-renders.
    @State private var didFeedPlaceholder = false

    /// Background task identifier for graceful pause (§25.2).
    @State private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    // MARK: - Computed properties

    /// Whether an API key is stored in the keychain.
    private var hasAPIKey: Bool {
        KeychainHelper.exists(for: ForgeSettingsKeys.apiKey)
    }

    /// The network status to display in the top bar.
    /// - Red when no API key is configured.
    /// - Yellow when a key exists but the engine hasn't verified reachability.
    /// - Green when the engine is ready (key was injected successfully).
    private var networkStatus: NetworkStatus {
        if !hasAPIKey {
            return .missing
        } else if isReady {
            return .configured
        } else {
            return .unverified
        }
    }

    var body: some View {
        ZStack {
            SwiftUI.Color.forgeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar(
                    title: "FORGE",
                    onBack: { appState.returnToLaunchMenu() },
                    rightIcon: "gearshape",
                    rightLabel: "Settings",
                    onRightTap: {
                        ForgeHaptic.impact(.light)
                        showingSettings = true
                    },
                    networkStatus: networkStatus,
                    rightIconNeedsAttention: !hasAPIKey
                )

                // Always keep the terminal alive so its state is not lost when
                // overlays appear/disappear. Overlays sit on top.
                ForgeTerminalView(
                    terminalView: $terminalView,
                    onSend: { data in handleSend(data) },
                    onResize: { cols, rows in handleResize(cols: cols, rows: rows) }
                )
                .ignoresSafeArea(.container, edges: [.bottom])
                .overlay {
                    // Loading placeholder — shown while the engine boots
                    // and before the terminal has content (§Task 1).
                    if isLoading && !isReady && errorMessage == nil {
                        loadingPlaceholder
                            .transition(.opacity)
                    }

                    // Error placeholder — replaces the terminal visually when
                    // the engine fails to load (§Task 1).
                    if let errorMessage = errorMessage, !isReady {
                        errorView(errorMessage)
                            .transition(.opacity)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear { startEngine() }
        .onDisappear { stopEngine() }
        .onChange(of: terminalView != nil) { _, isAvailable in
            // Feed placeholder text the moment the terminal becomes ready to
            // receive input — before the JS engine finishes loading (§Task 1).
            if isAvailable && !didFeedPlaceholder {
                feedPlaceholderContent()
            }
        }
        .onChange(of: appState.currentProject) { _, newProject in
            if let project = newProject {
                applyProject(project)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.didEnterBackgroundNotification
            )
        ) { _ in handleBackground() }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.willEnterForegroundNotification
            )
        ) { _ in handleForeground() }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.didReceiveMemoryWarningNotification
            )
        ) { _ in engine?.didReceiveMemoryWarning() }
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingProjectManager) {
            ProjectManagerSheet()
                .environmentObject(appState)
        }
    }

    // MARK: - Error view

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(SwiftUI.Color.forgeError)
            Text("Engine Error")
                .font(.forgeHeadline)
                .foregroundStyle(SwiftUI.Color.forgePrimaryText)
            Text(message)
                .font(.forgeBody)
                .foregroundStyle(SwiftUI.Color.forgeSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retry") {
                ForgeHaptic.impact(.medium)
                errorMessage = nil
                startEngine()
            }
            .foregroundStyle(SwiftUI.Color.forgeAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SwiftUI.Color.forgeBackground.opacity(0.97))
    }

    // MARK: - Loading placeholder

    /// Shown while the engine boots, before the terminal has meaningful
    /// content. A spinner sits over the terminal, which already has the
    /// welcome banner text (§Task 1).
    private var loadingPlaceholder: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(SwiftUI.Color.forgeAccent)
                .scaleEffect(1.3)

            Text("Initializing engine…")
                .font(.forgeCaption)
                .foregroundStyle(SwiftUI.Color.forgeSecondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SwiftUI.Color.forgeBackground.opacity(0.85))
    }

    // MARK: - Placeholder content (§Task 1 & §Task 2)

    /// Feeds the welcome banner and API-key warning directly into the terminal
    /// via the engine's output handler. This text appears immediately on
    /// screen, before (or instead of) any JS engine output.
    private func feedPlaceholderContent() {
        guard terminalView != nil else { return }
        didFeedPlaceholder = true

        // ── Welcome banner (§Task 1) ────────────────────────────────────
        //
        // Cyan for the version line (ANSI bright cyan / SGR 96), dim for the
        // subtitle, and a plain prompt cursor at the end.
        let banner: String
        if hasBundle {
            banner = """
            \u{001b}[96mFORGE v1.0.0\u{001b}[0m — Trident T3 Audit Engine\r\n\
            Loading agent bundle…\r\n\
            \r\n\
            > \u{001b}[5m_\u{001b}[0m
            """
        } else {
            banner = """
            \u{001b}[96mFORGE v1.0.0\u{001b}[0m — Trident T3 Audit Engine\r\n\
            \u{001b}[2mNo agent bundle loaded. Configure API key in Settings to start.\u{001b}[0m\r\n\
            \r\n\
            > \u{001b}[5m_\u{001b}[0m
            """
        }

        // Route through the engine's output handler so all terminal writes
        // pass through a single pipeline (§Task 1). Falls back to a direct
        // feed if the engine isn't available yet.
        if let outputHandler = engine?.outputHandler {
            outputHandler(banner)
        } else {
            terminalView?.feed(text: banner)
        }

        // ── API key warning (§Task 2) ──────────────────────────────────
        //
        // Yellow ANSI (SGR 33) for the warning header, then dim instructions.
        if !hasAPIKey {
            let warning = """

            \r\n\
            \u{001b}[33m⚠ No API Key Configured\u{001b}[0m\r\n\
            \u{001b}[2mOpen Settings (gear icon) to configure your LLM provider and API key.\u{001b}[0m\r\n\
            \r\n
            """

            if let outputHandler = engine?.outputHandler {
                outputHandler(warning)
            } else {
                terminalView?.feed(text: warning)
            }
        }
    }

    // MARK: - Engine lifecycle

    private func startEngine() {
        // Tear down any previous engine before creating a new one.
        if engine != nil { stopEngine() }

        // Reset state for this attempt.
        isLoading = true
        isReady = false
        errorMessage = nil
        didFeedPlaceholder = false

        // Detect whether the JS bundle exists so the placeholder text can
        // reflect reality (§Task 1).
        hasBundle = Bundle.main.url(
            forResource: "forge-bundle", withExtension: "js"
        ) != nil

        let newBridge = ForgeBridge()
        let newEngine = ForgeEngine(bridge: newBridge)

        // Wire output → SwiftTerm.
        newEngine.outputHandler = { ansi in
            terminalView?.feed(text: ansi)
        }

        // Wire ready signal.
        newEngine.readyHandler = {
            isLoading = false
            isReady = true
            terminalView?.feed(
                text: "\u{001b}[36mFORGE engine ready.\u{001b}[0m\r\n"
            )
        }

        // Wire errors.
        newEngine.errorHandler = { message in
            isLoading = false
            errorMessage = message
        }

        // Store bridge/engine BEFORE applying the project so applyProject
        // can call bridge?.setProjectRoot on the NEW bridge.
        bridge = newBridge
        engine = newEngine

        // If a project is already selected, apply it; otherwise prompt.
        if let project = appState.currentProject {
            applyProject(project)
        } else if appState.projects.isEmpty {
            // No projects exist yet — prompt the user to create one.
            showingProjectManager = true
        } else if let last = appState.projects.first {
            // Reopen the most recently accessed project.
            appState.openProject(last)
            applyProject(last)
        }

        // Feed the placeholder content now if the terminal is already alive
        // (e.g. retry). Otherwise onChange(of: terminalView) handles it.
        if terminalView != nil && !didFeedPlaceholder {
            feedPlaceholderContent()
        }

        // Load the bundle — the bootstrap will fire __ready when done.
        newEngine.loadBundle()
    }

    private func stopEngine() {
        engine?.pause()
        engine?.teardown()
        engine = nil
        bridge = nil
        terminalView = nil
        isLoading = false
        isReady = false
        errorMessage = nil
        didFeedPlaceholder = false
    }

    // MARK: - Project application

    /// Applies the selected project to the bridge and initializes Git if
    /// credentials are configured (§22.1).
    private func applyProject(_ project: ForgeProject) {
        bridge?.setProjectRoot(project.path)

        // Initialize Git if credentials are configured. A callbackId is
        // required by ForgeBridge — nil causes the operation to be silently
        // skipped. Use a throwaway UUID since we don't need the result.
        if KeychainHelper.exists(for: ForgeSettingsKeys.apiKey) {
            bridge?.gitOperation(
                ["operation": "init"],
                callbackId: UUID().uuidString
            )
        }
    }

    // MARK: - Input / resize routing

    private func handleSend(_ data: Data) {
        guard let input = String(data: data, encoding: .utf8) else { return }
        // Escape for safe embedding in a JS string literal (§7.5).
        let escaped = input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        engine?.sendInput(escaped)
    }

    private func handleResize(cols: Int, rows: Int) {
        engine?.sendResize(cols: cols, rows: rows)
    }

    // MARK: - Background / foreground (§25)

    private func handleBackground() {
        engine?.pause()
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(
            withName: "ForgeGrace"
        ) { [self] in
            engine?.pause()
            if backgroundTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskId)
                backgroundTaskId = .invalid
            }
        }
    }

    private func handleForeground() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
        engine?.resume()
    }
}

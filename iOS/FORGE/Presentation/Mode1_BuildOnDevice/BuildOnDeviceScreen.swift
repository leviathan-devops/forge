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

    /// Background task identifier for graceful pause (§25.2).
    @State private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

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
                    }
                )

                if let errorMessage = errorMessage, !isReady {
                    errorView(errorMessage)
                } else {
                    ForgeTerminalView(
                        terminalView: $terminalView,
                        onSend: { data in handleSend(data) },
                        onResize: { cols, rows in handleResize(cols: cols, rows: rows) }
                    )
                    .ignoresSafeArea(.container, edges: [.bottom])
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear { startEngine() }
        .onDisappear { stopEngine() }
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
    }

    // MARK: - Engine lifecycle

    private func startEngine() {
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

        let newBridge = ForgeBridge()
        let newEngine = ForgeEngine(bridge: newBridge)

        // Wire output → SwiftTerm.
        newEngine.outputHandler = { ansi in
            terminalView?.feed(text: ansi)
        }

        // Wire ready signal.
        newEngine.readyHandler = {
            isReady = true
            terminalView?.feed(
                text: "\u{001b}[36mFORGE engine ready.\u{001b}[0m\r\n"
            )
        }

        // Wire errors.
        newEngine.errorHandler = { message in
            errorMessage = message
        }

        bridge = newBridge
        engine = newEngine

        // Load the bundle — the bootstrap will fire __ready when done.
        newEngine.loadBundle()
    }

    private func stopEngine() {
        engine?.pause()
        engine?.teardown()
        engine = nil
        bridge = nil
        terminalView = nil
    }

    // MARK: - Project application

    /// Applies the selected project to the bridge and initializes Git if
    /// credentials are configured (§22.1).
    private func applyProject(_ project: ForgeProject) {
        bridge?.setProjectRoot(project.path)

        // Initialize Git if credentials are configured.
        if KeychainHelper.exists(for: ForgeSettingsKeys.apiKey) {
            bridge?.gitOperation(
                ["operation": "init"],
                callbackId: nil
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

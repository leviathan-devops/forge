import SwiftUI

// MARK: - Crash diagnostics

/// Installs a signal handler that prints the crashing address + backtrace
/// before the process dies. The print goes to the simulator system log.
private func installCrashHandler() {
    func handler(_ sig: Int32) {
        let bt = Thread.callStackSymbols.joined(separator: "\n")
        let msg = "FORGE CRASH signal=\(sig)\n\(bt)"
        FileHandle.standardError.write(msg.data(using: .utf8) ?? Data())
        print(msg)
        signal(sig, SIG_DFL)
        raise(sig)
    }
    signal(SIGSEGV) { sig in handler(sig) }
    signal(SIGABRT) { sig in handler(sig) }
    signal(SIGBUS) { sig in handler(sig) }
    signal(SIGILL) { sig in handler(sig) }
}

// MARK: - App Entry Point

/// FORGE application entry point.
/// Enforces dark mode, sets up the environment object, and configures the scene.
@main
struct FORGEApp: App {
    @StateObject private var appState = AppState()

    init() {
        installCrashHandler()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .tint(.forgeAccent)
        }
    }
}

// MARK: - Root View

/// Root container. LaunchMenuView is always alive so its fullScreenCover
/// (mode transitions) and internal state persist correctly.
/// Sheets for Settings and ProjectManager are attached here so they're
/// available from any mode via the shared AppState bindings.
struct RootView: View {
    @EnvironmentObject var appState: AppState

    // Launch animation state (spec §20.3): fade-in 0.3s + spring scale 0.95→1.0.
    @State private var launchOpacity: Double = 0
    @State private var launchScale: CGFloat = 0.95

    var body: some View {
        LaunchMenuView()
            .opacity(launchOpacity)
            .scaleEffect(launchScale)
            .sheet(isPresented: $appState.showingSettings) {
                SettingsSheet()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $appState.showingProjectManager) {
                ProjectManagerSheet()
                    .environmentObject(appState)
            }
            .onAppear {
                // Snappy launch: parallel fade + soft spring scale (forgeSpringSoft).
                withAnimation(.easeInOut(duration: 0.3)) {
                    launchOpacity = 1
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    launchScale = 1.0
                }
            }
    }
}

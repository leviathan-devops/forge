import SwiftUI

// MARK: - App Entry Point

/// FORGE application entry point.
/// Enforces dark mode, sets up the environment object, and configures the scene.
@main
struct FORGEApp: App {
    @StateObject private var appState = AppState()

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

    var body: some View {
        LaunchMenuView()
            .sheet(isPresented: $appState.showingSettings) {
                SettingsSheet()
            }
            .sheet(isPresented: $appState.showingProjectManager) {
                ProjectManagerSheet()
            }
    }
}

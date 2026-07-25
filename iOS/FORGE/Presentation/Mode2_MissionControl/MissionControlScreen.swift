import SwiftUI
import UIKit

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

    /// Currently visible session index in the pager.
    @State private var currentIndex: Int = 0

    /// Whether Eagle Vision (grid overview) is active.
    @State private var isInEagleVision: Bool = false

    /// Controls the server picker sheet.
    @State private var showingServerPicker = false

    var body: some View {
        ZStack {
            SwiftUI.Color.forgeBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ConnectionStatusPills(connectionManager: connectionManager)

                contentArea
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .statusBarHidden(true)
        .onAppear {
            connectionManager.start()
        }
        .onDisappear {
            connectionManager.stop()
        }
        .sheet(isPresented: $showingServerPicker) {
            ServerPickerSheet(connectionManager: connectionManager)
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
        if connectionManager.savedServers.isEmpty {
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
        HStack {
            Button {
                ForgeHaptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.forgeAccent)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("MISSION CONTROL")
                    .font(.forgeHeadline)
                    .foregroundColor(.forgePrimaryText)
                if !connectionManager.sessions.isEmpty {
                    if let session = currentSession {
                        Text("\(session.server.name) — \(session.displayName)")
                            .font(.forgeCaption)
                            .foregroundColor(.forgeSecondaryText)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Button {
                ForgeHaptics.tap()
                withAnimation(.forgeSpring) {
                    isInEagleVision.toggle()
                }
            } label: {
                Image(systemName: isInEagleVision ? "rectangle" : "square.grid.2x2")
                    .font(.system(size: 18))
                    .foregroundColor(.forgeSecondaryText)
            }

            Button {
                ForgeHaptics.tap()
                showingServerPicker = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.forgeAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(SwiftUI.Color.forgeSurface)
    }

    // MARK: - Session pager

    private var sessionPager: some View {
        SessionPagerView(
            sessions: connectionManager.sessions,
            currentIndex: $currentIndex,
            onIndexChanged: { newIndex in
                currentIndex = newIndex
            }
        )
        // Eagle Vision pinch handler overlays the pager.
        .overlay {
            EagleVisionPinchOverlay(
                isInEagleVision: $isInEagleVision,
                sessionCount: connectionManager.sessions.count
            )
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
            Text("No Servers Configured")
                .font(.forgeTitle)
                .foregroundColor(.forgePrimaryText)
            Text("No servers configured. Tap + to add an opencode server.")
                .font(.forgeBody)
                .foregroundColor(.forgeSecondaryText)
                .multilineTextAlignment(.center)

            Button {
                ForgeHaptics.tap()
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
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
                ForgeHaptics.tap()
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

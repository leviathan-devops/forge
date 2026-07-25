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

                if connectionManager.sessions.isEmpty {
                    emptyState
                } else if isInEagleVision {
                    eagleVisionGrid
                } else {
                    sessionPager
                }
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
                    let session = currentSession
                    Text("\(session.server.name) — \(session.displayName)")
                        .font(.forgeCaption)
                        .foregroundColor(.forgeSecondaryText)
                        .lineLimit(1)
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

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 56))
                .foregroundColor(.forgeSecondaryText)
            Text("No Sessions")
                .font(.forgeTitle)
                .foregroundColor(.forgePrimaryText)
            Text("Add an opencode server to discover sessions.")
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

    // MARK: - Derived

    private var currentSession: RemoteSession {
        let safeIndex = min(currentIndex, connectionManager.sessions.count - 1)
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

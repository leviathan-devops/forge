import SwiftUI

/// ConnectionStatusPills
///
/// Per FORGE Engineering Specification §16.5.
///
/// A horizontally scrollable row of server status pills. Each pill shows the
/// server name and a colored status dot (green = connected, yellow =
/// connecting, gray = disconnected, red = error). Tapping a pill refreshes
/// that server's sessions.
struct ConnectionStatusPills: View {

    @ObservedObject var connectionManager: ConnectionManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if connectionManager.savedServers.isEmpty {
                    pill(
                        name: "No servers",
                        status: .disconnected,
                        action: nil
                    )
                } else {
                    ForEach(connectionManager.savedServers) { server in
                        let status = connectionManager.serverStatus[server.id.uuidString] ?? .disconnected
                        pill(
                            name: server.name,
                            status: status,
                            action: {
                                ForgeHaptics.tap()
                                connectionManager.refreshSessions(for: server)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(SwiftUI.Color.forgeSurface)
    }

    // MARK: - Pill

    private func pill(
        name: String,
        status: ConnectionManager.ConnectionStatus,
        action: (() -> Void)?
    ) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor(for: status))
                    .frame(width: 7, height: 7)
                Text(name)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.forgePrimaryText)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(SwiftUI.Color.forgeElevated)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(SwiftUI.Color.forgeBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }

    private func dotColor(for status: ConnectionManager.ConnectionStatus) -> Color {
        switch status {
        case .connected:    return .forgeSuccess
        case .connecting:   return .forgeWarning
        case .disconnected: return .forgeSecondaryText
        case .error:        return .forgeError
        }
    }
}

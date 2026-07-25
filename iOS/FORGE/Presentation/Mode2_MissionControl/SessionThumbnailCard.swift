import SwiftUI

/// SessionThumbnailCard
///
/// Per FORGE Engineering Specification §19.3.
///
/// A single cell in the Eagle Vision grid. Displays:
/// - A miniature terminal preview (the last 5 output lines, rendered at 7 pt
///   monospaced text in the cyan accent color at 70 % opacity).
/// - A status row: green/gray connection dot + session name + server name.
/// - A Trident phase progress bar (cyan when active, gray when idle).
struct SessionThumbnailCard: View {

    let session: RemoteSession
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Miniature terminal preview.
            ZStack(alignment: .topLeading) {
                Color.forgeBackground
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(previewLines.indices, id: \.self) { i in
                        Text(previewLines[i])
                            .font(.system(size: 7, weight: .regular, design: .monospaced))
                            .foregroundColor(.forgeAccent.opacity(0.7))
                            .lineLimit(1)
                    }
                    if previewLines.isEmpty {
                        Text("—")
                            .font(.system(size: 7, weight: .regular, design: .monospaced))
                            .foregroundColor(.forgeSecondaryText)
                    }
                }
                .padding(6)
            }
            .frame(height: 120)
            .background(Color(red: 0x12/255, green: 0x12/255, blue: 0x1A/255))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Status row.
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(session.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.forgePrimaryText)
                    .lineLimit(1)
                Spacer()
                Text(session.server.name)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(.forgeSecondaryText)
                    .lineLimit(1)
            }

            // Phase progress bar.
            PhaseProgressView(
                phase: session.info.phase ?? "",
                isActive: isActive
            )
        }
        .padding(8)
        .background(Color.forgeSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isActive ? Color.forgeAccent.opacity(0.6) : Color.forgeBorder,
                    lineWidth: isActive ? 1.5 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Derived

    /// The last up-to-5 lines of output for the preview.
    private var previewLines: [String] {
        let lines = session.info.lastLines ?? []
        return Array(lines.suffix(5))
    }

    /// Connection dot color: green when active, gray otherwise.
    private var statusColor: Color {
        session.info.active ? .forgeSuccess : .forgeSecondaryText
    }
}

// MARK: - PhaseProgressView

/// A thin horizontal bar showing the current Trident phase. Cyan when the
/// session is actively running a God Loop, gray when idle.
private struct PhaseProgressView: View {

    let phase: String
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !phase.isEmpty {
                Text(phase.uppercased())
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(isActive ? .forgeAccent : .forgeSecondaryText)
                    .lineLimit(1)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.forgeSecondaryText.opacity(0.3))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActive ? Color.forgeAccent : Color.forgeSecondaryText)
                        .frame(width: isActive ? geo.size.width * 0.6 : geo.size.width * 0.15)
                }
            }
            .frame(height: 3)
        }
    }
}

import SwiftUI

/// SessionCarouselView
///
/// Per FORGE Engineering Specification §17 (Session Card Carousel).
///
/// A **vertical** card carousel that overlays Mission Control. It lists every
/// active remote session as a card — status dot, name, ACTIVE/IDLE pill,
/// agent · phase, last-2-lines preview, and a `[JOIN]` button — followed by a
/// dashed "Spawn New Session" card at the bottom. Tapping outside the card (or
/// the `xmark`) dismisses the overlay.
///
/// iPhone-first: the stack scrolls vertically (not horizontally like the iPad
/// variant). Presented from the palette's `session.view_active` command (W6).
struct SessionCarouselView: View {

    let sessions: [RemoteSessionInfo]
    let onJoin: (RemoteSessionInfo) -> Void
    let onSpawn: () -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dim backdrop — tap to close.
                SwiftUI.Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { onClose() }

                VStack(spacing: 0) {
                    header

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(sessions) { session in
                                SessionCard(session: session) {
                                    onJoin(session)
                                }
                            }
                            SpawnCard(onTap: onSpawn)
                        }
                        .padding(12)
                    }

                    Text("tap outside to close")
                        .font(.forgeCaption)
                        .foregroundColor(.forgeSecondaryText)
                        .padding(.vertical, 8)
                }
                .frame(
                    maxWidth: min(geo.size.width * 0.85, 340),
                    maxHeight: geo.size.height * 0.8
                )
                .background(SwiftUI.Color.forgeElevated)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(SwiftUI.Color.forgeAccentDim.opacity(0.5), lineWidth: 1)
                )
            }
        }
        .accessibilityIdentifier("sessionCarousel")
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("ACTIVE SESSIONS")
                .font(.forgeHeadline)
                .foregroundColor(.forgePrimaryText)
            Spacer()
            Button {
                ForgeHaptic.impact(.light)
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.forgeSecondaryText)
            }
            .accessibilityIdentifier("carouselCloseButton")
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }
}

// MARK: - SessionCard

/// A single session row: status dot, name, ACTIVE/IDLE pill, agent · phase,
/// last-2-lines preview, and a `[JOIN]` button (spec §17).
private struct SessionCard: View {
    let session: RemoteSessionInfo
    let onJoin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: status dot + name + ACTIVE/IDLE pill.
            HStack(spacing: 8) {
                Text(session.active ? "●" : "○")
                    .font(.system(size: 14))
                    .foregroundColor(session.active ? .forgeSuccess : .forgeSecondaryText)

                Text(displayName)
                    .font(.forgeHeadline)
                    .foregroundColor(.forgePrimaryText)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(session.active ? "ACTIVE" : "IDLE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.forgeAccentBright)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(SwiftUI.Color.forgeAccent.opacity(0.2))
                    .clipShape(Capsule())
            }

            // Row 2: agent · phase.
            if !metaLine.isEmpty {
                Text(metaLine)
                    .font(.forgeCaption)
                    .foregroundColor(.forgeSecondaryText)
                    .lineLimit(1)
            }

            // Row 3: last-2-lines preview (mono, ANSI stripped).
            if let preview = previewLines, !preview.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(preview, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(.forgeSecondaryText)
                            .lineLimit(1)
                    }
                }
            }

            // Row 4: [JOIN].
            HStack {
                Spacer()
                Button {
                    ForgeHaptic.impact(.light)
                    onJoin()
                } label: {
                    Text("JOIN")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.forgeBackground)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(SwiftUI.Color.forgeAccent)
                        .clipShape(Capsule())
                }
                .accessibilityIdentifier("joinButton_\(session.id)")
            }
        }
        .padding(12)
        .background(SwiftUI.Color.forgeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(SwiftUI.Color.forgeBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sessionCard_\(session.id)")
    }

    private var displayName: String {
        session.name.isEmpty ? "Session \(session.id.prefix(8))" : session.name
    }

    private var metaLine: String {
        var parts: [String] = []
        if let agent = session.agent, !agent.isEmpty { parts.append(agent) }
        if let phase = session.phase, !phase.isEmpty { parts.append(phase) }
        return parts.joined(separator: " · ")
    }

    private var previewLines: [String]? {
        guard let lines = session.lastLines, !lines.isEmpty else { return nil }
        return lines.suffix(2).map { stripANSI($0) }.filter { !$0.isEmpty }
    }

    /// Strips ANSI escape sequences from a terminal line for the card preview.
    private func stripANSI(_ text: String) -> String {
        var out = ""
        var inEscape = false
        for char in text {
            if char == "\u{001B}" { inEscape = true; continue }
            if inEscape {
                if char.isLetter { inEscape = false }
                continue
            }
            out.append(char)
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - SpawnCard

/// Dashed "Spawn New Session" affordance at the bottom of the carousel.
private struct SpawnCard: View {
    let onTap: () -> Void

    var body: some View {
        Button {
            ForgeHaptic.impact(.medium)
            onTap()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.forgeAccentBright)
                Text("Spawn New Session")
                    .font(.forgeHeadline)
                    .foregroundColor(.forgePrimaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.forgeSecondaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(SwiftUI.Color.forgeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        SwiftUI.Color.forgeAccentDim.opacity(0.6),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
        }
        .accessibilityIdentifier("spawnCard")
        .accessibilityLabel("Spawn New Session")
    }
}

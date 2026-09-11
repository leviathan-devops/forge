import SwiftUI

/// SessionThumbnailCard
///
/// Eagle Vision rolodex cell — shows a MINIATURE LIVE STREAM of the session's
/// actual chat TUI: fetches GET /session/{id}/message, maps into the shared
/// ChatMessage/Part model, and renders the last few parts at 6-7pt mono so you
/// can SEE the active agent loop (Thinking blocks, tool rows, prose) from the
/// kanban grid. Polls every 4s.
struct SessionThumbnailCard: View {

    let session: RemoteSession
    let isActive: Bool

    @State private var messages: [ChatMessage] = []
    @State private var pollTask: Task<Void, Never>?
    @State private var skippedLarge = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Miniature LIVE chat preview.
            ZStack(alignment: .topLeading) {
                SwiftUI.Color.forgeBackground
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(miniParts) { mini in
                        Text(mini.text)
                            .font(.system(size: 7, weight: mini.bold ? .semibold : .regular,
                                          design: .monospaced))
                            .foregroundColor(mini.color)
                            .italic(mini.italic)
                            .lineLimit(1)
                    }
                    if miniParts.isEmpty {
                        Text(skippedLarge ? "Large session — tap to open" : "No activity yet")
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
        .background(SwiftUI.Color.forgeSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isActive ? SwiftUI.Color.forgeAccent.opacity(0.6) : SwiftUI.Color.forgeBorder,
                    lineWidth: isActive ? 1.5 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear { startPolling() }
        .onDisappear { pollTask?.cancel() }
    }

    // MARK: - Mini chat stream

    private struct MiniLine: Identifiable {
        let id = UUID()
        let text: String
        let color: SwiftUI.Color
        let italic: Bool
        let bold: Bool
    }

    /// The last up-to-6 rendered parts as single-line mini entries.
    private var miniParts: [MiniLine] {
        var lines: [MiniLine] = []
        for message in messages {
            for part in message.parts {
                switch part.kind {
                case .thinking:
                    let t = part.text.replacingOccurrences(of: "\n", with: " ")
                    lines.append(MiniLine(text: "Thinking: \(String(t.prefix(60)))",
                                         color: .forgeSecondaryText, italic: true, bold: false))
                case .prose:
                    let t = part.text.replacingOccurrences(of: "\n", with: " ")
                    lines.append(MiniLine(text: String(t.prefix(70)),
                                         color: .forgePrimaryText, italic: false, bold: false))
                case .tool:
                    let name = part.tool?.name ?? "tool"
                    let title = part.tool?.title ?? ""
                    let ok = part.tool.map { if case .done(let o) = $0.status { return o } else { return false } } ?? false
                    let glyph = ok ? "✓" : "~"
                    lines.append(MiniLine(text: "\(glyph) \(name) \(title)",
                                         color: ok ? .forgeSuccess : .forgeAccent, italic: false, bold: false))
                case .write:
                    lines.append(MiniLine(text: "▸ \(part.write?.path ?? "") — \(part.write?.bytes ?? 0) bytes",
                                         color: .forgeAccent, italic: false, bold: false))
                case .turnFooter:
                    lines.append(MiniLine(text: part.text, color: .forgeSecondaryText,
                                          italic: false, bold: false))
                case .statusBanner:
                    lines.append(MiniLine(text: part.text, color: .forgeSuccess,
                                          italic: false, bold: true))
                default:
                    break
                }
            }
        }
        return Array(lines.suffix(6))
    }

    private func startPolling() {
        pollTask?.cancel()
        fetch()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run { self.fetch() }
            }
        }
    }

    /// Fetches the session's messages. Sessions with HUGE transcripts
    /// (historical builds, > 20 MB) are skipped to avoid per-card memory/
    /// timeout bombs — the LIVE streaming sessions (small, recent) always load.
    private func fetch() {
        guard let url = URL(string: "\(session.server.baseURL)/session/\(session.id)/message") else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        URLSession.shared.dataTask(with: req) { data, resp, _ in
            // Guard: skip multi-megabyte transcripts (huge historical sessions).
            if let http = resp as? HTTPURLResponse,
               http.expectedContentLength > 20_000_000 {
                DispatchQueue.main.async {
                    self.messages = []
                    self.skippedLarge = true
                }
                return
            }
            guard let data = data,
                  let envelopes = try? JSONDecoder().decode(
                    [RemoteMessageEnvelope].self, from: data) else { return }
            let mapped = RemoteMessageMapper.map(envelopes)
            DispatchQueue.main.async {
                self.messages = mapped
                self.skippedLarge = false
            }
        }.resume()
    }

    private var statusColor: SwiftUI.Color {
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
                        .fill(SwiftUI.Color.forgeSecondaryText.opacity(0.3))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActive ? SwiftUI.Color.forgeAccent : SwiftUI.Color.forgeSecondaryText)
                        .frame(width: isActive ? geo.size.width * 0.6 : geo.size.width * 0.15)
                }
            }
            .frame(height: 3)
        }
    }
}

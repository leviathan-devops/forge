import SwiftUI

// MARK: - DialogSessionListView

/// Session list / resume picker (spec §11.6). Renders the demo project's root
/// sessions grouped TODAY / EARLIER by `time_updated`. Row: title + model +
/// relative time. Tap → `onSelect(session.id)` → `onClose()`; the host loads
/// messages and navigates.
///
/// Uses the same chrome as `DialogSelectView` (dim backdrop, search filter,
/// tap-outside close) but owns its grouping + row layout because sessions need
/// the TODAY/EARLIER split and relative-time formatting that the generic
/// `DialogOption` shape can't express.
struct DialogSessionListView: View {
    let title: String
    let sessions: [SessionInfo]
    let onSelect: (String) -> Void
    let onClose: () -> Void

    @State private var filter = ""

    // MARK: - Filtering

    /// Multi-token AND, case-insensitive over the session title only.
    private var filtered: [SessionInfo] {
        let q = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return sessions }
        let tokens = q.split(separator: " ")
        return sessions.filter { s in
            let hay = s.title.lowercased()
            return tokens.allSatisfy { hay.contains($0) }
        }
    }

    /// TODAY = `time_updated` is within the current calendar day; else EARLIER.
    /// Order within a group is the input order (sessions are passed newest-first).
    private var grouped: [(String, [SessionInfo])] {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        var today: [SessionInfo] = []
        var earlier: [SessionInfo] = []
        for s in filtered {
            let date = Date(timeIntervalSince1970: TimeInterval(s.timeUpdated) / 1000.0)
            if date >= startOfToday {
                today.append(s)
            } else {
                earlier.append(s)
            }
        }
        var out: [(String, [SessionInfo])] = []
        if !today.isEmpty { out.append(("Today", today)) }
        if !earlier.isEmpty { out.append(("Earlier", earlier)) }
        return out
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(.forgeHeadline)
                        .foregroundColor(.forgePrimaryText)
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.forgeSecondaryText)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("dialogClose")
                }
                .padding(10)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.forgeSecondaryText)
                    TextField("Search sessions", text: $filter)
                        .font(.forgeBody)
                        .foregroundColor(.forgePrimaryText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .accessibilityIdentifier("sessionSearch")
                }
                .padding(10)
                .background(Color.forgeSurface)

                Divider().overlay(Color.forgeAccentDim.opacity(0.3))

                if sessions.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                                Text(group.0.uppercased())
                                    .font(.forgeCaption)
                                    .foregroundColor(.forgeAccentBright)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 8)

                                ForEach(group.1, id: \.id) { s in
                                    sessionRow(s)
                                }
                            }
                        }
                    }
                }

                Text("tap outside to close")
                    .font(.forgeCaption)
                    .foregroundColor(.forgeSecondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color.forgeSurface)
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width * 0.8, 360),
                   maxHeight: UIScreen.main.bounds.height * 0.8)
            .background(Color.forgeElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.forgeAccentDim.opacity(0.4), lineWidth: 1)
            )
            .accessibilityAddTraits(.isModal)
        }
    }

    // MARK: - Row

    /// Title on top, model + relative time beneath. Tapping selects the session.
    @ViewBuilder
    private func sessionRow(_ s: SessionInfo) -> some View {
        Button {
            onSelect(s.id)
            onClose()
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text("▶")
                    .foregroundColor(.forgeAccent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.title)
                        .foregroundColor(.forgePrimaryText)
                        .font(.forgeBody)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(Self.modelDisplayName(s.model))
                        Text("·")
                        Text(Self.relativeTime(timeUpdatedMs: s.timeUpdated))
                    }
                    .font(.forgeCaption)
                    .foregroundColor(.forgeSecondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier("dialogRow_\(s.id)")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 24)
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundColor(.forgeSecondaryText)
            Text("No sessions yet")
                .font(.forgeBody)
                .foregroundColor(.forgeSecondaryText)
            Text("Start a new session from the palette.")
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryText.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("sessionListEmpty")
    }

    // MARK: - Formatting helpers

    /// Decode the `session.model` JSON (`{"id":"...","providerID":"..."}`) and
    /// return the id, or `"default"` when absent/unreadable.
    static func modelDisplayName(_ raw: String?) -> String {
        guard let raw,
              let data = raw.data(using: .utf8),
              let ref = try? JSONDecoder().decode(ModelRef.self, from: data)
        else { return "default" }
        return ref.id
    }

    /// Relative time ("3h ago", "yesterday"). Uses a cached
    /// `RelativeDateTimeFormatter` for cheap repeated calls.
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    static func relativeTime(timeUpdatedMs: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timeUpdatedMs) / 1000.0)
        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

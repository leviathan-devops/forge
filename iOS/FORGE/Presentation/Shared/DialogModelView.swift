import SwiftUI

// MARK: - DialogModelView

/// Model picker rebuilt to match the REAL opencode "Select model" popup
/// (measured from the operator's reference screenshots):
///
/// - Sharp corners, thin 1px dark border
/// - Header: `Select model` left + `esc` right
/// - `Search` label (dim) above the filter field
/// - Sections: `Recent` (usage history) then provider groups
/// - Rows: model display name (white) + provider (dim) + `Free` badge right
/// - Selected row: SOLID ORANGE full-width bar (opencode's amber selection)
/// - Footer: dim `Connect provider ctrl+a   Favorite ctrl+f`
struct DialogModelView: View {
    let currentModel: String
    let onSelect: (String) -> Void
    let onClose: () -> Void

    @State private var filter = ""
    @State private var recent: [String] = DialogModelView.loadRecent()
    @ObservedObject private var catalogStore = ZenModelCatalog.shared

    // MARK: - Derived

    private var filtered: [ZenModelCatalog.Entry] {
        let q = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return catalogStore.entries }
        let tokens = q.split(separator: " ")
        return catalogStore.entries.filter { entry in
            let hay = "\(entry.displayName) \(entry.provider) \(entry.id)".lowercased()
            return tokens.allSatisfy { hay.contains($0) }
        }
    }

    /// Sections in opencode order: Recent first, then provider groups.
    private var grouped: [(String, [ZenModelCatalog.Entry])] {
        var out: [(String, [ZenModelCatalog.Entry])] = []
        let filterActive = !filter.trimmingCharacters(in: .whitespaces).isEmpty

        if !filterActive {
            let recentEntries = recent.compactMap { id in filtered.first { $0.id == id } }
            if !recentEntries.isEmpty { out.append(("Recent", recentEntries)) }
            // Provider groups (skip Recent duplicates)
            let groupedByProvider = Dictionary(grouping: filtered) { $0.provider }
            for (provider, entries) in groupedByProvider.sorted(by: { $0.key < $1.key }) {
                let nonRecent = entries.filter { !recent.contains($0.id) }
                if !nonRecent.isEmpty { out.append((provider, nonRecent)) }
            }
        } else {
            out.append(("All", filtered))
        }
        return out
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }
                .task { await catalogStore.refresh() }

            VStack(spacing: 0) {
                // Header: "Select model" + esc
                HStack {
                    Text("Select model")
                        .font(.forgeBody)
                        .foregroundColor(.forgePrimaryText)
                    Spacer()
                    Text("esc")
                        .font(.forgeBody)
                        .foregroundColor(.forgeSecondaryText)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)

                Divider().overlay(Color.forgeBorder.opacity(0.6))

                // Search label + field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search")
                        .font(.forgeCaption)
                        .foregroundColor(.forgeSecondaryText)
                    TextField("", text: $filter)
                        .font(.forgeBody)
                        .foregroundColor(.forgePrimaryText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 6)

                Divider().overlay(Color.forgeBorder.opacity(0.4))

                // Model list — opencode rows
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                            Text(group.0)
                                .font(.forgeCaption)
                                .foregroundColor(.forgeAccentBright)
                                .padding(.horizontal, 14)
                                .padding(.top, 10)
                                .padding(.bottom, 2)

                            ForEach(group.1, id: \.id) { entry in
                                Button {
                                    choose(entry.id)
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(entry.displayName)
                                            .font(.forgeBody)
                                            .foregroundColor(.forgePrimaryText)
                                            .lineLimit(1)
                                        Text(entry.provider)
                                            .font(.forgeCaption)
                                            .foregroundColor(.forgeSecondaryText)
                                        Spacer(minLength: 4)
                                        if entry.free {
                                            Text("Free")
                                                .font(.forgeCaption)
                                                .foregroundColor(.forgeSecondaryText)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        currentModel == entry.id
                                            ? Color.forgeAccent.opacity(0.85)
                                            : Color.clear
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityIdentifier("dialogRow_\(entry.id)")
                            }
                        }
                    }
                }

                // Footer action hints (opencode style)
                HStack {
                    Text("Connect provider")
                    Text("ctrl+a")
                    Spacer()
                    Text("Favorite")
                    Text("ctrl+f")
                }
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.forgeSurface)
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width * 0.82, 380),
                   maxHeight: UIScreen.main.bounds.height * 0.78)
            .background(Color.forgeElevated)
            .overlay(
                Rectangle()
                    .stroke(Color.forgeBorder.opacity(0.8), lineWidth: 1)
            )
            .accessibilityAddTraits(.isModal)
        }
    }

    // MARK: - Selection + recent persistence

    private func choose(_ id: String) {
        onSelect(id)
        var updated = recent.filter { $0 != id }
        updated.insert(id, at: 0)
        if updated.count > 10 { updated = Array(updated.prefix(10)) }
        recent = updated
        Self.saveRecent(updated)
        onClose()
    }

    private static let recentKey = "forge.recentModels"

    private static func loadRecent() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: recentKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return decoded
    }

    private static func saveRecent(_ ids: [String]) {
        guard let data = try? JSONEncoder().encode(ids) else { return }
        UserDefaults.standard.set(data, forKey: recentKey)
    }
}

import SwiftUI

// MARK: - PaletteEntry

/// A command pre-evaluated against the current `SessionContext` for display.
/// `suggested` is resolved to a Bool here (it is a closure on `ForgeCommand`).
struct PaletteEntry: Identifiable {
    let id = UUID()
    let name: String
    let title: String
    let desc: String?
    let category: String
    let suggested: Bool
    let command: ForgeCommand
}

// MARK: - CommandPaletteView

/// Ctrl+P port rebuilt to match the REAL opencode command palette (measured
/// from the operator's reference screenshots):
///
/// - Sharp corners, 1px bright border (opencode popups have NO rounding)
/// - Header row: `Commands` left + `esc` right
/// - `Search` section (violet header) above the filter field
/// - Sections with VIOLET headers; rows = title left + shortcut right
/// - Selected row: SOLID ORANGE full-width highlight bar (opencode's amber
///   selection — not a pale outline)
/// - Text-only rows (opencode has NO icons in the palette)
/// - Footer: dim "esc to close · enter to select" hints (not "tap outside")
struct CommandPaletteView: View {
    let context: SessionContext
    let onClose: () -> Void

    @State private var filter = ""
    @State private var selectedIndex = 0

    // MARK: Derived lists

    private var allEntries: [PaletteEntry] {
        CommandRegistry.entries(for: context).map { cmd in
            PaletteEntry(
                name: cmd.name,
                title: cmd.title,
                desc: cmd.desc,
                category: cmd.category.rawValue.capitalized,
                suggested: cmd.suggested(context),
                command: cmd
            )
        }
    }

    private var visible: [PaletteEntry] {
        let query = filter.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return allEntries }
        return allEntries.filter { matches($0, query) }
    }

    /// Rendered rows preserving opencode's section order (no shortcut column —
    /// iOS is not keyboard-native; the operator removed shortcuts).
    private var listRows: [PaletteRow] {
        let filterIsEmpty = filter.trimmingCharacters(in: .whitespaces).isEmpty
        if filterIsEmpty {
            let suggested = visible.filter(\.suggested).map {
                PaletteRow(title: $0.title, category: "Suggested",
                           value: "suggested:\($0.name)", command: $0.command)
            }
            let rest = visible.map {
                PaletteRow(title: $0.title, category: $0.category,
                           value: $0.name, command: $0.command)
            }
            return suggested + rest
        }
        return visible.map {
            PaletteRow(title: $0.title, category: $0.category,
                       value: $0.name, command: $0.command)
        }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                // Header: "Commands" + "esc" (opencode layout)
                HStack {
                    Text("Commands")
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

                // Search section header + filter field (opencode: label above)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Search")
                        .font(.forgeCaption)
                        .foregroundColor(.forgeAccentBright)
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

                // Command list — opencode rows: title left, shortcut right,
                // selected row = SOLID ORANGE bar.
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(listRows.enumerated()), id: \.element.value) { idx, row in
                            VStack(alignment: .leading, spacing: 0) {
                                // Section header (only when the category changes)
                                if idx == 0 || listRows[idx - 1].category != row.category {
                                    Text(row.category)
                                        .font(.forgeCaption)
                                        .foregroundColor(.forgeAccentBright)
                                        .padding(.horizontal, 14)
                                        .padding(.top, 10)
                                        .padding(.bottom, 2)
                                }
                                Button {
                                    selectedIndex = idx
                                    onClose()
                                    Task {
                                        try? await CommandRegistry.dispatch(
                                            row.command.name, in: context
                                        )
                                    }
                                } label: {
                                    HStack {
                                        Text(row.title)
                                            .font(.forgeBody)
                                            .foregroundColor(.forgePrimaryText)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        selectedIndex == idx
                                            ? Color.forgeAccent.opacity(0.85)
                                            : Color.clear
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityIdentifier("paletteRow_\(row.value)")
                            }
                        }
                    }
                }
                .onAppear { selectedIndex = 0 }

                // Footer hints (opencode style — dim, keyboard-first)
                HStack {
                    Text("esc to close")
                    Spacer()
                    Text("enter to select")
                }
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.forgeSurface)
            }
            // SHARP corners — opencode popups are rectangles, not rounded.
            .frame(maxWidth: min(UIScreen.main.bounds.width * 0.82, 380),
                   maxHeight: UIScreen.main.bounds.height * 0.78)
            .background(Color.forgeElevated)
            .overlay(
                Rectangle()
                    .stroke(Color.forgeBorder.opacity(0.9), lineWidth: 1)
            )
            .accessibilityAddTraits(.isModal)
        }
    }

    // MARK: - Row model

    private struct PaletteRow: Identifiable {
        let id = UUID()
        let title: String
        let category: String
        let value: String
        let command: ForgeCommand
    }

    // MARK: - Filtering

    private func matches(_ entry: PaletteEntry, _ query: String) -> Bool {
        let haystack = (entry.title + " "
                        + (entry.desc ?? "") + " "
                        + entry.name + " "
                        + entry.category).lowercased()
        let tokens = query.lowercased().split(separator: " ")
        return tokens.allSatisfy { haystack.contains($0) }
    }
}

import SwiftUI

// MARK: - DialogOption

/// A single selectable row in a `DialogSelectView` (spec §11.1, verbatim from
/// `dialog-select.tsx` hash `ae07cd…`). `onSelect` is optional so the host can
/// react to the tap itself via the view's callbacks.
struct DialogOption: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let description: String?
    let category: String?
    let suggested: Bool
    let onSelect: (() -> Void)?

    init(title: String,
         value: String,
         description: String? = nil,
         category: String? = nil,
         suggested: Bool = false,
         onSelect: (() -> Void)? = nil) {
        self.title = title
        self.value = value
        self.description = description
        self.category = category
        self.suggested = suggested
        self.onSelect = onSelect
    }
}

// MARK: - DialogSelectView

/// Generic grouped picker (spec §11.2). Same visual chrome as the command palette
/// — dim backdrop, elevated card, search field, grouped list, tap-outside close.
/// Used by the model/agent/session-list dialogs.
struct DialogSelectView: View {
    let title: String
    let options: [DialogOption]
    let onClose: () -> Void

    @State private var filter = ""

    // MARK: Derived lists

    /// Multi-token AND, case-insensitive filter over title + description.
    private var filtered: [DialogOption] {
        let query = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return options }
        let tokens = query.split(separator: " ")
        return options.filter { opt in
            tokens.allSatisfy { token in
                opt.title.lowercased().contains(token)
                || (opt.description?.lowercased().contains(token) ?? false)
            }
        }
    }

    /// Grouped, preserving first-seen category order. When the filter is empty,
    /// a synthetic "Suggested" group is prepended containing every option flagged
    /// `suggested` (mirrors the palette's Suggested behavior).
    private var grouped: [(String, [DialogOption])] {
        let filterIsEmpty = filter.trimmingCharacters(in: .whitespaces).isEmpty
        var order: [String] = []
        var buckets: [String: [DialogOption]] = [:]
        for opt in filtered {
            let key = opt.category ?? "Other"
            if buckets[key] == nil { order.append(key); buckets[key] = [] }
            buckets[key]?.append(opt)
        }
        var out: [(String, [DialogOption])] = []
        if filterIsEmpty {
            let suggested = filtered.filter { $0.suggested }
            if !suggested.isEmpty { out.append(("Suggested", suggested)) }
        }
        for key in order {
            if key == "Suggested" { continue }
            out.append((key, buckets[key] ?? []))
        }
        return out
    }

    // MARK: Body

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                // Title bar
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

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.forgeSecondaryText)
                    TextField("Search", text: $filter)
                        .font(.forgeBody)
                        .foregroundColor(.forgePrimaryText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                .padding(10)
                .background(Color.forgeSurface)

                Divider().overlay(Color.forgeAccentDim.opacity(0.3))

                // Grouped list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(grouped.enumerated()), id: \.offset) { _, group in
                            Text(group.0.uppercased())
                                .font(.forgeCaption)
                                .foregroundColor(.forgeAccentBright)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                            ForEach(group.1, id: \.value) { opt in
                                Button {
                                    opt.onSelect?()
                                    onClose()
                                } label: {
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("▶")
                                            .foregroundColor(.forgeAccent)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(opt.title)
                                                .foregroundColor(.forgePrimaryText)
                                                .font(.forgeBody)
                                            if let desc = opt.description {
                                                Text(desc)
                                                    .font(.forgeCaption)
                                                    .foregroundColor(.forgeSecondaryText)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityIdentifier("dialogRow_\(opt.value)")
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
}

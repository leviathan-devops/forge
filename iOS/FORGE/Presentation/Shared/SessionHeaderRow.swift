import SwiftUI

// MARK: - SessionHeaderRow

/// Fixed SwiftUI row rendered ABOVE the terminal (spec §7, opencode-TUI style).
/// Left: `# {session title}` bold + model · provider caption (dim).
/// Right: `{tokens}  {pct}% (${cost})` — mirrors the opencode TUI header
/// (`# session-title` left, `39,413  20% ($0.29)` right).
struct SessionHeaderRow: View {
    /// Leading title, e.g. `"FORGE-Demo"` — rendered bold with a `#` prefix.
    let title: String

    /// Dim caption under the title: `"deepseek-v4-flash · OpenCode Zen"`.
    var subtitle: String? = nil

    /// Trailing token/cost summary, e.g. `"21.4K  2% ($0.02)"` — opencode
    /// renders this on the right edge of the header.
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text("# \(title)")
                .font(.forgeCaption.weight(.bold))
                .foregroundColor(.forgePrimaryText)
                .lineLimit(1)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.forgeCaption)
                    .foregroundColor(.forgeSecondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(.forgeCaption)
                    .foregroundColor(.forgeSecondaryText)
                    .lineLimit(1)
                    .accessibilityIdentifier("sessionHeaderTrailing")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.forgeSurface)
        .accessibilityIdentifier("sessionHeaderRow")
    }
}

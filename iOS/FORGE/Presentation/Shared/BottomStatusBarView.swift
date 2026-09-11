import SwiftUI

// MARK: - BottomStatusBarView

/// Single-row bottom status bar (opencode-TUI structure, fire-orange theme).
/// Mirrors the real opencode status bar:
/// `agent forge-full-featured │ 1333 tokens │ 18% context left │ 43.03m cost`
///
/// FORGE renders: `agent trident │ deepseek-v4-flash-free │ 6.3K tokens │
/// 1% context │ $0.01` with pipe separators, left-aligned.
struct BottomStatusBarView: View {
    let agent: String          // "trident"
    let model: String          // "deepseek-v4-flash-free"
    let provider: String       // "OpenCode Zen"
    let tokensUsed: Int        // accumulated this session
    var contextWindow: Int = 1_000_000
    let cost: Double           // session.cost

    var body: some View {
        HStack(spacing: 6) {
            Text(agent)
                .font(.forgeCaption.weight(.bold))
                .foregroundColor(.forgePrimaryText)
                .lineLimit(1)
            Text("│")
                .font(.forgeCaption)
                .foregroundColor(.forgeAccent)
            Text(model)
                .font(.forgeCaption.weight(.semibold))
                .foregroundColor(.forgeAccentBright)
                .lineLimit(1)
            Text("│")
                .font(.forgeCaption)
                .foregroundColor(.forgeAccent)
            Text(tokenLabel)
                .font(.forgeCaption)
                .foregroundColor(.forgePrimaryText)
                .lineLimit(1)
            Text("│")
                .font(.forgeCaption)
                .foregroundColor(.forgeAccent)
            Text(contextLabel)
                .font(.forgeCaption)
                .foregroundColor(.forgePrimaryText)
                .lineLimit(1)
            Text("│")
                .font(.forgeCaption)
                .foregroundColor(.forgeAccent)
            Text(costLabel)
                .font(.forgeCaption)
                .foregroundColor(.forgeAccentBright)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 26)          // FIXED height — nothing can wrap/squish.
        .background(
            LinearGradient(
                colors: [Color.forgeAccent.opacity(0.22), Color.forgeAccent.opacity(0.10)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .overlay(
            Rectangle()
                .fill(Color.forgeAccent.opacity(0.35))
                .frame(height: 1),
            alignment: .top
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bottomStatusBar")
    }

    // MARK: - Labels (opencode format)

    private var tokenLabel: String {
        formatTokens(tokensUsed)
    }

    private var contextLabel: String {
        let window = max(contextWindow, 1)
        let pct = Double(tokensUsed) / Double(window) * 100
        return String(format: "%.0f%% context", pct)
    }

    private var costLabel: String {
        String(format: "$%.2f", cost)
    }

    /// K/M token format: `6.3K tokens` (opencode uses raw counts; K/M keeps
    /// the row compact on iPhone).
    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM tokens", Double(n) / 1e6) }
        if n >= 1_000 { return String(format: "%.1fK tokens", Double(n) / 1e3) }
        return "\(n) tokens"
    }
}

import SwiftUI

// MARK: - Top Bar

/// Spec §6 top bar. Three chrome controls only: back chevron (‹), title, and a
/// hamburger (☰) that presents the command palette. No gear, no sidebar toggle,
/// no network dot — those surfaces move into the palette (☰).
///
/// `onBack` and `onMenu` are optional so title-only / menu-less screens still
/// compile; the buttons render only when their callback is supplied.
struct TopBar: View {
    let title: String
    var onBack: (() -> Void)? = nil
    var onMenu: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Centered title.
            Text(title)
                .font(.forgeBodyMono)
                .foregroundStyle(SwiftUI.Color.forgePrimaryText)
                .tracking(1)
                .lineLimit(1)

            HStack {
                if let onBack = onBack {
                    Button(action: {
                        ForgeHaptic.impact(.light)
                        onBack()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(SwiftUI.Color.forgeAccent)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("backButton")
                    .accessibilityLabel("Back")
                }

                Spacer()
            }

            HStack {
                Spacer()

                if let onMenu = onMenu {
                    Button(action: {
                        ForgeHaptic.impact(.light)
                        onMenu()
                    }) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 17))
                            .foregroundStyle(SwiftUI.Color.forgeAccent)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("menuButton")
                    .accessibilityLabel("Open command palette")
                }
            }
        }
        .frame(height: ForgeMetrics.topBarHeight)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .background(SwiftUI.Color.forgeSurface.opacity(0.95))
        .overlay(
            Rectangle()
                .fill(SwiftUI.Color.forgeBorder)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// MARK: - Preview

#Preview("Top Bar — Back + Menu") {
    VStack {
        TopBar(
            title: "FORGE",
            onBack: {},
            onMenu: {}
        )
        Spacer()
    }
    .background(SwiftUI.Color.forgeBackground)
    .preferredColorScheme(.dark)
}

#Preview("Top Bar — Title Only") {
    VStack {
        TopBar(title: "PROJECTS")
        Spacer()
    }
    .background(SwiftUI.Color.forgeBackground)
    .preferredColorScheme(.dark)
}

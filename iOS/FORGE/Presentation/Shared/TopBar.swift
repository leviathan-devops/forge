import SwiftUI

// MARK: - Top Bar Button

/// Configuration for the optional right-side button in the top bar.
struct TopBarButton {
    let icon: String
    let label: String
    let action: () -> Void

    init(icon: String, label: String = "", action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.action = action
    }
}

// MARK: - Top Bar

/// A 44pt navigation bar with an optional back chevron, centered title,
/// and an optional right-side button.
///
/// Per spec section 16: Standardized top bar for all screens.
struct TopBar: View {
    let title: String
    var onBack: (() -> Void)? = nil
    var rightIcon: String? = nil
    var rightLabel: String = ""
    var onRightTap: (() -> Void)? = nil

    var body: some View {
        ZStack {
            // Centered title
            Text(title)
                .font(.forgeBodyMono)
                .foregroundStyle(SwiftUI.Color.forgePrimaryText)
                .tracking(1)
                .lineLimit(1)

            // Left side — back button
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
                }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("backButton")
                }

                Spacer()
            }

            // Right side — action button
            HStack {
                Spacer()

                if let rightIcon = rightIcon, let onRightTap = onRightTap {
                    Button(action: {
                        ForgeHaptic.impact(.light)
                        onRightTap()
                    }) {
                        Image(systemName: rightIcon)
                            .font(.system(size: 17))
                            .foregroundStyle(SwiftUI.Color.forgeSecondaryText)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
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

#Preview("Top Bar with Back") {
    VStack {
        TopBar(
            title: "BUILD ON-DEVICE",
            onBack: {},
            rightIcon: "gearshape",
            rightLabel: "Settings",
            onRightTap: {}
        )
        Spacer()
    }
    .background(SwiftUI.Color.forgeBackground)
    .preferredColorScheme(.dark)
}

#Preview("Top Bar Title Only") {
    VStack {
        TopBar(title: "PROJECTS")
        Spacer()
    }
    .background(SwiftUI.Color.forgeBackground)
    .preferredColorScheme(.dark)
}

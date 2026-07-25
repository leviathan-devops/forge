import SwiftUI

// MARK: - Network Status

/// Network / credential status displayed as a colored dot in the top bar.
///
/// - `.configured`: API key is present and has been verified reachable.
///   Shown as a solid green dot.
/// - `.unverified`: API key is present but has not been verified yet.
///   Shown as a solid yellow dot.
/// - `.missing`: No API key configured. Shown as a solid red dot.
/// - `.hidden`: Indicator is not displayed (e.g. on screens where it is
///   irrelevant, such as Mission Control).
enum NetworkStatus {
    case configured
    case unverified
    case missing
    case hidden

    /// The dot color for this status.
    var color: SwiftUI.Color {
        switch self {
        case .configured: return .forgeSuccess
        case .unverified: return .forgeWarning
        case .missing:    return .forgeError
        case .hidden:     return .clear
        }
    }
}

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
/// an optional right-side button, and an optional network status indicator.
///
/// Per spec section 16: Standardized top bar for all screens.
struct TopBar: View {
    let title: String
    var onBack: (() -> Void)? = nil
    var rightIcon: String? = nil
    var rightLabel: String = ""
    var onRightTap: (() -> Void)? = nil

    /// When non-`.hidden`, a small colored dot is rendered to the left of the
    /// right-side button. Green = API key configured and verified, yellow =
    /// configured but unverified, red = no API key.
    var networkStatus: NetworkStatus = .hidden

    /// When `true`, the right-side icon pulses with a cyan glow to draw the
    /// user's attention (e.g. when an API key is missing).
    var rightIconNeedsAttention: Bool = false

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

                Spacer()
            }

            // Right side — status dot + action button
            HStack(spacing: 6) {
                Spacer()

                // Network status indicator (§Task 4)
                if networkStatus != .hidden {
                    Circle()
                        .fill(networkStatus.color)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(networkStatus.color.opacity(0.3), lineWidth: 3)
                                .frame(width: 8, height: 8)
                                .blur(radius: 1)
                        )
                        .accessibilityLabel(statusAccessibilityLabel)
                }

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
                            .modifier(GearPulseModifier(isActive: rightIconNeedsAttention))
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

    // MARK: - Accessibility

    private var statusAccessibilityLabel: String {
        switch networkStatus {
        case .configured: return "API key configured and verified"
        case .unverified: return "API key configured but not verified"
        case .missing:    return "No API key configured"
        case .hidden:     return ""
        }
    }
}

// MARK: - Gear Pulse Modifier

/// Applies a repeating cyan glow pulse to a view when `isActive` is true.
/// Used to draw attention to the settings gear when action is required.
private struct GearPulseModifier: ViewModifier {
    let isActive: Bool
    @State private var pulse = false

    func body(content: Content) -> some View {
        if isActive {
            content
                .foregroundStyle(SwiftUI.Color.forgeAccent)
                .shadow(
                    color: SwiftUI.Color.forgeAccent.opacity(pulse ? 0.7 : 0.15),
                    radius: pulse ? 10 : 3
                )
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 0.9)
                        .repeatForever(autoreverses: true)
                    ) {
                        pulse = true
                    }
                }
        } else {
            content
        }
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

#Preview("Top Bar — No API Key (Red Dot + Pulsing Gear)") {
    VStack {
        TopBar(
            title: "FORGE",
            onBack: {},
            rightIcon: "gearshape",
            rightLabel: "Settings",
            onRightTap: {},
            networkStatus: .missing,
            rightIconNeedsAttention: true
        )
        Spacer()
    }
    .background(SwiftUI.Color.forgeBackground)
    .preferredColorScheme(.dark)
}

#Preview("Top Bar — API Key Configured (Green Dot)") {
    VStack {
        TopBar(
            title: "FORGE",
            onBack: {},
            rightIcon: "gearshape",
            rightLabel: "Settings",
            onRightTap: {},
            networkStatus: .configured
        )
        Spacer()
    }
    .background(SwiftUI.Color.forgeBackground)
    .preferredColorScheme(.dark)
}

import SwiftUI

// MARK: - Mode Card

/// A reusable card component for selecting a FORGE operational mode.
///
/// Displays an icon, title, and subtitle in a FORGE-themed card with
/// tap animation (spring 0.4s) and haptic feedback.
///
/// Per spec section 17: Mode selection cards.
struct ModeCard: View {
    let mode: ForgeMode
    @Binding var isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: handleTap) {
            cardContent
                .scaleEffect(isPressed ? 0.96 : 1.0)
                .opacity(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(mode.rawValue)
        // Keep tappable; selection is visual feedback only during transition.
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(spacing: ForgeMetrics.standardPadding) {
            // Icon
            Image(systemName: mode.icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(SwiftUI.Color.forgeAccent)
                .frame(width: 48, height: 48)
                .forgeGlow()

            // Title + Subtitle
            VStack(spacing: 6) {
                Text(mode.displayName)
                    .font(.forgeHeadline)
                    .foregroundStyle(SwiftUI.Color.forgePrimaryText)
                    .tracking(1)

                Text(mode.subtitle)
                    .font(.forgeBody)
                    .foregroundStyle(SwiftUI.Color.forgeSecondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        // minHeight (not fixed height): cards grow with content. The
        // MISSION CONTROL subtitle was shortened to 3 lines (operator
        // directive 2026-08-29); the grow-with-content frame stays so copy
        // changes can never clip again. AGENT MODE stays 140 (2-line copy).
        .frame(minHeight: 140)
        .padding(.horizontal, 20)
        .forgeCard(isElevated: isSelected)
        .contentShape(Rectangle())
    }

    // MARK: - Interaction

    private func handleTap() {
        ForgeHaptic.impact(.light)

        withAnimation(ForgeAnimation.cardTap) {
            isPressed = true
            isSelected = true
        }

        // Brief delay for visual feedback before transitioning
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isPressed = false
            action()
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        ModeCard(
            mode: .onDevice,
            isSelected: .constant(false),
            action: {}
        )
        ModeCard(
            mode: .missionControl,
            isSelected: .constant(true),
            action: {}
        )
    }
    .padding()
    .background(SwiftUI.Color.forgeBackground)
}

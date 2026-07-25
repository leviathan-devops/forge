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
        .disabled(isSelected)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(spacing: ForgeMetrics.standardPadding) {
            // Icon
            Image(systemName: mode.icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(SwiftUI.Color.forgeAccent)
                .frame(width: 56, height: 56)
                .forgeGlow()

            // Title + Subtitle
            VStack(spacing: 6) {
                Text(mode.rawValue)
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
        .padding(.vertical, 28)
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

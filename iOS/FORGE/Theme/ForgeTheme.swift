import SwiftUI
import UIKit
import SwiftTerm

/// ForgeTheme
///
/// Per FORGE Engineering Specification §7.4 and §20.
///
/// Central definition of every visual constant in the app: the deep-space
/// color palette, the JetBrains Mono typography scale, the 16-color ANSI
/// terminal palette fed to SwiftTerm, and the shared spring animation curve.
///
/// There is no light mode (§1.2.7). Every color is dark-first.

// MARK: - SwiftUI Color Palette

extension SwiftUI.Color {
    /// Near-black app background. Hex 0A0A0F.
    static let forgeBackground = Color(red: 0x0A/255, green: 0x0A/255, blue: 0x0F/255)

    /// Card / panel surface. Hex 1A1A24.
    static let forgeSurface = Color(red: 0x1A/255, green: 0x1A/255, blue: 0x24/255)

    /// Overlays and sheets (slightly darker than surface). Hex 12121A.
    static let forgeElevated = Color(red: 0x12/255, green: 0x12/255, blue: 0x1A/255)

    /// Electric cyan accent — the sole accent color. Hex 00F0FF.
    static let forgeAccent = Color(red: 0x00/255, green: 0xF0/255, blue: 0xFF/255)

    /// Body text. Hex E0E0E0.
    static let forgePrimaryText = Color(red: 0xE0/255, green: 0xE0/255, blue: 0xE0/255)

    /// Captions and labels. Hex 888888.
    static let forgeSecondaryText = Color(red: 0x88/255, green: 0x88/255, blue: 0x88/255)

    /// Pass / success states. Hex 50FA7B.
    static let forgeSuccess = Color(red: 0x50/255, green: 0xFA/255, blue: 0x7B/255)

    /// Audit / warning phases. Hex F1FA8C.
    static let forgeWarning = Color(red: 0xF1/255, green: 0xFA/255, blue: 0x8C/255)

    /// Failure / error states. Hex FF5555.
    static let forgeError = Color(red: 0xFF/255, green: 0x55/255, blue: 0x55/255)

    /// Card stroke — accent at 20 % opacity.
    static let forgeBorder = Color(red: 0x00/255, green: 0xF0/255, blue: 0xFF/255).opacity(0.2)
}

// MARK: - UIColor Palette

extension UIColor {
    /// Near-black app background as UIColor. Hex 0A0A0F.
    static let forgeBackground = UIColor(
        red: 0x0A/255, green: 0x0A/255, blue: 0x0F/255, alpha: 1.0
    )

    /// Electric cyan accent as UIColor. Hex 00F0FF.
    static let forgeAccent = UIColor(
        red: 0x00/255, green: 0xF0/255, blue: 0xFF/255, alpha: 1.0
    )

    /// Body text as UIColor. Hex E0E0E0.
    static let forgePrimaryText = UIColor(
        red: 0xE0/255, green: 0xE0/255, blue: 0xE0/255, alpha: 1.0
    )

    /// Card stroke as UIColor (accent @ 20 %).
    static let forgeBorder = UIColor(
        red: 0x00/255, green: 0xF0/255, blue: 0xFF/255, alpha: 0.2
    )
}

// MARK: - Typography

extension Font {
    /// JetBrains Mono Bold at 24 pt — launch-menu title and screen titles.
    static let forgeTitle = Font.custom("JetBrainsMono-Bold", size: 24)

    /// JetBrains Mono SemiBold at 17 pt — section headlines.
    static let forgeHeadline = Font.custom("JetBrainsMono-SemiBold", size: 17)

    /// JetBrains Mono Regular at 14 pt — body text.
    static let forgeBody = Font.custom("JetBrainsMono-Regular", size: 14)

    /// JetBrains Mono Regular at 12 pt — captions and metadata.
    static let forgeCaption = Font.custom("JetBrainsMono-Regular", size: 12)

    /// JetBrains Mono Regular at 14 pt — terminal font (also set natively on
    /// the SwiftTerm view via UIFont).
    static let forgeTerminal = Font.custom("JetBrainsMono-Regular", size: 14)

    /// Convenience initializer for SwiftUI font names that gracefully falls
    /// back to SF Mono when JetBrains Mono is unavailable.
    static func forgeMono(_ size: CGFloat, weight: UIFont.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold: name = "JetBrainsMono-Bold"
        case .semibold: name = "JetBrainsMono-SemiBold"
        default: name = "JetBrainsMono-Regular"
        }
        return .custom(name, size: size)
    }
}

// MARK: - Animation

extension Animation {
    /// The standard FORGE spring animation: 0.3 s response, 0.8 damping
    /// fraction (§1.2.5). Used for every animation in the app.
    static let forgeSpring = Animation.spring(response: 0.3, dampingFraction: 0.8)

    /// A slightly softer variant for large view transitions (mode cards,
    /// Eagle Vision).
    static let forgeSpringSoft = Animation.spring(response: 0.4, dampingFraction: 0.8)
}

// MARK: - Haptics

/// Fires a medium-intensity haptic tap by default (§1.2.5). Call on every
/// button press, session switch, and mode transition.
enum ForgeHaptics {
    static func tap(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

// MARK: - ANSI Color Palette

/// The 16-color ANSI palette installed into SwiftTerm via `installColors`.
/// Matches the Dracula-inspired deep-space theme (§7.4).
struct ForgeTheme {
    /// The complete 16-entry ANSI color array. Index 0–7 are normal colors,
    /// 8–15 are bright variants. SwiftTerm consumes these directly.
    static let ansiColors: [SwiftTerm.Color] = [
        SwiftTerm.Color(red: 0x1A, green: 0x1A, blue: 0x24), // 0  Black
        SwiftTerm.Color(red: 0xFF, green: 0x55, blue: 0x55), // 1  Red
        SwiftTerm.Color(red: 0x50, green: 0xFA, blue: 0x7B), // 2  Green
        SwiftTerm.Color(red: 0xF1, green: 0xFA, blue: 0x8C), // 3  Yellow
        SwiftTerm.Color(red: 0x00, green: 0xF0, blue: 0xFF), // 4  Blue / Cyan accent
        SwiftTerm.Color(red: 0xFF, green: 0x79, blue: 0xC6), // 5  Magenta
        SwiftTerm.Color(red: 0x8B, green: 0xE9, blue: 0xFD), // 6  Cyan light
        SwiftTerm.Color(red: 0xE0, green: 0xE0, blue: 0xE0), // 7  White
        SwiftTerm.Color(red: 0x28, green: 0x28, blue: 0x32), // 8  Bright black
        SwiftTerm.Color(red: 0xFF, green: 0x6E, blue: 0x6E), // 9  Bright red
        SwiftTerm.Color(red: 0x69, green: 0xFF, blue: 0x94), // 10 Bright green
        SwiftTerm.Color(red: 0xFF, green: 0xFA, blue: 0x6C), // 11 Bright yellow
        SwiftTerm.Color(red: 0x00, green: 0xFF, blue: 0xFF), // 12 Bright blue
        SwiftTerm.Color(red: 0xFF, green: 0x92, blue: 0xD0), // 13 Bright magenta
        SwiftTerm.Color(red: 0xA4, green: 0xFF, blue: 0xFF), // 14 Bright cyan
        SwiftTerm.Color(red: 0xFF, green: 0xFF, blue: 0xFF), // 15 Bright white
    ]

    /// The default cursor color (electric cyan).
    static let cursorColor = SwiftTerm.Color(red: 0x00, green: 0xF0, blue: 0xFF)

    /// The default selection background (cyan at low alpha).
    static let selectionColor = UIColor(red: 0x00/255, green: 0xF0/255, blue: 0xFF/255, alpha: 0.2)

    /// The terminal background (matches app background exactly).
    static let backgroundColor = UIColor.forgeBackground

    /// The terminal foreground text color.
    static let foregroundColor = UIColor.forgePrimaryText

    /// JetBrains Mono regular at 14 pt — the canonical terminal font.
    static func terminalFont() -> UIFont {
        return UIFont(name: "JetBrainsMono-Regular", size: 14)
            ?? UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    }
}

// MARK: - Extended Color Palette

extension SwiftUI.Color {
    /// Purple accent. Hex BD93F9.
    static let forgePurple = Color(red: 0xBD/255, green: 0x93/255, blue: 0xF9/255)

    /// Pink accent. Hex FF79C6.
    static let forgePink = Color(red: 0xFF/255, green: 0x79/255, blue: 0xC6/255)

    /// Orange accent. Hex FFB86C.
    static let forgeOrange = Color(red: 0xFF/255, green: 0xB8/255, blue: 0x6C/255)

    /// Green alias. Hex 50FA7B.
    static let forgeGreen = forgeSuccess
}

// MARK: - Extended Typography

extension Font {
    /// JetBrains Mono Regular at 14 pt — monospace labels, buttons.
    static let forgeBodyMono = Font.custom("JetBrainsMono-Regular", size: 14)

    /// System default at 11 pt — micro labels.
    static let forgeMicro = Font.system(size: 11, design: .default)
}

// MARK: - ForgeHaptic (convenience wrapper around ForgeHaptics)

/// Provides impact(), notify(), and selection() methods for haptic feedback.
/// Bridges to the underlying ForgeHaptics implementation.
enum ForgeHaptic {
    /// Impact haptic — physical tap feedback for button presses.
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        ForgeHaptics.tap(style: style)
    }

    /// Notification haptic — success / warning / error feedback.
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        switch type {
        case .success: ForgeHaptics.success()
        case .error:   ForgeHaptics.error()
        case .warning:
            // Map warning to a medium impact since UINotificationFeedbackGenerator
            // doesn't have a dedicated warning type.
            ForgeHaptics.tap(style: .medium)
        @unknown default:
            ForgeHaptics.tap(style: .medium)
        }
    }

    /// Selection haptic — subtle tick for picker / toggle changes.
    static func selection() {
        ForgeHaptics.selection()
    }
}

/// Global haptic feedback helper. Triggers a light impact by default.
func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    ForgeHaptic.impact(style)
}

// MARK: - Animation Constants

/// Named animation constants used throughout the FORGE UI.
enum ForgeAnimation {
    /// Card tap spring — bouncy, satisfying. 0.4s response, 0.7 damping.
    static let cardTap = Animation.spring(response: 0.4, dampingFraction: 0.7)

    /// Quick fade for small UI state changes.
    static let quick = Animation.easeInOut(duration: 0.2)

    /// Standard transition animation.
    static let standard = Animation.easeInOut(duration: 0.3)

    /// Page transition — smooth crossfade.
    static let pageTransition = Animation.easeInOut(duration: 0.35)
}

// MARK: - Layout Metrics

/// Centralized layout constants for consistent spacing and sizing.
enum ForgeMetrics {
    static let topBarHeight: CGFloat = 44
    static let cardCornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 12
    static let standardPadding: CGFloat = 16
    static let largePadding: CGFloat = 24
    static let gridSize: CGFloat = 40
    static let maxParallaxOffset: CGFloat = 10
    static let gridOpacity: Double = 0.03
    static let titleFontSize: CGFloat = 36
    static let titleUnderlineWidth: CGFloat = 120
    static let titleUnderlineHeight: CGFloat = 3
}

// MARK: - View Modifiers

/// Applies the FORGE card background (surface color, 16pt corner radius, accent border).
struct ForgeCardBackground: ViewModifier {
    var isElevated: Bool = false
    var showBorder: Bool = true

    func body(content: Content) -> some View {
        content
            .background(isElevated ? SwiftUI.Color.forgeElevated : SwiftUI.Color.forgeSurface)
            .clipShape(RoundedRectangle(cornerRadius: ForgeMetrics.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ForgeMetrics.cardCornerRadius, style: .continuous)
                    .stroke(showBorder ? SwiftUI.Color.forgeBorder : SwiftUI.Color.clear, lineWidth: 1)
            )
    }
}

extension View {
    /// Apply FORGE card styling.
    func forgeCard(isElevated: Bool = false, showBorder: Bool = true) -> some View {
        modifier(ForgeCardBackground(isElevated: isElevated, showBorder: showBorder))
    }

    /// Apply FORGE accent glow (cyan shadow).
    func forgeGlow(color: SwiftUI.Color = .forgeAccent, radius: CGFloat = 8) -> some View {
        shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 0)
    }
}

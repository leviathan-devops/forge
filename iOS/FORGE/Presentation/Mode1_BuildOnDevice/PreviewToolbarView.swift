import SwiftUI

/// PreviewToolbarView
///
/// FORGE-PREVIEW-SPEC-V1.0 §3.5 — reload / home / path / console / Safari.
/// Appears only when previewMode is `.preview` or `.split` (WAVE 2 layout).
/// Height: 36pt. Tokens: existing ForgeTheme (previewToolbarBg lands in WAVE 2).
struct PreviewToolbarView: View {
    let currentPath: String?
    let onReload: () -> Void
    let onHome: () -> Void
    let onOpenInSafari: () -> Void
    let onToggleConsole: () -> Void
    var consoleBadge: Int

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onReload) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15, weight: .medium))
            }
            .accessibilityIdentifier("previewReload")

            Button(action: onHome) {
                Image(systemName: "house")
                    .font(.system(size: 15, weight: .medium))
            }
            .accessibilityIdentifier("previewHome")

            Text(currentPath ?? "no content")
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)

            Button(action: onToggleConsole) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "terminal")
                        .font(.system(size: 15, weight: .medium))
                    if consoleBadge > 0 {
                        Text("\(min(consoleBadge, 99))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.forgeBackground)
                            .padding(2)
                            .background(Color.forgeAccent, in: Circle())
                            .offset(x: 8, y: -8)
                    }
                }
            }
            .accessibilityIdentifier("previewConsoleToggle")

            Button(action: onOpenInSafari) {
                Image(systemName: "safari")
                    .font(.system(size: 15, weight: .medium))
            }
            .accessibilityIdentifier("previewOpenSafari")
        }
        .foregroundColor(.forgeAccent)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color.forgeSurface)
    }
}

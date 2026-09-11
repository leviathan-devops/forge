import SwiftUI

/// PreviewMode
///
/// Segmented surface for Mode 1: terminal-only, split, or preview-only.
/// Raw values are the chrome labels (TERMINAL / SPLIT / PREVIEW).
enum PreviewMode: String, CaseIterable {
    case terminal = "TERMINAL"
    case split    = "SPLIT"
    case preview  = "PREVIEW"
}

/// PreviewModeToggle
///
/// Per FORGE-PREVIEW-SPEC-V1.0 §3.2.
///
/// Segmented control sitting between `SessionHeaderRow` and the
/// terminal/preview ZStack. PREVIEW is disabled (dimmed, untappable) until
/// the first `renderPreview` call succeeds. SPLIT is always available.
/// WAVE 2 wires this into `BuildOnDeviceScreen`; this file is chrome only.
struct PreviewModeToggle: View {
    @Binding var mode: PreviewMode
    /// False until the first `renderPreview` call succeeds.
    var hasPreviewContent: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PreviewMode.allCases, id: \.self) { m in
                Button {
                    withAnimation(.forgeSpring) {
                        mode = m
                    }
                    hapticFeedback(.light)
                } label: {
                    Text(m.rawValue)
                        .font(.forgeCaption)
                        .foregroundColor(mode == m ? SwiftUI.Color.forgeBackground : SwiftUI.Color.forgeSecondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            mode == m ? SwiftUI.Color.forgeAccent : SwiftUI.Color.clear
                        )
                }
                .buttonStyle(.plain)
                .disabled(m == .preview && !hasPreviewContent)
                .opacity(m == .preview && !hasPreviewContent ? 0.35 : 1.0)
                .accessibilityIdentifier("previewMode.\(m.rawValue)")
                .accessibilityLabel(m.rawValue)
            }
        }
        .background(SwiftUI.Color.forgeSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(SwiftUI.Color.forgeAccent.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .accessibilityIdentifier("previewModeToggle")
        .accessibilityElement(children: .contain)
    }
}

import SwiftUI

/// SkillsDialogView — the vanilla "Skills" palette destination. Lists the
/// skills FORGE ships (mirrors opencode's skills surface).
struct SkillsDialogView: View {
    let onClose: () -> Void

    private static let skills: [(String, String)] = [
        ("trident-dispatch-templates", "Dispatch prompt templates (E1-E4 / B1-B5)"),
        ("container-testing", "Runtime-grade container test protocol"),
        ("systematic-debugging", "Reproduce → isolate → root cause → fix"),
        ("test-driven-development", "Write the failing test first"),
        ("verification-before-completion", "Evidence before assertions"),
        ("zero-trust-audit", "Treat every 'done' as a claim to re-run"),
        ("compaction-prep", "Survive context compaction"),
        ("god-loop-build-prompt", "Autonomous build execution charter"),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                HStack {
                    Text("Skills")
                        .font(.forgeBody)
                        .foregroundColor(.forgePrimaryText)
                    Spacer()
                    Text("esc")
                        .font(.forgeBody)
                        .foregroundColor(.forgeSecondaryText)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)

                Divider().overlay(Color.forgeBorder.opacity(0.6))

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Text("Skills")
                            .font(.forgeCaption)
                            .foregroundColor(.forgeAccentBright)
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                            .padding(.bottom, 2)
                        ForEach(Self.skills, id: \.0) { skill in
                            HStack(spacing: 8) {
                                Text(skill.0)
                                    .font(.forgeBody)
                                    .foregroundColor(.forgePrimaryText)
                                Text(skill.1)
                                    .font(.forgeCaption)
                                    .foregroundColor(.forgeSecondaryText)
                                    .lineLimit(1)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                        }
                    }
                }

                HStack {
                    Text("esc to close")
                    Spacer()
                    Text("tap to select")
                }
                .font(.forgeCaption)
                .foregroundColor(.forgeSecondaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.forgeSurface)
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width * 0.82, 380),
                   maxHeight: UIScreen.main.bounds.height * 0.6)
            .background(Color.forgeElevated)
            .overlay(
                Rectangle()
                    .stroke(Color.forgeBorder.opacity(0.9), lineWidth: 1)
            )
            .accessibilityAddTraits(.isModal)
        }
    }
}

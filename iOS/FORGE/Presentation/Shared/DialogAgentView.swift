import SwiftUI

// MARK: - DialogAgentView

/// Agent picker (spec §11.5). Single row — `trident` — until a Phase-2 vendor
/// agent ships. Same chrome as the other dialogs (dim backdrop, elevated card,
/// tap-outside close) so the picker family reads as one consistent surface.
///
/// Selecting the row calls `onSelect(agentID)` then `onClose()`. The host
/// (command dispatch) is responsible for persisting the choice via
/// `SessionStore.setAgentModel(...)`; this view is pure presentation.
struct DialogAgentView: View {
    let currentAgent: String
    let onSelect: (String) -> Void
    let onClose: () -> Void

    private let agentID = "trident"
    private let agentName = "trident"
    private let agentDescription = "T3 Algorithmic Audit Engine"

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                HStack {
                    Text("Switch agent")
                        .font(.forgeHeadline)
                        .foregroundColor(.forgePrimaryText)
                    Spacer()
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.forgeSecondaryText)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("dialogClose")
                }
                .padding(10)

                Divider().overlay(Color.forgeAccentDim.opacity(0.3))

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Text("AGENTS")
                            .font(.forgeCaption)
                            .foregroundColor(.forgeAccentBright)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        Button {
                            onSelect(agentID)
                            onClose()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "shield.lefthalf.filled")
                                    .foregroundColor(.forgeAccent)
                                    .font(.system(size: 18))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(agentName)
                                        .foregroundColor(.forgePrimaryText)
                                        .font(.forgeBody)
                                    Text(agentDescription)
                                        .font(.forgeCaption)
                                        .foregroundColor(.forgeSecondaryText)
                                }
                                Spacer()
                                if currentAgent == agentID {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.forgeAccentBright)
                                        .font(.forgeBody)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("dialogRow_\(agentID)")
                    }
                }

                Text("tap outside to close")
                    .font(.forgeCaption)
                    .foregroundColor(.forgeSecondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color.forgeSurface)
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width * 0.8, 360),
                   maxHeight: UIScreen.main.bounds.height * 0.8)
            .background(Color.forgeElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.forgeAccentDim.opacity(0.4), lineWidth: 1)
            )
            .accessibilityAddTraits(.isModal)
        }
    }
}

import SwiftUI

// MARK: - DialogPromptView

/// Text-input dialog (spec §11.3). Used for the session-rename flow:
/// pre-filled with the current title, a single `TextField`, and a SAVE button
/// that is disabled when the trimmed value is empty.
///
/// Flow: SAVE → `onSubmit(trimmed)` → `onClose()`. The host persists the new
/// title via `SessionStore.setTitle(...)`; this view only collects the string.
struct DialogPromptView: View {
    let title: String
    let initial: String
    let onSubmit: (String) -> Void
    let onClose: () -> Void

    @State private var text: String = ""
    @FocusState private var fieldFocused: Bool

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    fieldFocused = false
                    onClose()
                }

            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(.forgeHeadline)
                        .foregroundColor(.forgePrimaryText)
                    Spacer()
                    Button {
                        fieldFocused = false
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

                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.forgeCaption)
                        .foregroundColor(.forgeSecondaryText)

                    TextField("Session name", text: $text)
                        .font(.forgeBody)
                        .foregroundColor(.forgePrimaryText)
                        .padding(10)
                        .background(Color.forgeSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.forgeAccentDim.opacity(0.4), lineWidth: 1)
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($fieldFocused)
                        .submitLabel(.done)
                        .onSubmit { commitIfValid() }
                        .accessibilityIdentifier("promptTextField")
                }
                .padding(12)

                HStack {
                    Spacer()
                    Button {
                        commitIfValid()
                    } label: {
                        Text("SAVE")
                            .font(.forgeHeadline)
                            .foregroundColor(trimmed.isEmpty ? .forgeSecondaryText : .forgePrimaryText)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(trimmed.isEmpty
                                          ? Color.forgeSurface
                                          : Color.forgeAccent)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(trimmed.isEmpty)
                    .accessibilityIdentifier("promptSave")
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

                Spacer(minLength: 0)

                Text("tap outside to close")
                    .font(.forgeCaption)
                    .foregroundColor(.forgeSecondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color.forgeSurface)
            }
            .frame(maxWidth: min(UIScreen.main.bounds.width * 0.8, 360),
                   maxHeight: UIScreen.main.bounds.height * 0.6)
            .background(Color.forgeElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.forgeAccentDim.opacity(0.4), lineWidth: 1)
            )
            .accessibilityAddTraits(.isModal)
        }
        .onAppear {
            // Prefill with the current value and select it for quick replace.
            text = initial
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                fieldFocused = true
            }
        }
    }

    // MARK: - Save

    /// Commits the trimmed text if non-empty, then closes. Idempotent guard —
    /// once closed, further taps cannot re-fire because the view is unmounted.
    private func commitIfValid() {
        let value = trimmed
        guard !value.isEmpty else { return }
        fieldFocused = false
        onSubmit(value)
        onClose()
    }
}

import SwiftUI

/// EagleVisionGridView
///
/// Per FORGE Engineering Specification §19.3.
///
/// A SwiftUI grid of all session thumbnails. Shown when the user pinches
/// outward from a single session terminal (Eagle Vision overview mode).
///
/// Uses an adaptive `LazyVGrid` with columns sized between 160–240 pt. Each
/// cell is a `SessionThumbnailCard`. Tapping a cell zooms back into that
/// session.
struct EagleVisionGridView: View {

    let sessions: [RemoteSession]
    let currentIndex: Int

    /// Called when the user taps a thumbnail to zoom back in.
    var onSelect: ((Int) -> Void)?

    /// Adaptive columns: at least 160 pt wide.
    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            if sessions.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        Button {
                            ForgeHaptics.tap()
                            onSelect?(index)
                        } label: {
                            SessionThumbnailCard(
                                session: session,
                                isActive: index == currentIndex
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .background(Color.forgeBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(.forgeSecondaryText)
            Text("No Active Sessions")
                .font(.forgeHeadline)
                .foregroundColor(.forgePrimaryText)
            Text("Connect to a server to see sessions here.")
                .font(.forgeBody)
                .foregroundColor(.forgeSecondaryText)
                .multilineTextAlignment(.center)
        }
    }
}

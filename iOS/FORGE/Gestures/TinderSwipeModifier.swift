import SwiftUI

/// TinderSwipeModifier
///
/// Per FORGE Engineering Specification §18 (Tinder-Swipe Session Switching).
///
/// A SwiftUI `ViewModifier` that adds a horizontal drag-to-switch gesture to
/// the Mission Control session pager. A drag commits to the next/previous
/// session when it crosses 40% of the screen width **or** exceeds 800 pt/s of
/// predicted velocity (the same thresholds used by the UIKit direction-lock
/// gesture in §18.1). Otherwise the content springs back to neutral.
///
/// The minimum drag distance is 15 pt — mirroring
/// `DirectionLockPanGesture.activationThreshold` — so incidental touches and
/// vertical terminal scrolling never start a horizontal swipe.
struct TinderSwipeModifier: ViewModifier {

    /// Total number of swipable pages.
    let count: Int

    /// The currently visible page index (two-way bound).
    @Binding var index: Int

    /// Live drag translation applied as a horizontal offset.
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        offset = value.translation.width
                    }
                    .onEnded { value in
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        let screenWidth = UIScreen.main.bounds.width
                        let shouldCommit = abs(value.translation.width) > 0.4 * screenWidth
                            || abs(velocity) > 800

                        if shouldCommit {
                            withAnimation(.easeOut(duration: 0.25)) {
                                if value.translation.width < 0, index < count - 1 {
                                    index += 1
                                } else if value.translation.width > 0, index > 0 {
                                    index -= 1
                                }
                            }
                        }
                        withAnimation {
                            offset = 0
                        }
                    }
            )
    }
}

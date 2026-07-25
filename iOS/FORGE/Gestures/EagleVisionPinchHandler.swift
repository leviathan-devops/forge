import UIKit
import SwiftUI

/// EagleVisionPinchHandler
///
/// Per FORGE Engineering Specification §19.2.
///
/// A UIKit-oriented handler for the `UIPinchGestureRecognizer` that drives
/// Eagle Vision transitions. In the SwiftUI layer, a native
/// `MagnificationGesture` is used directly inside `MissionControlScreen`
/// (see `EagleVisionPinchOverlay`). This class provides the equivalent logic
/// for any UIKit-hosted contexts (e.g. the `SessionPagerView`'s underlying
/// `UIPageViewController`) and centralizes the animation coordination.
///
/// Thresholds (per §19.2):
/// - Pinch scale < 0.5  → enter Eagle Vision (zoom out to grid).
/// - Pinch scale > 0.8  → exit Eagle Vision (zoom back into a session from
///   the grid, or cancel an in-progress zoom-out).
final class EagleVisionPinchHandler: NSObject, UIGestureRecognizerDelegate {

    // MARK: - Configuration

    /// Pinch scale below which Eagle Vision is entered.
    var enterThreshold: CGFloat = 0.5

    /// Pinch scale above which Eagle Vision is exited.
    var exitThreshold: CGFloat = 0.8

    // MARK: - State

    /// Whether Eagle Vision is currently active.
    private(set) var isInEagleVision = false

    /// Called when the pinch triggers an enter transition.
    var onEnterEagleVision: (() -> Void)?

    /// Called when the pinch triggers an exit transition.
    var onExitEagleVision: (() -> Void)?

    // MARK: - Setup

    /// Installs a pinch gesture recognizer on the given view, wired to this
    /// handler.
    func install(on view: UIView) {
        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(handlePinch(_:))
        )
        pinch.delegate = self
        view.addGestureRecognizer(pinch)
    }

    // MARK: - Pinch handling

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .changed:
            if gesture.scale < enterThreshold && !isInEagleVision {
                enterEagleVision()
                // Cancel the gesture so it does not fire repeatedly.
                gesture.state = .cancelled
            }
        case .ended, .cancelled:
            // If the user pinched back out past the exit threshold while in
            // the grid, exit Eagle Vision.
            if isInEagleVision && gesture.scale > exitThreshold {
                exitEagleVision()
            }
        default:
            break
        }
    }

    // MARK: - Transitions

    /// Enters Eagle Vision with a spring animation. Animates the terminal
    /// view scaling down / fading while the grid fades in.
    func enterEagleVision() {
        guard !isInEagleVision else { return }
        isInEagleVision = true
        ForgeHaptics.tap()
        onEnterEagleVision?()
    }

    /// Exits Eagle Vision, optionally selecting a specific session index to
    /// zoom back into.
    func exitEagleVision(sessionIndex: Int? = nil) {
        guard isInEagleVision else { return }
        isInEagleVision = false
        ForgeHaptics.tap()
        onExitEagleVision?()
    }

    // MARK: - Gesture delegate

    /// Allow simultaneous recognition with the direction-lock pan only after
    /// two fingers are involved (the direction lock cancels on the second
    /// touch, so there is no real conflict).
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        // Pinch (two fingers) and pan (one finger) are naturally
        // distinguishable. Allow simultaneous recognition so neither blocks
        // the other during the transition frame.
        return other is DirectionLockPanGesture
    }
}

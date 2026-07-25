import UIKit
import UIKit.UIGestureRecognizerSubclass

/// DirectionLockPanGesture
///
/// Per FORGE Engineering Specification §18.1 and §19.4.
///
/// A custom `UIGestureRecognizer` that distinguishes horizontal swipes
/// (session switching in Mission Control) from vertical drags (terminal
/// scrollback). After a 15-point displacement threshold it locks to the
/// dominant axis for the remainder of the gesture, then reports only the
/// locked-axis delta.
///
/// It also cancels itself when a second finger touches, so it coexists
/// cleanly with the two-finger Eagle Vision pinch gesture (§19.4).
class DirectionLockPanGesture: UIGestureRecognizer {

    // MARK: - Configuration

    /// The minimum displacement (in points) before the gesture activates and
    /// locks to an axis.
    var activationThreshold: CGFloat = 15.0

    /// The axis the gesture has locked onto, or `.none` before activation.
    private(set) var lockedAxis: LockedAxis = .none

    enum LockedAxis {
        case none
        case horizontal
        case vertical
    }

    // MARK: - Tracking state

    /// The touch location where the gesture began.
    private var startPoint: CGPoint = .zero

    /// The last reported touch location (used for incremental deltas).
    private var lastReportedPoint: CGPoint = .zero

    /// Whether the dominant axis has been determined yet.
    private var directionDetermined = false

    /// The accumulated translation along the locked axis since the gesture
    /// began. Read by the action target after `.changed`/`.ended`.
    private(set) var translation: CGFloat = 0

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)

        // Cancel immediately if more than one finger is involved — this lets
        // the pinch gesture take over (§19.4).
        if event.allTouches?.count ?? 0 > 1 {
            state = .cancelled
            return
        }

        guard let touch = touches.first else {
            state = .failed
            return
        }
        startPoint = touch.location(in: view)
        lastReportedPoint = startPoint
        directionDetermined = false
        lockedAxis = .none
        translation = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        // Coexistence with pinch: cancel if a second finger appears (§19.4).
        if event.allTouches?.count ?? 0 > 1 {
            if state == .began || state == .changed {
                state = .cancelled
            }
            return
        }

        guard let touch = touches.first else { return }
        let point = touch.location(in: view)

        // Compute total displacement from the start.
        let totalDx = point.x - startPoint.x
        let totalDy = point.y - startPoint.y

        if !directionDetermined {
            // Wait until the displacement exceeds the activation threshold.
            if abs(totalDx) > activationThreshold || abs(totalDy) > activationThreshold {
                directionDetermined = true
                // Lock to whichever axis has the greater displacement.
                lockedAxis = abs(totalDx) > abs(totalDy) ? .horizontal : .vertical
                state = .began
                lastReportedPoint = point
            }
            return
        }

        // Direction is locked — report only the locked-axis delta.
        let delta: CGFloat
        switch lockedAxis {
        case .horizontal:
            delta = point.x - lastReportedPoint.x
        case .vertical:
            delta = point.y - lastReportedPoint.y
        case .none:
            delta = 0
        }
        translation += delta
        lastReportedPoint = point
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        // If the gesture never crossed the threshold, it fails (no-op).
        // Otherwise it ends normally.
        state = directionDetermined ? .ended : .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = .cancelled
    }

    // MARK: - Reset

    /// Called by UIKit after the gesture transitions to a terminal state
    /// (`.ended`, `.cancelled`, `.failed`). Resets all tracking state so the
    /// recognizer is ready for the next touch sequence.
    override func reset() {
        startPoint = .zero
        lastReportedPoint = .zero
        directionDetermined = false
        lockedAxis = .none
        translation = 0
        super.reset()
    }

    // MARK: - Public accessors

    /// The current velocity (points per move event) along the locked axis.
    /// Returns 0 if the axis has not been determined.
    var velocity: CGFloat {
        guard directionDetermined else { return 0 }
        // Velocity is approximated from the last delta; callers that need
        // real velocity can track it externally.
        return translation
    }

    /// Convenience: `true` when the gesture has locked to the horizontal axis.
    var isHorizontal: Bool { lockedAxis == .horizontal }

    /// Convenience: `true` when the gesture has locked to the vertical axis.
    var isVertical: Bool { lockedAxis == .vertical }
}

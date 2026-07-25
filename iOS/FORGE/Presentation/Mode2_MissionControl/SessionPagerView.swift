import SwiftUI
import UIKit
import SwiftTerm

/// SessionPagerView
///
/// Per FORGE Engineering Specification §16.3 and §18.
///
/// A `UIViewControllerRepresentable` wrapping a `UIPageViewController` that
/// displays one remote session's SwiftTerm terminal at a time. The user swipes
/// horizontally between sessions using the direction-lock gesture recognizer.
///
/// Each page hosts its own `TerminalView` and a `RemoteSessionViewModel`. The
/// pager exposes a binding to the current page index and a callback when the
/// index changes.
struct SessionPagerView: UIViewControllerRepresentable {

    /// The sessions to display, one per page.
    var sessions: [RemoteSession]

    /// The currently visible page index.
    @Binding var currentIndex: Int

    /// Called when the user swipes to a different page.
    var onIndexChanged: ((Int) -> Void)?

    // MARK: - makeUIViewController

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        pageVC.dataSource = context.coordinator
        pageVC.delegate = context.coordinator

        // Disable the built-in bounce to avoid conflicts with the
        // direction-lock gesture.
        for subview in pageVC.view.subviews {
            if let scrollView = subview as? UIScrollView {
                scrollView.bounces = true
                scrollView.alwaysBounceHorizontal = false
            }
        }

        // Install the direction-lock gesture recognizer so horizontal swipes
        // switch pages while vertical drags scroll the terminal (§18.1).
        let directionLock = DirectionLockPanGesture(
            target: context.coordinator,
            action: #selector(Coordinator.handleDirectionLock(_:))
        )
        directionLock.delegate = context.coordinator
        pageVC.view.addGestureRecognizer(directionLock)
        context.coordinator.directionLockGesture = directionLock

        // Set the initial page.
        context.coordinator.parent = self
        if !sessions.isEmpty {
            let initial = min(currentIndex, sessions.count - 1)
            let host = context.coordinator.makeHostController(
                for: sessions[initial],
                atIndex: initial
            )
            pageVC.setViewControllers([host], direction: .forward, animated: false)
        }

        return pageVC
    }

    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        context.coordinator.parent = self

        // If the session list changed identity, refresh the visible page.
        guard !sessions.isEmpty else { return }
        let safeIndex = min(currentIndex, sessions.count - 1)

        let currentHost = pageVC.viewControllers?.first as? SessionHostController
        if currentHost?.session.id != sessions[safeIndex].id {
            let host = context.coordinator.makeHostController(
                for: sessions[safeIndex], atIndex: safeIndex
            )
            pageVC.setViewControllers([host], direction: .forward, animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject,
        UIPageViewControllerDataSource,
        UIPageViewControllerDelegate,
        UIGestureRecognizerDelegate {

        var parent: SessionPagerView
        weak var directionLockGesture: DirectionLockPanGesture?

        init(parent: SessionPagerView) {
            self.parent = parent
        }

        // MARK: - Page data source

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let host = viewController as? SessionHostController,
                  host.index > 0 else {
                return nil
            }
            let prevIndex = host.index - 1
            guard prevIndex < parent.sessions.count else { return nil }
            return makeHostController(
                for: parent.sessions[prevIndex], atIndex: prevIndex
            )
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let host = viewController as? SessionHostController else { return nil }
            let nextIndex = host.index + 1
            guard nextIndex < parent.sessions.count else { return nil }
            return makeHostController(
                for: parent.sessions[nextIndex], atIndex: nextIndex
            )
        }

        // MARK: - Page delegate

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  let host = pageViewController.viewControllers?.first as? SessionHostController else {
                return
            }
            DispatchQueue.main.async {
                self.parent.currentIndex = host.index
                self.parent.onIndexChanged?(host.index)
                ForgeHaptics.selection()
            }
        }

        // MARK: - Host controller factory

        func makeHostController(
            for session: RemoteSession,
            atIndex index: Int
        ) -> SessionHostController {
            return SessionHostController(
                session: session,
                index: index
            )
        }

        // MARK: - Direction-lock gesture

        @objc func handleDirectionLock(_ gesture: DirectionLockPanGesture) {
            // The PageViewController handles the actual scroll. The
            // direction-lock gesture is primarily here to coexist with the
            // terminal's scroll view (see gesture delegate below) and to
            // cancel multi-touch for pinch coexistence (§19.4).
            switch gesture.state {
            case .began:
                ForgeHaptics.tap(style: .light)
            default:
                break
            }
        }

        // MARK: - Gesture delegate (§18.2)

        /// The direction-lock gesture must be required-to-fail-by the terminal
        /// scroll pan, so that horizontal touches switch pages and vertical
        /// touches scroll the terminal.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy other: UIGestureRecognizer
        ) -> Bool {
            if other is UIPanGestureRecognizer {
                return true
            }
            return false
        }

        /// Mutually exclusive once the direction is determined.
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            return false
        }
    }
}

// MARK: - SessionHostController

/// A `UIViewController` that hosts a single SwiftTerm `TerminalView` for one
/// remote session, along with its `RemoteSessionViewModel`.
final class SessionHostController: UIViewController, TerminalViewDelegate {

    let session: RemoteSession
    let index: Int

    private var terminalView: TerminalView!
    private(set) var viewModel: RemoteSessionViewModel!

    init(session: RemoteSession, index: Int) {
        self.session = session
        self.index = index
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        terminalView = TerminalView(frame: view.bounds)
        terminalView.terminalDelegate = self
        terminalView.font = ForgeTheme.terminalFont()
        terminalView.nativeBackgroundColor = ForgeTheme.backgroundColor
        terminalView.nativeForegroundColor = ForgeTheme.foregroundColor
        terminalView.selectedTextBackgroundColor = ForgeTheme.selectionColor
        terminalView.installColors(ForgeTheme.ansiColors)
        do { try terminalView.setUseMetal(true) } catch {
            #if DEBUG
            print("Metal unavailable: \(error)")
            #endif
        }
        terminalView.changeScrollback(5000)
        terminalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(terminalView)

        viewModel = RemoteSessionViewModel()
        viewModel.connect(to: session, terminalView: terminalView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        terminalView.frame = view.bounds
    }

    // MARK: - TerminalViewDelegate

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        viewModel.sendInput(Data(data))
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        viewModel.sendResize(cols: newCols, rows: newRows)
    }

    func setTerminalTitle(source: TerminalView, title: String) {}

    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        if let url = URL(string: link) {
            DispatchQueue.main.async { UIApplication.shared.open(url) }
        }
    }

    func bell(source: TerminalView) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func clipboardCopy(source: TerminalView, content: Data) {
        UIPasteboard.general.string = String(data: content, encoding: .utf8)
    }

    func clipboardRead(source: TerminalView) -> Data? {
        return UIPasteboard.general.string?.data(using: .utf8)
    }

    func scrolled(source: TerminalView, position: Double) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
}

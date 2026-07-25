import SwiftUI
import UIKit
import SwiftTerm

/// ForgeTerminalView
///
/// Per FORGE Engineering Specification §7.3.
///
/// A production `UIViewRepresentable` wrapping SwiftTerm's `TerminalView`.
/// SwiftTerm's built-in SwiftUI wrapper is `#if DEBUG` only, so we provide a
/// release-quality wrapper here.
///
/// Responsibilities:
/// - Create the `TerminalView` with the FORGE theme (colors, JetBrains Mono,
///   Metal GPU rendering, 5000-line scrollback).
/// - Wire the `TerminalViewDelegate` so keyboard input flows to the JS engine
///   and resize events propagate to OpenTUI.
/// - Expose the underlying view via a binding so the parent can call `feed`.
struct ForgeTerminalView: UIViewRepresentable {

    /// Bound to the created `TerminalView` so the parent screen can feed ANSI
    /// data into it directly.
    @Binding var terminalView: TerminalView?

    /// Called when the user types into the terminal. The data is forwarded to
    /// the ForgeEngine (JS input pipeline, §8.2).
    var onSend: ((Data) -> Void)?

    /// Called when the terminal's visible dimensions change so OpenTUI can
    /// re-layout (§8.3).
    var onResize: ((Int, Int) -> Void)?

    // MARK: - makeUIView

    func makeUIView(context: Context) -> TerminalView {
        let view = TerminalView(frame: .zero)

        // Theme: colors, fonts, selection.
        view.terminalDelegate = context.coordinator
        view.font = ForgeTheme.terminalFont()
        view.nativeBackgroundColor = ForgeTheme.backgroundColor
        view.nativeForegroundColor = ForgeTheme.foregroundColor
        view.selectedTextBackgroundColor = ForgeTheme.selectionColor
        view.installColors(ForgeTheme.ansiColors)

        // Metal GPU rendering for smooth scrolling; fall back gracefully.
        do {
            try view.setUseMetal(true)
        } catch {
            #if DEBUG
            print("Metal unavailable, using CoreText fallback: \(error)")
            #endif
        }

        // Generous scrollback but capped to control memory (§31.1).
        view.changeScrollback(5000)

        // Scroll behaviour — preserve vertical rubber-banding (§18.3).
        view.bounces = true
        view.alwaysBounceHorizontal = false
        view.showsVerticalScrollIndicator = true

        // Keyboard accessory view with a Done button to dismiss the keyboard (§Task 3).
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.barStyle = .black
        toolbar.isTranslucent = true
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(
                title: "Done",
                style: .done,
                target: context.coordinator,
                action: #selector(Coordinator.dismissKeyboard)
            )
        ]
        toolbar.sizeToFit()
        view.inputAccessoryView = toolbar

        // Store a weak reference in the coordinator so the Done button can
        // resign first responder (§Task 3).
        context.coordinator.terminalView = view

        // Publish the created view to the binding on the next run loop so
        // SwiftUI's update cycle is not interrupted.
        DispatchQueue.main.async {
            self.terminalView = view
        }

        return view
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        // No incremental updates needed — SwiftTerm manages its own state.
        // Re-assert the delegate in case the coordinator was recreated.
        uiView.terminalDelegate = context.coordinator
    }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(onSend: onSend, onResize: onResize)
    }

    /// Implements `TerminalViewDelegate`, forwarding input and resize events
    /// to the closures provided by the parent screen.
    final class Coordinator: NSObject, TerminalViewDelegate {

        let onSend: ((Data) -> Void)?
        let onResize: ((Int, Int) -> Void)?

        /// Weak reference to the TerminalView so the keyboard Done button
        /// action can dismiss the keyboard (§Task 3).
        weak var terminalView: TerminalView?

        init(onSend: ((Data) -> Void)?, onResize: ((Int, Int) -> Void)?) {
            self.onSend = onSend
            self.onResize = onResize
            super.init()
        }

        // MARK: Keyboard Dismissal

        /// Called when the user taps "Done" in the keyboard accessory bar.
        /// Resigns first responder to hide the keyboard (§Task 3).
        @objc func dismissKeyboard() {
            terminalView?.resignFirstResponder()
        }

        // MARK: Input

        /// Keyboard input from SwiftTerm. Forwards the raw bytes to the JS
        /// engine via the onSend closure (§8.2).
        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            onSend?(Data(data))
        }

        // MARK: Resize

        /// Reports the new column/row count so OpenTUI can re-layout (§8.3).
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            onResize?(newCols, newRows)
        }

        // MARK: Title

        func setTerminalTitle(source: TerminalView, title: String) {
            // Title updates could be forwarded to the top bar; no-op for now.
        }

        // MARK: Links

        func requestOpenLink(
            source: TerminalView,
            link: String,
            params: [String: String]
        ) {
            if let url = URL(string: link) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url)
                }
            }
        }

        // MARK: Bell

        func bell(source: TerminalView) {
            // Light haptic on terminal bell (§1.2.5).
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        // MARK: Clipboard

        func clipboardCopy(source: TerminalView, content: Data) {
            UIPasteboard.general.string = String(data: content, encoding: .utf8)
        }

        func clipboardRead(source: TerminalView) -> Data? {
            return UIPasteboard.general.string?.data(using: .utf8)
        }

        // MARK: Scroll

        func scrolled(source: TerminalView, position: Double) {
            // Could drive a scroll-position indicator; no-op for now.
        }

        // MARK: Host directory

        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            // No-op — directory changes are handled by the agent.
        }

        // MARK: iTerm / range (protocol completeness)

        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}

        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}

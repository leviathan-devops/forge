import SwiftUI
import UIKit
import SwiftTerm
#if canImport(Metal)
import Metal
#endif

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
///   Metal GPU rendering on **device only**, 5000-line scrollback).
/// - Wire the `TerminalViewDelegate` so keyboard input flows to the JS engine
///   and resize events propagate to OpenTUI.
/// - Expose the underlying view via a binding so the parent can call `feed`.
///
/// Simulator safety (Gate D / Mode1):
/// - Never enable SwiftTerm Metal on the iOS Simulator — CI SIGABRT residual
///   ("com.forge.app crashed in <external symbol>") after BUILD ON-DEVICE.
/// - Device builds only enable Metal when `MTLCreateSystemDefaultDevice()`
///   returns a live device (and still catch `MetalError`).
/// - SwiftTerm pin remains 1.15.x (C5) — Metal is **off by default** in 1.15;
///   we never call `setUseMetal(true)` on simulator.
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
        // Prefer a non-zero initial frame so SwiftTerm's first layout pass has
        // sane col/row math. Representable will resize to the SwiftUI slot.
        let initialFrame = CGRect(x: 0, y: 0, width: 320, height: 480)
        let view = TerminalView(frame: initialFrame)

        // Theme: colors, fonts, selection.
        view.terminalDelegate = context.coordinator
        view.font = ForgeTheme.terminalFont()
        view.nativeBackgroundColor = ForgeTheme.backgroundColor
        view.nativeForegroundColor = ForgeTheme.foregroundColor
        view.selectedTextBackgroundColor = ForgeTheme.selectionColor
        view.installColors(ForgeTheme.ansiColors)

        // ── Metal / renderer guard ──────────────────────────────────────────
        // CRITICAL: never enable Metal on the iOS Simulator. SwiftTerm's Metal
        // path SIGABRTs under XCUITest (CI Gate D Mode1: "crashed in
        // <external symbol>" right after tapping BUILD ON-DEVICE).
        // Device builds still get Metal when a system default device exists.
        configureRenderer(for: view)

        // Generous scrollback but capped to control memory (§31.1).
        view.changeScrollback(5000)

        // Scroll behaviour — preserve vertical rubber-banding (§18.3).
        view.bounces = true
        view.alwaysBounceHorizontal = false
        view.showsVerticalScrollIndicator = true

        // UITest / Gate D: stable identifier for the terminal surface.
        // TerminalView is a UIScrollView subclass — scrollViews.firstMatch
        // still works; accessibility id helps non-crash probes.
        view.accessibilityIdentifier = "forgeTerminal"
        view.isAccessibilityElement = true
        view.accessibilityLabel = "FORGE Terminal"

        // Store coordinator weak ref before deferred accessory install.
        context.coordinator.terminalView = view

        // Defer Done accessory + binding publish past first layout pass so we
        // do not overwrite SwiftTerm's TerminalAccessory during zero-frame
        // setup (RCA R1d / Fix C) under fullScreenCover + XCUITest.
        DispatchQueue.main.async {
            self.installKeyboardAccessory(on: view, coordinator: context.coordinator)
            self.terminalView = view
        }

        return view
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        // No incremental updates needed — SwiftTerm manages its own state.
        // Re-assert the delegate in case the coordinator was recreated.
        uiView.terminalDelegate = context.coordinator
        context.coordinator.terminalView = uiView
        context.coordinator.onSend = onSend
        context.coordinator.onResize = onResize
    }

    // MARK: - Renderer configuration

    /// Enables Metal only on physical devices with a live MTL device.
    /// Simulator: leave CoreGraphics path (SwiftTerm default Metal = off).
    private func configureRenderer(for view: TerminalView) {
        #if targetEnvironment(simulator)
        // Explicit Metal OFF on simulator (SwiftTerm default is already off;
        // call setUseMetal(false) for honesty — never setUseMetal(true) here).
        do {
            try view.setUseMetal(false)
        } catch {
            // Already CoreGraphics path — ignore.
        }
        #if DEBUG
        print("[FORGE] Simulator: SwiftTerm Metal renderer OFF (CoreGraphics path)")
        #endif
        #else
        #if canImport(Metal)
        // Runtime guard: only enable when a default Metal device exists.
        guard MTLCreateSystemDefaultDevice() != nil else {
            #if DEBUG
            print("[FORGE] Metal device unavailable — CoreGraphics terminal path")
            #endif
            return
        }
        #endif
        do {
            try view.setUseMetal(true)
        } catch {
            #if DEBUG
            print("Metal unavailable, using CoreText fallback: \(error)")
            #endif
        }
        #endif
    }

    // MARK: - Keyboard accessory (deferred)

    /// Installs the terminal keyboard accessory bar (ESC, CTRL, TAB, arrows,
    /// Done) after the first run-loop tick so SwiftTerm's own accessory setup
    /// in TerminalView.init is not clobbered mid-setup (RCA R1d / Fix C).
    private func installKeyboardAccessory(on view: TerminalView, coordinator: Coordinator) {
        let ctrlItem = Self.textKey("CTRL", coordinator, #selector(Coordinator.toggleCtrl))

        let toolbar = UIToolbar()
        toolbar.barStyle = .black
        toolbar.isTranslucent = true
        toolbar.tintColor = UIColor.forgeAccent
        toolbar.items = [
            Self.textKey("ESC", coordinator, #selector(Coordinator.keyEsc)),
            ctrlItem,
            Self.textKey("TAB", coordinator, #selector(Coordinator.keyTab)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            Self.arrowKey("arrow.left", coordinator, #selector(Coordinator.keyLeft)),
            Self.arrowKey("arrow.up", coordinator, #selector(Coordinator.keyUp)),
            Self.arrowKey("arrow.down", coordinator, #selector(Coordinator.keyDown)),
            Self.arrowKey("arrow.right", coordinator, #selector(Coordinator.keyRight)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(
                title: "Done",
                style: .done,
                target: coordinator,
                action: #selector(Coordinator.dismissKeyboard)
            )
        ]
        toolbar.sizeToFit()
        view.inputAccessoryView = toolbar
        coordinator.terminalView = view
        coordinator.ctrlButton = ctrlItem
    }

    private static func textKey(_ title: String, _ target: Coordinator, _ action: Selector) -> UIBarButtonItem {
        UIBarButtonItem(title: title, style: .plain, target: target, action: action)
    }

    private static func arrowKey(_ systemName: String, _ target: Coordinator, _ action: Selector) -> UIBarButtonItem {
        UIBarButtonItem(image: UIImage(systemName: systemName), style: .plain, target: target, action: action)
    }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(onSend: onSend, onResize: onResize)
    }

    /// Implements `TerminalViewDelegate`, forwarding input and resize events
    /// to the closures provided by the parent screen.
    final class Coordinator: NSObject, TerminalViewDelegate {

        var onSend: ((Data) -> Void)?
        var onResize: ((Int, Int) -> Void)?

        /// Weak reference to the TerminalView so the keyboard Done button
        /// action can dismiss the keyboard (§Task 3).
        weak var terminalView: TerminalView?

        /// Holds the CTRL toggle button so its visual style can be reset when
        /// the modifier is consumed by the next key press.
        weak var ctrlButton: UIBarButtonItem?

        /// Tracks the CTRL modifier toggle state for the keyboard accessory.
        private var ctrlActive = false

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

        // MARK: Keyboard Accessory Keys

        /// ESC — sends the escape byte (0x1B).
        @objc func keyEsc() {
            onSend?(Data([0x1B]))
            resetCtrl()
        }

        /// TAB — sends the tab byte (0x09).
        @objc func keyTab() {
            onSend?(Data([0x09]))
            resetCtrl()
        }

        /// CTRL — toggles the modifier. When active, the next arrow press sends
        /// the xterm CTRL+arrow sequence (word-wise motion in bash/zsh).
        @objc func toggleCtrl(_ sender: UIBarButtonItem) {
            ctrlActive.toggle()
            sender.style = ctrlActive ? .done : .plain
            ForgeHaptic.selection()
        }

        @objc func keyLeft()  { sendArrow(letterByte: 0x44) } // 'D'
        @objc func keyRight() { sendArrow(letterByte: 0x43) } // 'C'
        @objc func keyUp()    { sendArrow(letterByte: 0x41) } // 'A'
        @objc func keyDown()  { sendArrow(letterByte: 0x42) } // 'B'

        /// Sends an ANSI cursor sequence. CTRL+arrow uses the xterm
        /// `ESC [ 1 ; 5 <letter>` form for word-wise cursor motion.
        private func sendArrow(letterByte: UInt8) {
            let bytes: [UInt8]
            if ctrlActive {
                bytes = [0x1B, 0x5B, 0x31, 0x3B, 0x35, letterByte]
            } else {
                bytes = [0x1B, 0x5B, letterByte]
            }
            onSend?(Data(bytes))
            resetCtrl()
        }

        private func resetCtrl() {
            guard ctrlActive else { return }
            ctrlActive = false
            ctrlButton?.style = .plain
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
            // Light haptic on terminal bell (§1.2.5). Safe no-op on sim.
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

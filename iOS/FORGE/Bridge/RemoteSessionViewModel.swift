import Foundation
import SwiftUI
import Combine
import SwiftTerm

/// RemoteSessionViewModel
///
/// Per FORGE Engineering Specification §16.3 and §12.3.
///
/// Manages a single `URLSessionWebSocketTask` connection to a remote opencode
/// server, bridging terminal output and keyboard input between SwiftTerm and
/// the remote TUI.
///
/// Responsibilities:
/// - `connect(to:)` opens the WebSocket and starts the receive loop.
/// - `receiveLoop` feeds incoming ANSI frames into SwiftTerm via `feed`.
/// - `sendInput` forwards SwiftTerm keystrokes to the remote server.
/// - `sendResize` propagates terminal size changes.
/// - Automatic reconnection with exponential backoff (2 s → 60 s max).
/// - Publishes a `connectionLost` flag so views can show a red banner.
final class RemoteSessionViewModel: ObservableObject {

    // MARK: - Published state

    /// `true` while the WebSocket is open and receiving.
    @Published var isConnected: Bool = false

    /// Set when the connection drops; cleared on successful reconnect.
    @Published var connectionLost: Bool = false

    /// Human-readable status for display.
    @Published var statusText: String = "Disconnected"

    // MARK: - Private state

    private var webSocket: URLSessionWebSocketTask?
    private weak var terminalView: TerminalView?
    private var session: RemoteSession?
    private var reconnectAttempts: Int = 0
    private var isManualDisconnect: Bool = false
    private let sessionQueue = DispatchQueue(label: "forge.remote.ws", qos: .userInitiated)

    // MARK: - Connect

    /// Opens a WebSocket to the given session's server and begins receiving.
    /// The `terminalView` is captured weakly so incoming frames can be fed
    /// directly into SwiftTerm.
    func connect(to session: RemoteSession, terminalView: TerminalView) {
        self.session = session
        self.terminalView = terminalView
        self.isManualDisconnect = false
        openConnection()
    }

    private func openConnection() {
        guard let session = session else { return }
        let urlString = "\(session.server.wsURL)/ws/session/\(session.id)"
        guard let url = URL(string: urlString) else {
            updateStatus("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        if let token = session.server.bearerToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let task = URLSession.shared.webSocketTask(with: request)
        webSocket = task
        task.resume()

        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionLost = false
            self.statusText = "Connected to \(session.server.name)"
        }
        // Reset the backoff counter on sessionQueue so all accesses are
        // serialized on the same queue as the increment in handleDisconnect.
        sessionQueue.async { self.reconnectAttempts = 0 }

        receiveLoop()
    }

    // MARK: - Receive loop (§12.3)

    /// Continuously receives WebSocket messages and feeds text/data frames
    /// into SwiftTerm. On failure, triggers reconnection.
    private func receiveLoop() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.feedToTerminal(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.feedToTerminal(text)
                    }
                @unknown default:
                    break
                }
                // Continue listening.
                self.receiveLoop()

            case .failure:
                self.handleDisconnect()
            }
        }
    }

    /// Feeds a string into SwiftTerm on the main thread.
    private func feedToTerminal(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.terminalView?.feed(text: text)
        }
    }

    // MARK: - Send input (§12.3)

    /// Forwards keyboard input from SwiftTerm to the remote server.
    func sendInput(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        guard let socket = webSocket else { return }
        socket.send(.string(text)) { [weak self] error in
            if error != nil {
                self?.handleDisconnect()
            }
        }
    }

    // MARK: - Send resize (§12.3)

    /// Sends a resize control message so the remote TUI reflows.
    func sendResize(cols: Int, rows: Int) {
        guard let socket = webSocket else { return }
        let payload = "{\"type\":\"resize\",\"cols\":\(cols),\"rows\":\(rows)}"
        socket.send(.string(payload)) { _ in }
    }

    // MARK: - Reconnection with backoff (§12.3)

    private func handleDisconnect() {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionLost = true
            self.statusText = "Connection lost — reconnecting…"
        }

        // Show a red banner in the terminal (§12.3).
        feedToTerminal(
            "\r\n\u{001b}[31mConnection lost — reconnecting…\u{001b}[0m\r\n"
        )

        // Serialize reconnection state on sessionQueue to avoid data races
        // with disconnect() which sets isManualDisconnect on the main thread.
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isManualDisconnect else { return }

            self.reconnectAttempts += 1
            let delay = min(2.0 * pow(2.0, Double(self.reconnectAttempts - 1)), 60.0)

            self.sessionQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, !self.isManualDisconnect else { return }
                self.webSocket?.cancel()
                self.webSocket = nil
                self.openConnection()
            }
        }
    }

    // MARK: - Disconnect

    /// Cleanly closes the WebSocket and stops reconnection attempts.
    func disconnect() {
        isManualDisconnect = true
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.statusText = "Disconnected"
        }
    }

    // MARK: - Status

    private func updateStatus(_ text: String) {
        DispatchQueue.main.async {
            self.statusText = text
        }
    }
}

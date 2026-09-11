import Foundation
import SwiftUI
import Combine
import SwiftTerm

/// RemoteSessionViewModel
///
/// Connects a SwiftTerm terminal to a REAL opencode server PTY (the live
/// protocol — NOT the old `/ws/session/{id}` path which the real server
/// doesn't expose):
///
///   1. POST {baseURL}/pty  {command:"/bin/bash", title}  → {id: "pty_..."}
///   2. WS connect to ws://{host}/pty/{ptyID}/connect
///   3. Incoming text frames → SwiftTerm feed (JSON control frames like
///      {"cursor":N} are skipped)
///   4. Outgoing keystrokes → ws.send(text)
///   5. Resize → ANSI resize sequence over the socket
///
/// The PTY is deleted on disconnect (DELETE /pty/{ptyID}).
final class RemoteSessionViewModel: ObservableObject {

    // MARK: - Published state

    @Published var isConnected: Bool = false
    @Published var connectionLost: Bool = false
    @Published var statusText: String = "Disconnected"

    // MARK: - Private state

    private var webSocket: URLSessionWebSocketTask?
    private weak var terminalView: TerminalView?
    private var session: RemoteSession?
    private var ptyID: String?
    private var reconnectAttempts: Int = 0
    private var isManualDisconnect: Bool = false
    private let sessionQueue = DispatchQueue(label: "forge.remote.ws", qos: .userInitiated)

    // MARK: - Connect (real PTY flow)

    /// 1. Creates a PTY on the real server, then opens the WS attach.
    func connect(to session: RemoteSession, terminalView: TerminalView) {
        self.session = session
        self.terminalView = terminalView
        self.isManualDisconnect = false
        // Honest in-flight state: until openConnection lands, the sheet shows
        // "Connecting…" — never the misleading "Disconnected" (the initial
        // value) while a slow PTY spawn is still resolving (E-14 finding:
        // a loaded-host spawn can take tens of seconds and the sheet looked
        // dead the whole time).
        updateStatus("Connecting…")
        createPTYThenConnect()
    }

    private func createPTYThenConnect() {
        guard let session = session,
              let url = URL(string: "\(session.server.baseURL)/pty") else {
            updateStatus("Invalid server URL")
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Real opencode PTY body (verified: {command:"/bin/bash", title} → {id}).
        let body: [String: Any] = [
            "command": "/bin/bash",
            "title": session.displayName,
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, resp, error in
            guard let self = self else { return }
            guard let data = data,
                  let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ptyID = obj["id"] as? String else {
                DispatchQueue.main.async {
                    self.statusText = error != nil
                        ? "PTY failed: \(error!.localizedDescription)"
                        : "PTY create failed"
                    self.connectionLost = true
                }
                return
            }
            self.ptyID = ptyID
            self.openConnection(ptyID: ptyID)
        }.resume()
    }

    /// 2. Opens the WebSocket to the PTY connect endpoint.
    private func openConnection(ptyID: String) {
        guard let session = session else { return }
        let urlString = "\(session.server.wsURL)/pty/\(ptyID)/connect"
        guard let url = URL(string: urlString) else {
            updateStatus("Invalid PTY URL")
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

        // Initial 80×24 resize: without this the PTY defaults to a narrow
        // width and long prompts wrap (E2E finding). Real layout resizes
        // refine it afterwards.
        task.send(.string("\u{1b}[8;24;80t")) { _ in }
        lastSentCols = 80
        lastSentRows = 24

        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionLost = false
            self.statusText = "Connected to \(session.server.name)"
        }
        sessionQueue.async { self.reconnectAttempts = 0 }

        receiveLoop()
    }

    // MARK: - Receive loop

    private func receiveLoop() {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleFrame(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleFrame(text)
                    }
                @unknown default:
                    break
                }
                self.receiveLoop()

            case .failure:
                self.handleDisconnect()
            }
        }
    }

    /// Holds a partial ANSI sequence split across WS frames (the PTY echo of
    /// our resize arrives byte-fragmented; a lone ESC would render as "^[").
    private var ansiBuffer = ""

    /// F2 (fixed 2026-08-11): the resize echo residue ("\x07;rows;colst")
    /// lands in the SHELL's line buffer — the user's first command would
    /// merge with the junk ("bash: syntax error near unexpected token ';'").
    /// The residue is stripped visually on receive; this flag arms a one-time
    /// Ctrl-U (\x15) that KILLS the pending junk line inside the shell.
    private var needsLineKill = true

    /// ANSI output frames feed SwiftTerm. Rules:
    /// - JSON control objects ({...}) are protocol metadata → stripped.
    /// - CSI resize sequences (\x1B[8;rows;colst — our own echo) → dropped.
    /// - CSI/OSC sequences split across frames → buffered until complete so
    ///   SwiftTerm parses them (never renders a bare "^[").
    private func handleFrame(_ text: String) {
        var cleaned = text.replacingOccurrences(
            of: "\\{[^}]*\\}",
            with: "",
            options: .regularExpression
        )
        // Resize echo residue: the PTY consumes "\x1B[8" and echoes back
        // "\x07;rows;colst" (BEL + params + t) — strip that exact shape.
        cleaned = cleaned.replacingOccurrences(
            of: "\u{07};\\d+;\\d+t",
            with: "",
            options: .regularExpression
        )
        // The server may also send the resize echo CARET-ESCAPED as literal
        // "^[8;rows;colst" text (observed: the frame contains the literal
        // caret-bracket, not a real ESC byte — the sequencer can't parse it).
        cleaned = cleaned.replacingOccurrences(
            of: "\\^\\[8;\\d+;\\d+t",
            with: "",
            options: .regularExpression
        )
        // F2: the resize echo ALSO pollutes the shell's input buffer (the PTY
        // consumes "\x1B[8" and echoes "\x07;rows;colst" as if typed). After
        // the first residue arrives, kill the pending junk line with Ctrl-U.
        if needsLineKill,
           text.range(of: "\\^?\\[?8;\\d+;\\d+t|\\u{07};\\d+;\\d+t",
                      options: .regularExpression) != nil {
            needsLineKill = false
            if let socket = webSocket {
                socket.send(.string("\u{15}")) { _ in }
            }
        }
        // NUL bytes (the PTY prepends \u0000 to control frames).
        cleaned = cleaned.replacingOccurrences(of: "\u{00}", with: "")
        // C1 control normalization: the server may send the CSI as the single
        // char U+009B (C1) instead of ESC+[ — SwiftTerm can't parse C1, and
        // our sequencer's ESC check misses it. Normalize the common C1 set.
        cleaned = cleaned.replacingOccurrences(of: "\u{009B}", with: "\u{1B}[")
        cleaned = cleaned.replacingOccurrences(of: "\u{009D}", with: "\u{1B}]")
        cleaned = cleaned.replacingOccurrences(of: "\u{0090}", with: "\u{1B}P")
        let combined = ansiBuffer + cleaned
        ansiBuffer = ""

        var out = ""
        var i = combined.startIndex
        while i < combined.endIndex {
            let c = combined[i]
            if c == "\u{1B}" {
                let after = combined.index(after: i)
                if after < combined.endIndex && combined[after] == "[" {
                    // CSI sequence: find the final byte (0x40–0x7E).
                    var j = combined.index(after: after)
                    var complete = false
                    while j < combined.endIndex {
                        let fc = combined[j]
                        if fc >= "\u{40}" && fc <= "\u{7E}" {
                            j = combined.index(after: j)
                            complete = true
                            break
                        }
                        j = combined.index(after: j)
                    }
                    if !complete {
                        ansiBuffer = String(combined[i...])
                        break
                    }
                    let seq = String(combined[i..<j])
                    // Drop window-resize echoes; feed everything else.
                    if !seq.hasPrefix("\u{1B}[8;") {
                        out += seq
                    }
                    i = j
                    continue
                } else if after < combined.endIndex && combined[after] == "]" {
                    // OSC (title etc.): ends at BEL (\x07) or ST (\x1B\\)
                    var k = after
                    var terminated = false
                    while k < combined.endIndex {
                        if combined[k] == "\u{07}" {
                            k = combined.index(after: k); terminated = true; break
                        }
                        if combined[k] == "\u{1B}" {
                            let nk = combined.index(after: k)
                            if nk < combined.endIndex && combined[nk] == "\\" {
                                k = combined.index(nk, offsetBy: 1)
                                if k > combined.endIndex { k = combined.endIndex }
                                terminated = true; break
                            }
                        }
                        k = combined.index(after: k)
                    }
                    if !terminated {
                        ansiBuffer = String(combined[i...])
                        break
                    }
                    out += String(combined[i..<k])
                    i = k
                    continue
                } else {
                    // Bare ESC at the very end — hold it.
                    if after >= combined.endIndex {
                        ansiBuffer = String(combined[i...])
                        break
                    }
                    out += String(combined[i])
                    i = after
                    continue
                }
            } else {
                out += String(combined[i])
                i = combined.index(after: i)
            }
        }

        guard !out.isEmpty else { return }
        feedToTerminal(out)
    }

    private func feedToTerminal(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.terminalView?.feed(text: text)
        }
    }

    // MARK: - Send input (§12.3)

    /// Forwards keyboard input from SwiftTerm to the remote PTY.
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

    /// Last size sent (avoids echoing the same resize repeatedly — the PTY
    /// echoes the ANSI sequence back, which we strip on receive, but sending
    /// less is cleaner).
    private var lastSentCols = 0
    private var lastSentRows = 0

    /// Sends an ANSI terminal resize so the remote PTY reflows. Ignores
    /// degenerate initial frames (< 40 cols/rows — SwiftTerm's default
    /// 320×480 pre-layout frame) and repeats.
    func sendResize(cols: Int, rows: Int) {
        guard cols > 40, rows > 20,
              cols != lastSentCols || rows != lastSentRows else { return }
        lastSentCols = cols
        lastSentRows = rows
        guard let socket = webSocket else { return }
        socket.send(.string("\u{1b}[8;\(rows);\(cols)t")) { _ in }
    }

    // MARK: - Reconnection with backoff

    private func handleDisconnect() {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionLost = true
            self.statusText = "Connection lost — reconnecting…"
        }
        feedToTerminal("\r\n\u{001b}[31mConnection lost — reconnecting…\u{001b}[0m\r\n")

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.isManualDisconnect else { return }
            self.reconnectAttempts += 1
            let delay = min(2.0 * pow(2.0, Double(self.reconnectAttempts - 1)), 60.0)
            self.sessionQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, !self.isManualDisconnect else { return }
                self.webSocket?.cancel()
                self.webSocket = nil
                // Recreate the PTY (the old one may have died with the socket).
                self.createPTYThenConnect()
            }
        }
    }

    // MARK: - Disconnect (cleanup: kill PTY on the server)

    func disconnect() {
        isManualDisconnect = true
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        if let session = session, let ptyID = ptyID,
           let url = URL(string: "\(session.server.baseURL)/pty/\(ptyID)") {
            var req = URLRequest(url: url)
            req.httpMethod = "DELETE"
            URLSession.shared.dataTask(with: req).resume()
        }
        ptyID = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.statusText = "Disconnected"
        }
    }

    deinit {
        webSocket?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - Status

    private func updateStatus(_ text: String) {
        // Assign synchronously when already on main — the async hop can sit
        // behind a main-runloop stall (a 100-message transcript layout stalls
        // it for tens of seconds) and the label then shows the stale initial
        // "Disconnected" while the shell is already rendering (E-14 finding).
        if Thread.isMainThread {
            self.statusText = text
        } else {
            DispatchQueue.main.async {
                self.statusText = text
            }
        }
    }
}

import SwiftUI
import Combine
import SwiftTerm

/// Posted by the MC test hook to send a message through the VISIBLE chat
/// view's own composer path (FORGE_TEST_MC_SEND="<text>").
extension Notification.Name {
    static let forgeMCSend = Notification.Name("forge.mc.send")
    static let forgeMCOpenTerminal = Notification.Name("forge.mc.openTerminal")
}

/// RemoteSessionChatView
///
/// Mission Control session detail — renders a REAL opencode session's message
/// stream with the EXACT same TUI components as the on-device agent
/// (MessageView/PartView: Thinking blocks, tool rows, write panels, markdown
/// prose, turn footers). Fetches GET /session/{id}/message and polls for
/// updates, exactly like the on-device ChatStore flow.
struct RemoteSessionChatView: View {
    let session: RemoteSession

    @State private var messages: [ChatMessage] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var showTerminal = false
    @State private var pollTask: Task<Void, Never>?

    // Full remote control (the point of Mission Control): the composer sends
    // into the session via the canonical prompt_async endpoint.
    @State private var inputText = ""
    @State private var isSending = false
    @State private var sendError: String?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header: session name + agent/model + tokens/cost (footer-style,
            // mirroring the on-device minimal header).
            HStack(spacing: 8) {
                Text(session.displayName)
                    .font(TuiTheme.bodyFont.bold())
                    .foregroundStyle(TuiTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Button {
                    showTerminal = true
                } label: {
                    Image(systemName: "terminal")
                        .foregroundStyle(TuiTheme.textDim)
                }
            }
            .padding(.horizontal, TuiTheme.transcriptPad)
            .frame(height: 44)
            .background(TuiTheme.bg)
            .overlay(alignment: .bottom) { Divider().overlay(TuiTheme.panelBorder) }

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().tint(TuiTheme.violet)
                    Text("Loading session…")
                        .font(TuiTheme.smallFont)
                        .foregroundStyle(TuiTheme.textDim)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TuiTheme.bg)
            } else if let errorText {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(TuiTheme.failure)
                    Text(errorText)
                        .font(TuiTheme.smallFont)
                        .foregroundStyle(TuiTheme.textDim)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Retry") { fetch() }
                        .font(TuiTheme.smallFont)
                        .foregroundStyle(TuiTheme.violet)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TuiTheme.bg)
            } else {
                // THE SAME transcript surface as on-device.
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: TuiTheme.blockGap) {
                            ForEach(messages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, TuiTheme.transcriptPad)
                        .padding(.vertical, TuiTheme.blockGap)
                    }
                    .background(TuiTheme.bg)
                    .onChange(of: messages.count) { _, _ in
                        scrollTranscript(proxy)
                    }
                    .onChange(of: messages.first?.id) { _, _ in
                        // JOIN swaps the whole array; count can stay 40.
                        scrollTranscript(proxy)
                    }
                }
            }

            composerBar
        }
        .background(TuiTheme.bg.ignoresSafeArea())
    .sheet(isPresented: $showTerminal) {
        RemotePTYSheet(session: session)
    }
    .onReceive(NotificationCenter.default.publisher(for: .forgeMCSend)) { note in
        // Scoped: only the chat view whose session is the target sends
        // (a broadcast must never fire into every alive page).
        guard let target = note.userInfo?["sessionID"] as? String,
              target == session.id else { return }
        guard let text = note.userInfo?["text"] as? String, !text.isEmpty else { return }
        sendMessage(text)
    }
    .onReceive(NotificationCenter.default.publisher(for: .forgeMCOpenTerminal)) { note in
        // Scoped like forgeMCSend — only the targeted session's page opens
        // its PTY sheet (the C7 test hook drives the same code as the
        // header terminal button).
        guard let target = note.userInfo?["sessionID"] as? String,
              target == session.id else { return }
        showTerminal = true
    }
    .onAppear { startPolling() }
    .onDisappear { pollTask?.cancel() }
}

// MARK: - Composer (full remote control)

    /// The input bar — the SAME styling family as the on-device composer
    /// (dark, monospace, violet accent). Sends via
    /// POST /session/{id}/prompt_async (the canonical endpoint; the server
    /// runs the turn with its default agent/model — verified live against
    /// the dragon server).
    private var composerBar: some View {
        VStack(spacing: 0) {
            if let sendError {
                Text(sendError)
                    .font(TuiTheme.smallFont)
                    .foregroundStyle(TuiTheme.failure)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, TuiTheme.transcriptPad)
                    .padding(.top, 4)
            }
            HStack(spacing: 8) {
                TextField("Message the session…", text: $inputText, axis: .vertical)
                    .font(TuiTheme.bodyFont)
                    .foregroundStyle(TuiTheme.textPrimary)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(TuiTheme.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(TuiTheme.panelBorder, lineWidth: 1)
                    )
                    .submitLabel(.send)
                    .onSubmit { sendMessage(inputText) }

                Button {
                    sendMessage(inputText)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(
                            canSend ? TuiTheme.violet : TuiTheme.textDim.opacity(0.4)
                        )
                }
                .disabled(!canSend)
                .accessibilityIdentifier("remoteSendButton")
            }
            .padding(.horizontal, TuiTheme.transcriptPad)
            .padding(.vertical, 8)
            .background(TuiTheme.bg)
            .overlay(alignment: .top) { Divider().overlay(TuiTheme.panelBorder) }
        }
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    /// Sends the message into the session. 204 = accepted; the existing 5s
    /// poll picks up the user echo + the assistant reply.
    private func sendMessage(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        guard let url = URL(string: "\(session.server.baseURL)/session/\(session.id)/prompt_async") else {
            sendError = "Invalid URL"
            return
        }
        isSending = true
        sendError = nil
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(
            // L1 ENFORCEMENT (2026-08-15): pin agent=trident + the free zen
            // model on EVERY composer send — without this the server runs its
            // default agent (observed: a reply footered "■ build" on a live
            // battery run, violating the trident-only law). The serve's zen
            // provider id is "opencode" (verified live — "opencode-zen" and
            // "zen" return ProviderModelNotFoundError).
            withJSONObject: [
                "parts": [["type": "text", "text": text]],
                "agent": "trident",
                "model": ["providerID": "opencode", "modelID": ZenModelCatalog.defaultModelID]
            ]
        )
        URLSession.shared.dataTask(with: req) { _, resp, error in
            DispatchQueue.main.async {
                self.isSending = false
                if let error = error {
                    self.sendError = "Send failed: \(error.localizedDescription)"
                    return
                }
                guard let http = resp as? HTTPURLResponse, http.statusCode == 204 else {
                    let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
                    self.sendError = "Send failed (HTTP \(code))"
                    return
                }
                self.inputText = ""
                self.fetch()
            }
        }.resume()
    }

    private func scrollTranscript(_ proxy: ScrollViewProxy) {
        let e2e = ProcessInfo.processInfo.environment["FORGE_TEST_FULL_E2E"] == "1"
            || ProcessInfo.processInfo.environment["FORGE_TEST_MC_JOIN"] != nil
        if e2e, let taskID = messages.last(where: {
            $0.parts.contains { $0.tool?.name.lowercased() == "task" }
        })?.id {
            // LAST task row = the most recent subagent state (the first can
            // be a stale errored attempt — red for a live agent read wrong).
            proxy.scrollTo(taskID, anchor: .top)
        } else if let last = messages.last {
            withAnimation(.linear(duration: 0.08)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Fetch / poll

    private func startPolling() {
        fetch()
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run { self.fetch() }
            }
        }
    }

    private func fetch() {
        // Cap the fetch — unbounded /message on a 100-session serve
        // (the 27GB catastrophe class) hangs the serve and the sheet
        // sits on "Loading session…" forever. 40 newest is enough to
        // render the live tail including 1.14.51 task / bg-subagent rows.
        guard let url = URL(string: "\(session.server.baseURL)/session/\(session.id)/message?limit=40") else {
            errorText = "Invalid URL"
            isLoading = false
            return
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        URLSession.shared.dataTask(with: req) { data, resp, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorText = error.localizedDescription
                    return
                }
                guard let data = data,
                      let envelopes = try? JSONDecoder().decode(
                        [RemoteMessageEnvelope].self, from: data) else {
                    self.errorText = "Decode failed"
                    return
                }
                self.errorText = nil
                self.messages = RemoteMessageMapper.map(envelopes)
            }
        }.resume()
    }}

// MARK: - Remote PTY sheet (on-demand terminal attach)

/// The live PTY terminal for this session (created on demand — avoids
/// spawning a server-side PTY for every page while browsing).
struct RemotePTYSheet: View {
    let session: RemoteSession
    @Environment(\.dismiss) private var dismiss
    @State private var terminalView: TerminalView?
    // @StateObject, NOT @State — @State with a class never subscribes to its
    // @Published changes, so the status label never refreshed off the initial
    // "Disconnected" (the label only moved when an external poll re-render
    // happened to re-read it — the E-14 root cause: a live connected shell
    // labeled "Disconnected" because nothing watched the assignment).
    @StateObject private var viewModel = RemoteSessionViewModel()
    // The TerminalView is assigned ASYNC inside makeUIView — onAppear races it
    // (terminalView is still nil → connect() silently never fired → the sheet
    // sat "Disconnected" forever; C7 2026-08-15). Connect on FIRST availability
    // via onChange, guarded so a later onAppear can't double-connect.
    @State private var didStartPTY = false

    private func startPTYIfPossible(_ tv: TerminalView?) {
        guard !didStartPTY, let tv else { return }
        didStartPTY = true
        viewModel.connect(to: session, terminalView: tv)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(session.displayName)
                    .font(TuiTheme.bodyFont.bold())
                    .foregroundStyle(TuiTheme.textPrimary)
                Spacer()
                Text(viewModel.statusText)
                    .font(TuiTheme.smallFont)
                    .foregroundStyle(TuiTheme.textDim)
                Button("Close") { dismiss() }
                    .font(TuiTheme.smallFont)
                    .foregroundStyle(TuiTheme.violet)
            }
            .padding(.horizontal, TuiTheme.transcriptPad)
            .frame(height: 44)
            .background(TuiTheme.bg)
            .overlay(alignment: .bottom) { Divider().overlay(TuiTheme.panelBorder) }

            TerminalViewRepresentable(terminalView: $terminalView,
                                      onSend: { viewModel.sendInput($0) },
                                      onResize: { viewModel.sendResize(cols: $0, rows: $1) })
                .background(TuiTheme.bg)
        }
        .background(TuiTheme.bg.ignoresSafeArea())
        .onAppear {
            startPTYIfPossible(terminalView)
        }
        .onChange(of: terminalView) { _, newTV in
            startPTYIfPossible(newTV)
        }
        .onDisappear {
            viewModel.disconnect()
            // Reset the guard — otherwise a later re-presentation can never
            // re-connect (didStartPTY stays true) and the sheet goes dead at
            // "Disconnected" with the frozen shell render (the E-14 bug).
            didStartPTY = false
        }
    }
}

/// SwiftTerm wrapper for the MC PTY (11pt mono — matches the pager sizing).
struct TerminalViewRepresentable: UIViewRepresentable {
    @Binding var terminalView: TerminalView?
    let onSend: (Data) -> Void
    let onResize: (Int, Int) -> Void

    func makeUIView(context: Context) -> TerminalView {
        let tv = TerminalView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        tv.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        tv.nativeBackgroundColor = ForgeTheme.backgroundColor
        tv.nativeForegroundColor = ForgeTheme.foregroundColor
        tv.selectedTextBackgroundColor = ForgeTheme.selectionColor
        tv.installColors(ForgeTheme.ansiColors)
        tv.changeScrollback(5000)
        tv.terminalDelegate = context.coordinator
        DispatchQueue.main.async {
            self.terminalView = tv
        }
        return tv
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {
        uiView.terminalDelegate = context.coordinator
        context.coordinator.onSend = onSend
        context.coordinator.onResize = onResize
    }

    func makeCoordinator() -> Coordinator { Coordinator(onSend: onSend, onResize: onResize) }

    final class Coordinator: NSObject, TerminalViewDelegate {
        var onSend: ((Data) -> Void)?
        var onResize: ((Int, Int) -> Void)?
        init(onSend: @escaping (Data) -> Void, onResize: @escaping (Int, Int) -> Void) {
            self.onSend = onSend; self.onResize = onResize
        }
        func send(source: TerminalView, data: ArraySlice<UInt8>) { onSend?(Data(data)) }
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) { onResize?(newCols, newRows) }
        func setTerminalTitle(source: TerminalView, title: String) {}
        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
        func bell(source: TerminalView) {}
        func clipboardCopy(source: TerminalView, content: Data) {}
        func clipboardRead(source: TerminalView) -> Data? { nil }
        func scrolled(source: TerminalView, position: Double) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}

// MARK: - Remote message decode + mapping to the shared TUI model

/// GET /session/{id}/message envelope (real opencode shape).
struct RemoteMessageEnvelope: Codable {
    let info: RemoteMessageInfo
    let parts: [RemotePart]
}

struct RemoteMessageInfo: Codable {
    let id: String
    let role: String?
    let agent: String?
    let modelID: String?
    let providerID: String?
    let finish: String?
    let cost: Double?
    let time: RemoteTime?

    struct RemoteTime: Codable {
        let created: Int64?
        let completed: Int64?
    }
}

struct RemotePart: Codable {
    let type: String?
    let text: String?
    let tool: String?
    let filename: String?
    let state: RemoteToolState?

    struct RemoteToolState: Codable {
        let status: String?
        let input: RemoteToolInput?
        let content: [RemoteContent]?
        let output: String?
        let title: String?

        struct RemoteToolInput: Codable {
            let path: String?
            let filePath: String?
            let command: String?
            let title: String?
            // 1.14.51 task / bg-subagent fields (N5)
            let description: String?
            let subagent_type: String?
            let background: Bool?
        }
        struct RemoteContent: Codable {
            let type: String?
            let text: String?
        }
    }
}

enum RemoteMessageMapper {
    /// Deterministic UUID from a seed string (double FNV-1a). The 5s poll
    /// remaps the whole message array — random UUIDs would recreate every
    /// row each cycle and reset user expansion state (N3 tap-to-expand);
    /// stable ids keep LazyVStack row identity (and @State) alive.
    static func stableUUID(_ seed: String) -> UUID {
        var h1: UInt64 = 0xcbf29ce484222325
        var h2: UInt64 = 0xcbf29ce484222325
        for b in seed.utf8 {
            h1 = (h1 ^ UInt64(b)) &* 0x100000001b3
            h2 = (h2 &+ UInt64(b)) &* 0x00000100000001B3
        }
        let hex = String(format: "%08X%08X-%04X-4%03X-8%03X-%06X%06X",
                         UInt32(truncatingIfNeeded: h1 >> 32),
                         UInt32(truncatingIfNeeded: h1),
                         UInt16(truncatingIfNeeded: h2 >> 48),
                         UInt16(truncatingIfNeeded: (h2 >> 36) & 0x0FFF),
                         UInt16(truncatingIfNeeded: (h2 >> 24) & 0x0FFF),
                         UInt32(truncatingIfNeeded: h2 >> 32) ^ UInt32(truncatingIfNeeded: h1 >> 32),
                         UInt32(truncatingIfNeeded: h2))
        return UUID(uuidString: hex) ?? UUID()
    }

    /// Maps real session messages into the SAME ChatMessage/Part model the
    /// on-device agent uses — so MessageView/PartView render identically.
    static func map(_ envelopes: [RemoteMessageEnvelope]) -> [ChatMessage] {
        envelopes.compactMap { env in
            let role: ChatMessage.Role = (env.info.role == "user")
                ? .user(queued: false)
                : .assistant

            var parts: [Part] = []
            // D3: the serve emits a step-finish per LLM step — a footer per
            // step spammed the transcript. Only the LAST step-finish in the
            // message renders the epilogue (opencode behavior).
            let lastFinishIdx = env.parts.lastIndex { $0.type == "step-finish" }
            for (pidx, p) in env.parts.enumerated() {
                let seed = "\(env.info.id)#\(pidx)"
                switch p.type {
                case "text":
                    if let text = p.text, !text.isEmpty {
                        parts.append(Part(id: stableUUID(seed + "t"), kind: .prose, text: text))
                    }
                case "reasoning":
                    if let text = p.text, !text.isEmpty {
                        parts.append(Part(id: stableUUID(seed + "r"), kind: .thinking, text: text))
                    }
                case "tool":
                    let name = p.tool ?? "tool"
                    let title = Self.toolTitle(p)
                    let status: ToolState.Status = Self.toolStatus(p)
                    let payload = Self.toolPayload(p)
                    parts.append(Part(id: stableUUID(seed + "k"), kind: .tool, text: "",
                                      tool: ToolState(name: name, title: title,
                                                      detail: nil, status: status,
                                                      payload: payload, expanded: false)))
                case "file":
                    let path = p.filename ?? "file"
                    let content = Self.fileContent(p) ?? ""
                    parts.append(Part(id: stableUUID(seed + "w"), kind: .write, text: "",
                                      write: WriteState(path: path, bytes: content.utf8.count,
                                                        content: content, expanded: false)))
                case "step-finish":
                    guard pidx == lastFinishIdx else { break }
                    let agent = env.info.agent ?? "agent"
                    let model = env.info.modelID ?? ""
                    let cost = env.info.cost ?? 0
                    let footer = "▣ \(agent) · \(model) · $\(String(format: "%.4f", cost))"
                    parts.append(Part(id: stableUUID(seed + "f"), kind: .turnFooter, text: footer))
                case "step-start", "agent", "compaction", "retry", "snapshot", "patch":
                    break // noise — skip
                default:
                    if let text = p.text, !text.isEmpty {
                        parts.append(Part(id: stableUUID(seed + "d"), kind: .prose, text: text))
                    }
                }
            }
            guard !parts.isEmpty else { return nil }

            return ChatMessage(
                id: stableUUID(env.info.id),
                role: role,
                parts: parts,
                agentName: env.info.agent ?? "agent",
                modelName: env.info.modelID ?? "",
                startedAt: Date(timeIntervalSince1970: Double(env.info.time?.created ?? 0) / 1000),
                completedAt: env.info.time?.completed.map {
                    Date(timeIntervalSince1970: Double($0) / 1000)
                }
            )
        }
    }

    private static func toolTitle(_ p: RemotePart) -> String {
        // 1.14.51 task / bg-subagent ALWAYS prefixes kind + (background)
        // so the row is greppable on tape. Serve title/description ride after.
        if let kind = p.state?.input?.subagent_type, !kind.isEmpty {
            let bg = (p.state?.input?.background == true) ? " (background)" : ""
            let desc = p.state?.title ?? p.state?.input?.description ?? ""
            return desc.isEmpty ? "\(kind)\(bg)" : "\(kind)\(bg) — \(desc)"
        }
        if let t = p.state?.title, !t.isEmpty { return t }
        guard let input = p.state?.input else { return "" }
        return input.path ?? input.filePath ?? input.command ?? input.title ?? input.description ?? ""
    }

    private static func toolStatus(_ p: RemotePart) -> ToolState.Status {
        switch p.state?.status {
        case "completed": return .done(ok: true)
        case "error": return .done(ok: false)
        case "pending", "running": return .running
        default: return .running
        }
    }

    private static func toolPayload(_ p: RemotePart) -> String? {
        if let content = p.state?.content, !content.isEmpty {
            return content.compactMap { $0.text }.joined(separator: "\n")
        }
        // 1.14.51 task tool: the child return lives in state.output (string).
        if let out = p.state?.output, !out.isEmpty { return out }
        return nil
    }

    private static func fileContent(_ p: RemotePart) -> String? {
        // Tool parts carry the file content in state.content (text items);
        // file parts may reference a URL. Best-effort: state content.
        p.state?.content?.compactMap { $0.text }.joined(separator: "\n")
    }
}

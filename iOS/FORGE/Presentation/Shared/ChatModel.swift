import Foundation
import SwiftUI
import os

/// Unified-log handle for the preview trigger chain (Wave 4 greps `[PREVIEW]`
/// on the device log to count posts vs shows — print() does not persist).
let previewLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.forge.app", category: "preview")

// ChatModel.swift — the opencode-TUI data model (spec §3).
//
// THE CRITICAL RULE: streaming deltas MUTATE the existing part's `.text`
// string — they do NOT create new parts per delta (Anti-Pattern AP1, the
// word-per-line duplication bug). appendProseDelta("hello") appends to the
// last prose part of the current assistant message; same for thinking.
// Stable UUIDs make SwiftUI's LazyVStack diff correctly (AP12).
//
// Also hosts the LaneRouter (spec §4): the ONLY entry point for engine chat
// events. File content can ONLY ever reach attachWrite/attachDiff — there is
// no code path from tool arguments to prose (Anti-Pattern AP4, the worst
// bug).

// MARK: - Parts: one message is an ordered list of typed parts.

enum PartKind: Equatable {
    case prose              // lane 1 — markdown text
    case thinking           // lane 3 — reasoning
    case tool               // lane 4 — tool row (edit/write/read/task/…)
    case bash               // lane 5 — command panel
    case toolOneLiner       // lane 6 — dim summary line
    case phase              // lane 7 — "~ Preparing X..." (transient)
    case diff               // lane 2 — edit payload
    case write              // lane 2 — new-file payload
    case turnFooter         // "■ Agent · Model · 2m 41s"
    case statusBanner       // "✅ DONE — …"
    case error              // lane 8 — visible error row (⚠)
}

struct ToolState: Equatable {
    enum Status: Equatable { case preparing, running, done(ok: Bool) }
    var name: String            // "Edit", "Write", "Task", "Read"
    var title: String           // "battlefront/src/presentation/fps-view.ts"
    var detail: String?         // "└ 195 bytes" / "└ P4-A asset pipeline"
    var status: Status
    var payload: String?        // full args/output — shown ONLY on expand
    var expanded: Bool = false
}

struct BashState: Equatable {
    var title: String           // "# Weapon depth fix + fps shot"
    var command: String         // the "$ ..." line
    var output: String          // accumulated stdout
    var expanded: Bool = false
    static let collapsedLineLimit = 12
}

struct DiffState: Equatable {
    var path: String
    var hunks: [DiffHunk]       // see DiffEngine.swift
}

struct WriteState: Equatable {
    var path: String
    var bytes: Int
    var content: String
    var expanded: Bool = false
}

struct Part: Identifiable, Equatable {
    let id: UUID
    var kind: PartKind
    var text: String            // prose / thinking / phase / banner / oneLiner body
    var tool: ToolState?
    var bash: BashState?
    var diff: DiffState?
    var write: WriteState?
}

struct ChatMessage: Identifiable, Equatable {
    enum Role: Equatable { case user(queued: Bool), assistant }
    let id: UUID
    var role: Role
    var parts: [Part]
    var agentName: String       // "Build", "Trident", "Trident_build"
    var modelName: String       // from SessionConfig — NEVER hardcoded
    var startedAt: Date
    var completedAt: Date?
}

// MARK: - Session status (header + footer ticks)

struct SessionStatus: Equatable {
    var tokens: Int = 0
    var contextPct: Int = 0
    var costUSD: Double = 0
    var modelDisplayName: String = ""   // ← from engine config, NEVER hardcoded
    var agentName: String = ""
    var isRunning: Bool = false
    var workspace: String = ""          // "FORGE-Demo"
    var branch: String = ""             // "master"
    var version: String = ""            // app version
}

struct SubagentStatus: Equatable {
    var name: String        // "Trident_build"
    var step: Int           // 39
    var totalSteps: Int     // 41
    var tokens: Int         // 277_100 → ticks live
    var pct: Int            // 28
    var costUSD: Double     // 0.07
}

// MARK: - ChatStore — the single mutation point (spec §3).

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var status = SessionStatus()     // tokens, pct, cost, model, running
    @Published var subagent: SubagentStatus?    // drives the strip (§5.12)

    // Streaming targets — the ids of the parts currently receiving deltas.
    private var activeProse: UUID?
    private var activeThinking: UUID?

    // MARK: User / turn lifecycle

    func appendUser(_ text: String, queued: Bool) {
        let msg = ChatMessage(
            id: UUID(),
            role: .user(queued: queued),
            parts: [Part(id: UUID(), kind: .prose, text: text)],
            agentName: status.agentName,
            modelName: status.modelDisplayName,
            startedAt: Date(),
            completedAt: Date()
        )
        messages.append(msg)
        status.isRunning = true
    }

    /// Rebuilds the transcript from persisted session records (the restore
    /// half of transcript persistence — J1-L7: select() used to load nothing).
    /// User records: {role:"user", text}. Assistant records:
    /// {role:"assistant", parts:[{kind,text,toolName?,toolTitle?,writePath?}]}.
    func loadPersisted(_ records: [String]) {
        var restored: [ChatMessage] = []
        for rec in records {
            guard let data = rec.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let role = obj["role"] as? String else { continue }
            if role == "user", let text = obj["text"] as? String {
                restored.append(ChatMessage(
                    id: UUID(),
                    role: .user(queued: false),
                    parts: [Part(id: UUID(), kind: .prose, text: text)],
                    agentName: status.agentName,
                    modelName: status.modelDisplayName,
                    startedAt: Date(),
                    completedAt: Date()))
            } else if role == "assistant", let arr = obj["parts"] as? [[String: String]] {
                let parts: [Part] = arr.map { d in
                    let text = d["text"] ?? ""
                    switch d["kind"] {
                    case "thinking":
                        return Part(id: UUID(), kind: .thinking, text: text)
                    case "tool":
                        var p = Part(id: UUID(), kind: .tool, text: text)
                        p.tool = ToolState(name: d["toolName"] ?? "tool",
                                           title: d["toolTitle"] ?? "",
                                           status: .done(ok: true))
                        return p
                    case "bash":
                        return Part(id: UUID(), kind: .bash, text: text)
                    case "write":
                        var p = Part(id: UUID(), kind: .write, text: text)
                        p.write = WriteState(path: d["writePath"] ?? "",
                                             bytes: Int(d["writeBytes"] ?? "0") ?? 0,
                                             content: "")
                        return p
                    default:
                        return Part(id: UUID(), kind: .prose, text: text)
                    }
                }
                restored.append(ChatMessage(
                    id: UUID(),
                    role: .assistant,
                    parts: parts,
                    agentName: status.agentName,
                    modelName: status.modelDisplayName,
                    startedAt: Date(),
                    completedAt: Date()))
            }
        }
        messages = restored
    }

    func beginAssistantTurn(agent: String, model: String) {
        // A new assistant turn invalidates streaming targets so the next
        // delta creates a fresh part (no bleed into the previous turn).
        activeProse = nil
        activeThinking = nil
        let msg = ChatMessage(
            id: UUID(),
            role: .assistant,
            parts: [],
            agentName: agent.isEmpty ? status.agentName : agent,
            modelName: model.isEmpty ? status.modelDisplayName : model,
            startedAt: Date(),
            completedAt: nil
        )
        messages.append(msg)
        status.isRunning = true
    }

    // MARK: Delta mutation (THE fix for AP1)

    /// Appends `delta` to the active prose part, creating one if none exists.
    /// NEVER creates one part per delta.
    func appendProseDelta(_ delta: String) {
        guard !delta.isEmpty else { return }
        guard let lastIdx = messages.indices.last else { return }
        guard case .assistant = messages[lastIdx].role else { return }

        if let pid = activeProse,
           let pidx = messages[lastIdx].parts.firstIndex(where: { $0.id == pid }) {
            messages[lastIdx].parts[pidx].text += delta
        } else {
            // Switching lanes (e.g. thinking → prose): start a new prose part.
            let np = Part(id: UUID(), kind: .prose, text: delta)
            messages[lastIdx].parts.append(np)
            activeProse = np.id
        }
    }

    /// Appends `delta` to the active thinking part, creating one if none.
    func appendThinkingDelta(_ delta: String) {
        guard !delta.isEmpty else { return }
        guard let lastIdx = messages.indices.last else { return }
        guard case .assistant = messages[lastIdx].role else { return }

        if let pid = activeThinking,
           let pidx = messages[lastIdx].parts.firstIndex(where: { $0.id == pid }) {
            messages[lastIdx].parts[pidx].text += delta
        } else {
            let np = Part(id: UUID(), kind: .thinking, text: delta)
            messages[lastIdx].parts.append(np)
            activeThinking = np.id
        }
    }

    // MARK: Phase lines (lane 7 — exactly one, replaced by the tool row)

    func setPhase(_ text: String) {
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return }
        if let existing = messages[lastIdx].parts.firstIndex(where: { $0.kind == .phase }) {
            messages[lastIdx].parts[existing].text = text
        } else {
            messages[lastIdx].parts.append(Part(id: UUID(), kind: .phase, text: text))
        }
    }

    func clearPhase() {
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return }
        messages[lastIdx].parts.removeAll { $0.kind == .phase }
    }

    func appendError(_ text: String) {
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return }
        let display = text.hasPrefix("⚠") ? text : "⚠ \(text)"
        messages[lastIdx].parts.append(Part(id: UUID(), kind: .error, text: display))
        status.isRunning = false
    }

    var errorRow: String? {
        messages.last?.parts.last(where: { $0.kind == .error })?.text
    }

    // MARK: Tools

    // N8 WRITE DEDUP (2026-08-26): the engine emits BOTH a tool event AND a
    // write event for the same file write. Rendering both = two rows for one
    // action (`← hello.txt — 6 bytes` panel + `← write hello.txt` row — seen
    // in PHONE-E2E g-09 + lag2.png). The panel is strictly richer (title +
    // bytes + content), so ONE row survives regardless of event order:
    //   write-first → the tool row is REPLACED in place by the panel;
    //   tool-first  → the tool row is SKIPPED (the panel already exists).

    /// Index of the LAST write-tool row matching `path` (title ↔ path), if any.
    private func matchingWriteToolRowIdx(in msg: Int, path: String) -> Int? {
        messages[msg].parts.lastIndex { p in
            guard p.kind == .tool, let t = p.tool else { return false }
            guard t.name.lowercased().contains("write") else { return false }
            if t.title.isEmpty || path.isEmpty { return false }
            return t.title.contains(path) || path.contains(t.title)
        }
    }

    /// Whether a write panel matching `path` already exists in the turn.
    private func hasWritePanel(msg: Int, path: String) -> Bool {
        messages[msg].parts.contains { p in
            guard p.kind == .write, let w = p.write else { return false }
            return w.path == path || path.contains(w.path) || w.path.contains(path)
        }
    }

    func beginTool(name: String, title: String) -> UUID {
        clearPhase()
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return UUID() }
        let part = Part(id: UUID(), kind: .tool, text: "",
                        tool: ToolState(name: name, title: title, detail: nil,
                                        status: .running, payload: nil, expanded: false))
        messages[lastIdx].parts.append(part)
        return part.id
    }

    func setToolDetail(id: UUID, _ detail: String) {
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return }
        if let pidx = messages[lastIdx].parts.firstIndex(where: { $0.id == id && $0.kind == .tool }) {
            messages[lastIdx].parts[pidx].tool?.detail = detail
        }
    }

    func setToolPayload(id: UUID, payload: String) {
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return }
        if let pidx = messages[lastIdx].parts.firstIndex(where: { $0.id == id && $0.kind == .tool }) {
            messages[lastIdx].parts[pidx].tool?.payload = payload
        }
    }

    func completeTool(id: UUID, ok: Bool, payload: String?) {
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return }
        if let pidx = messages[lastIdx].parts.firstIndex(where: { $0.id == id && $0.kind == .tool }) {
            messages[lastIdx].parts[pidx].tool?.status = .done(ok: ok)
            if let payload { messages[lastIdx].parts[pidx].tool?.payload = payload }
        }
    }

    /// Records a tool that the bundle reports as already-complete (the bundle
    /// emits a single "tool" event post-execution with a ✓/✗ status).
    func recordTool(name: String, title: String, ok: Bool, detail: String?) {
        clearPhase()
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return }
        // N8 dedup (tool-side): a write panel for this path already rendered —
        // the panel IS the row; appending would double-render one action.
        if name.lowercased().contains("write"), hasWritePanel(msg: lastIdx, path: title) {
            return
        }
        let part = Part(id: UUID(), kind: .tool, text: "",
                        tool: ToolState(name: name, title: title, detail: detail,
                                        status: .done(ok: ok), payload: nil, expanded: false))
        messages[lastIdx].parts.append(part)
        // After a tool part, the next thinking/prose delta must start a NEW
        // part — otherwise iteration-2 reasoning appends to the pre-tool part
        // and lands BEFORE the tool rows (wrong order). Reset stream targets.
        activeProse = nil
        activeThinking = nil
    }

    func appendOneLiner(_ text: String) {
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return }
        messages[lastIdx].parts.append(Part(id: UUID(), kind: .toolOneLiner, text: text))
    }

    // MARK: Bash (lane 5)

    func beginBash(title: String, command: String) -> UUID {
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return UUID() }
        let part = Part(id: UUID(), kind: .bash, text: "",
                        bash: BashState(title: title, command: command, output: "",
                                        expanded: false))
        messages[lastIdx].parts.append(part)
        return part.id
    }

    func appendBashOutput(id: UUID, delta: String) {
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return }
        if let pidx = messages[lastIdx].parts.firstIndex(where: { $0.id == id && $0.kind == .bash }) {
            messages[lastIdx].parts[pidx].bash?.output += delta
        }
    }

    // MARK: File payloads (lane 2) — THE AP4 guard: args never reach prose.

    /// Progressive write: appends a content chunk to the growing write part.
    /// Creates the write part on first chunk (expanded so the code is visible
    /// as it streams in — opencode desktop behavior).
    func appendWriteStream(path: String, chunk: String) {
        guard !chunk.isEmpty else { return }
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return }
        // Find or create the streaming write part for this path.
        if let pidx = messages[lastIdx].parts.firstIndex(where: {
            $0.kind == .write && $0.write?.path == path
        }) {
            messages[lastIdx].parts[pidx].write?.content += chunk
            messages[lastIdx].parts[pidx].write?.bytes = messages[lastIdx].parts[pidx].write?.content.utf8.count ?? 0
        } else {
            let part = Part(id: UUID(), kind: .write, text: "",
                            write: WriteState(path: path, bytes: chunk.utf8.count,
                                              content: chunk, expanded: true))
            // N8 dedup (panel-side): a write-tool row for this path already
            // exists (tool event fired first) — replace it IN PLACE so the
            // row count for this action stays exactly one.
            if let tidx = matchingWriteToolRowIdx(in: lastIdx, path: path) {
                messages[lastIdx].parts[tidx] = part
            } else {
                messages[lastIdx].parts.append(part)
            }
        }
        // Reset stream targets so the next prose/thinking starts a new part
        // after the write panel (correct ordering).
        activeProse = nil
        activeThinking = nil
    }

    func attachDiff(path: String, hunks: [DiffHunk]) {
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return }
        messages[lastIdx].parts.append(Part(id: UUID(), kind: .diff, text: "",
                                            diff: DiffState(path: path, hunks: hunks)))
        activeProse = nil
        activeThinking = nil
    }

    func attachWrite(path: String, bytes: Int, content: String) {
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return }
        // If a streaming write part already exists for this path, update it
        // with the final content (avoid duplicate write panels).
        if let pidx = messages[lastIdx].parts.firstIndex(where: {
            $0.kind == .write && $0.write?.path == path
        }) {
            messages[lastIdx].parts[pidx].write?.content = content
            messages[lastIdx].parts[pidx].write?.bytes = bytes
            // Keep expanded — the user should see the code that was written
            // (opencode desktop shows file content in the transcript).
        } else {
            // COLLAPSED by default (N3): the final write renders as a
            // one-liner (`▸ path — N bytes`); tap expands the code panel.
            let part = Part(id: UUID(), kind: .write, text: "",
                            write: WriteState(path: path, bytes: bytes,
                                              content: content, expanded: false))
            // N8 dedup (panel-side): replace an existing write-tool row in
            // place (same single-row-per-action contract as the stream path).
            if let tidx = matchingWriteToolRowIdx(in: lastIdx, path: path) {
                messages[lastIdx].parts[tidx] = part
            } else {
                messages[lastIdx].parts.append(part)
            }
        }
        activeProse = nil
        activeThinking = nil
    }

    // MARK: Turn completion

    func completeTurn() {
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return }
        messages[lastIdx].completedAt = Date()
        let agent = messages[lastIdx].agentName.isEmpty ? status.agentName : messages[lastIdx].agentName
        let model = messages[lastIdx].modelName.isEmpty ? status.modelDisplayName : messages[lastIdx].modelName
        let dur = messages[lastIdx].completedAt!.timeIntervalSince(messages[lastIdx].startedAt)
        let mins = Int(dur) / 60
        let secs = Int(dur) % 60
        let footer = "■ \(agent) · \(model) · \(mins)m \(secs)s"
        messages[lastIdx].parts.append(Part(id: UUID(), kind: .turnFooter, text: footer))
        status.isRunning = false
        activeProse = nil
        activeThinking = nil
    }

    func setStatusBanner(_ text: String) {
        guard let lastIdx = messages.indices.last,
              case .assistant = messages[lastIdx].role else { return }
        messages[lastIdx].parts.append(Part(id: UUID(), kind: .statusBanner, text: text))
    }

    // MARK: Convenience entry points used by the screen

    func sendUser(_ text: String) {
        appendUser(text, queued: status.isRunning)
    }

    func interrupt() {
        status.isRunning = false
    }

    func updateModel(_ displayName: String) {
        status.modelDisplayName = displayName
    }

    /// The last assistant prose (for "Copy last assistant message").
    var lastAssistantText: String? {
        for message in messages.reversed() {
            if case .assistant = message.role {
                let prose = message.parts.filter { $0.kind == .prose }
                    .map(\.text).joined(separator: "\n")
                if !prose.isEmpty { return prose }
            }
        }
        return nil
    }

    /// The full transcript (for "Copy session transcript").
    var transcriptText: String? {
        var out: [String] = []
        for message in messages {
            switch message.role {
            case .user:
                out.append("User: " + (message.parts.first?.text ?? ""))
            case .assistant:
                for part in message.parts {
                    switch part.kind {
                    case .prose: out.append(part.text)
                    case .thinking: out.append("Thinking: " + part.text)
                    case .tool: out.append("\(part.tool?.name ?? "") \(part.tool?.title ?? "")")
                    case .write: out.append("Write \(part.write?.path ?? "")")
                    case .error: out.append(part.text)
                    default: break
                    }
                }
            }
        }
        return out.isEmpty ? nil : out.joined(separator: "\n\n")
    }
}

// MARK: - LaneRouter (spec §4)

/// The ONLY entry point for engine chat events. The ForgeEngine still posts a
/// `.forgeChatMessage` notification (fire-and-forget), but this router turns
/// the raw payload into store MUTATIONS that merge deltas — it never appends
/// one ChatMessage per event.
@MainActor
struct LaneRouter {
    let store: ChatStore

    /// Handles a `.forgeChatMessage` notification userInfo dict as forwarded
    /// by `ForgeEngine` (kind + payload fields). All routing lives here so
    /// file content can ONLY ever reach attachWrite/attachDiff.
    func handleChatPayload(_ info: [AnyHashable: Any]) {
        let kind = (info["kind"] as? String) ?? ""
        switch kind {

        case "user":
            // The app already echoes the user's message locally (sendMessage
            // → chatStore.sendUser). The engine's emitChat("user") is a
            // redundant echo of the SAME send — appending it rendered the
            // prompt TWICE (plain + QUEUED). Dedupe: skip when the last
            // message is the identical local echo; append otherwise (covers
            // engine-originated user messages with no local echo).
            let text = (info["text"] as? String) ?? ""
            if let last = store.messages.last,
               case .user = last.role,
               last.parts.first?.text == text {
                break
            }
            store.appendUser(text, queued: store.status.isRunning)

        case "reasoning":
            // First thinking token arrived — kill the "working" phase line
            // so the streamed content replaces the dead-screen indicator.
            store.ensureAssistantTurn()
            store.clearPhase()
            store.appendThinkingDelta((info["text"] as? String) ?? "")

        case "assistant":
            store.ensureAssistantTurn()
            store.clearPhase()
            store.appendProseDelta((info["text"] as? String) ?? "")

        case "phase":
            store.ensureAssistantTurn()
            store.setPhase((info["text"] as? String) ?? "")

        case "write":
            // AP4 guard: file content → attachWrite ONLY, never prose.
            store.ensureAssistantTurn()
            let path = (info["path"] as? String) ?? ""
            let content = (info["content"] as? String) ?? ""
            let bytes = (info["bytes"] as? Int) ?? content.utf8.count
            store.attachWrite(path: path, bytes: bytes, content: content)

        case "writeStream":
            // Progressive write: the model's write_file arguments stream in
            // fragments. Each chunk appends to the growing write part so the
            // user sees the file being written in real-time (not an empty gap).
            store.ensureAssistantTurn()
            let wsPath = (info["path"] as? String) ?? "file"
            let wsChunk = (info["chunk"] as? String) ?? ""
            store.appendWriteStream(path: wsPath, chunk: wsChunk)

        case "tool":
            store.ensureAssistantTurn()
            let name = (info["name"] as? String) ?? ""
            let arg = (info["arg"] as? String) ?? ""
            let statusStr = (info["status"] as? String) ?? ""
            let ok = statusStr == "✓"
            store.recordTool(name: name, title: arg, ok: ok, detail: nil)
            if ok && (name == "write" || name == "write_file") && (arg as NSString).lastPathComponent == "index.html" {
                // Pipeline fix: muse tool_calls path never sends status "done" text.
                // M2 fix: the bundle posts args.path verbatim (forge-bundle.js:1938 —
                // "subdir/index.html", never the bare form), so exact == never fired.
                previewLog.info("[PREVIEW] post forgeTurnComplete via tool-write arg=\(arg, privacy: .public)")
                store.clearPhase()
                store.completeTurn()
                store.setStatusBanner("done 1 file(s)")
                NotificationCenter.default.post(name: .forgeTurnComplete, object: nil)
            }

        case "status":
            let text = (info["text"] as? String) ?? ""
            if text.lowercased().contains("done") {
                previewLog.info("[PREVIEW] post forgeTurnComplete via status text=\(text, privacy: .public)")
                store.clearPhase()
                store.completeTurn()
                store.setStatusBanner(text)
                NotificationCenter.default.post(name: .forgeTurnComplete, object: nil)
            } else {
                store.ensureAssistantTurn()
                store.setPhase(text.isEmpty ? "■ working…" : text)
                store.status.isRunning = true
            }

        case "error":
            store.ensureAssistantTurn()
            store.clearPhase()
            let errText = (info["text"] as? String) ?? "Unknown error"
            store.appendError(errText)

        default:
            break
        }
    }
}

private extension ChatStore {
    /// Lazily begins an assistant turn if no live assistant message exists —
    /// so streamed reasoning/prose deltas always have a home to mutate.
    func ensureAssistantTurn() {
        if let last = messages.last, case .assistant = last.role, last.completedAt == nil {
            return
        }
        beginAssistantTurn(agent: status.agentName, model: status.modelDisplayName)
    }
}

// MARK: - Number formatting helpers (header/footer)

extension Int {
    /// 276_100 → "276.1K", 1_200_000 → "1.2M".
    var kFormatted: String {
        if self >= 1_000_000 { return String(format: "%.1fM", Double(self) / 1e6) }
        if self >= 1_000 { return String(format: "%.1fK", Double(self) / 1e3) }
        return "\(self)"
    }
}

extension Double {
    /// 0.0731 → "$0.07".
    var usdFormatted: String { String(format: "$%.2f", self) }
}

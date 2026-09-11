# FORGE iOS TUI — COMPLETE BUILD SPECIFICATION (v4, builder-ready)

**Date:** 2026-08-04
**For:** the builder agent (deepseek) executing the FORGE UI overhaul
**READ THIS FIRST — HOW TO USE THIS DOCUMENT:**
1. This is not a suggestion document. It is a specification. Every color, every spacing value, every component name, and every code pattern below is normative.
2. Do not improvise visual decisions. If a value is not in this document, pick the closest analog from the measured token table (§2) and note the deviation in your PR.
3. The Anti-Patterns section (§7) is as important as the build steps. Each anti-pattern is a bug that ALREADY HAPPENED in this codebase. If you recognize code you are about to write in §7, stop and use the paired "correct" pattern instead.
4. Work the phases in order (§8). Each phase has acceptance checks. Do not start phase N+1 until phase N passes.
5. Reference frames cited like `ref3/f0125.png` live in `evidence/reference-frames/`. Look at them before building each component.

**Evidence base:** 836 frames directly read + pixel-measured from 4 videos (forge demo @3fps, REF1 primary TUI @3fps, REF2 subagent edit stream @3fps, REF3 primary live-build session @5fps).

**THE TARGET IN ONE SENTENCE:** opencode's TUI — same mechanics, same colors, same block types, same streaming behavior — sized to an iPhone. Sidebar→drawer, two footer lines→one, unified diffs (which is what the primary agent uses anyway). Nothing else is adapted.

---

## TABLE OF CONTENTS

1. The Information Architecture (what renders where, and why)
2. Measured Design Tokens (the theme)
3. The Data Model (messages, parts, the store)
4. The Lane Router (streaming events → parts)
5. Component Specifications with Full SwiftUI Implementations
6. The Diff Engine (algorithm + rendering)
7. Anti-Patterns (each = a bug that already shipped)
8. Build Order (step-by-step, with acceptance checks)
9. Verification Protocol
10. Canonical Frame Index

---

## §1 THE INFORMATION ARCHITECTURE

### 1.1 The lane model

Everything the agent produces flows through exactly one of seven lanes. The UI never decides what something is — the router (§4) classifies events BEFORE they reach the view layer.

| Lane | Content | Default visibility | Example (from frames) |
|---|---|---|---|
| 1. PROSE | Assistant narrative | Fully visible, bright | "Now fps-view.ts — replace the bare-box weapon view model…" |
| 2. DIFF/WRITE | File changes | Fully expanded, dominates | Unified red/green diff panel (ref3/f0125) |
| 3. THINKING | Reasoning tokens | Visible, shaded italic, orange `Thinking:` label | ref3/f0035 |
| 4. TOOL ROWS | One line per tool call | One line + `└ detail` | `← Edit battlefront/src/presentation/fps-view.ts` |
| 5. BASH OUTPUT | Command stdout/stderr | COLLAPSED panel, dim, truncated ~12 lines | ref3/f0005 |
| 6. TOOL ONE-LINERS | Non-file tool invocations | Single dim truncated line | `⚙ omni_vision [file_path=…, mode=api, prompt=…]` |
| 7. PHASE LINES | "about to do X" | Ephemeral — REPLACED by the tool row | `~ Preparing edit...` |

**The law that was violated (forge/f0010):** tool-call ARGUMENTS (file contents, command strings) NEVER render as prose. File content appears only inside diff/code panels. In the current FORGE build, a model writing an HTML file streams the raw CSS/JS into the chat as prose — one token-fragment per line at random horizontal offsets. That single routing bug is responsible for the worst of the visual corruption. Phase 0 kills it.

### 1.2 What a working session looks like temporally

From REF2/REF3 frame sequences:

```
t+0s    User sends message → user block appears immediately (violet left bar).
        If agent busy: block carries QUEUED badge, stacks above composer.
t+0.2s  Thinking block appears, orange "Thinking:" label, shaded italic
        tokens streaming in live.
t+3s    Prose begins streaming below (or interleaved as separate blocks).
t+5s    "~ Preparing edit..." phase line (dim, ephemeral).
t+6s    Phase line REPLACED BY tool row "← Edit path/to/file.ts".
        Diff panel materializes below it, view auto-scrolls through it.
t+8s    Bash panel: "# Verify the fix" / "$ bun run test…" — output
        streams in dim, truncated at ~12 lines with "Click to expand".
t+15s   Turn completes → per-turn footer: "■ Build · DeepSeek V4 Flash
        (New) · 2m 41s". Footer token counter has ticked the whole time.
```

Stability invariant (S3): **once a block completes it never re-renders, moves, or duplicates.** The current FORGE build violates this (same paragraph rendered 3× in the final state).

---

## §2 MEASURED DESIGN TOKENS (the theme)

All values pixel-sampled from reference frames. This is the single source of truth — Phase 1 implements this as code exactly once.

```swift
// TuiTheme.swift — the ONLY place colors/spacing/typography are defined.
// Any color literal anywhere else in the codebase is a defect.

import SwiftUI

enum TuiTheme {
    // MARK: Surfaces (measured: REF2 f0070, REF1 f0013, REF3 f0265)
    static let bg           = Color(red: 0x13/255, green: 0x13/255, blue: 0x13/255) // #131313 transcript + panel interiors
    static let panelBorder  = Color(red: 0x2A/255, green: 0x2A/255, blue: 0x30/255) // #2A2A30 rounded-panel border
    static let gutterBar    = Color(red: 0x3A/255, green: 0x3A/255, blue: 0x42/255) // #3A3A42 thinking gutter

    // MARK: Text
    static let textPrimary  = Color(red: 0xE8/255, green: 0xE8/255, blue: 0xE8/255) // #E8E8E8
    static let textDim      = Color(red: 0x55/255, green: 0x55/255, blue: 0x52/255) // #555552 measured
    static let textFaint    = Color(red: 0x43/255, green: 0x43/255, blue: 0x43/255) // #434343 line-number gutter

    // MARK: Accents
    static let violet       = Color(red: 0x87/255, green: 0x5B/255, blue: 0xF5/255) // #875BF5 measured — user bar, badges, agent glyph, tool names
    static let violetDeep   = Color(red: 0x50/255, green: 0x24/255, blue: 0xBE/255) // #5024BE measured — bar gradient end
    static let orange       = Color(red: 0xE0/255, green: 0x8A/255, blue: 0x3C/255) // rust-orange — Thinking label, prose emphasis, "max" chip ONLY
    static let agentBlue    = Color(red: 0x5B/255, green: 0x9B/255, blue: 0xF5/255) // subagent glyph (Build/Trident_build)

    // MARK: Badges
    static let queuedBg     = Color(red: 0x6E/255, green: 0x64/255, blue: 0x7E/255) // #6E647E measured
    static let queuedText   = Color(red: 0x4E/255, green: 0x2E/255, blue: 0x7E/255) // #4E2E7E measured

    // MARK: Diff rows (measured REF3 f0125)
    static let diffAddBg    = Color(red: 0x1E/255, green: 0x2F/255, blue: 0x37/255) // #1E2F37
    static let diffRemoveBg = Color(red: 0x36/255, green: 0x20/255, blue: 0x2A/255) // #36202A

    // MARK: Semantics
    static let success      = Color(red: 0x4A/255, green: 0xDE/255, blue: 0x80/255) // ✓, LINT_OK, version dot
    static let failure      = Color(red: 0xF8/255, green: 0x71/255, blue: 0x71/255) // FAIL, error:

    // MARK: Syntax highlighting (inside code/diff panels)
    static let synKeyword   = violet
    static let synString    = Color(red: 0xCE/255, green: 0x8A/255, blue: 0x5A/255) // rust
    static let synComment   = Color(red: 0x5E/255, green: 0x8A/255, blue: 0x6A/255) // dim green
    static let synType      = Color(red: 0x6A/255, green: 0xC8/255, blue: 0xD8/255) // cyan
    static let synNumber    = orange
    static let synPlain     = textPrimary

    // MARK: Typography — DENSITY IS THE POINT (reference ≈48 lines/950px)
    static let bodyFont     = Font.system(size: 12, design: .monospaced)
    static let smallFont    = Font.system(size: 10, design: .monospaced)
    static let codeFont     = Font.system(size: 11, design: .monospaced)
    static let lineSpacing: CGFloat  = 3
    static let blockGap:    CGFloat  = 10
    static let panelPad:    CGFloat  = 10
    static let transcriptPad: CGFloat = 12
    static let panelRadius: CGFloat  = 10
    static let barWidth:    CGFloat  = 3
}
```

**Density acceptance check:** on a 390×844 viewport (iPhone 14), at least 40 transcript lines must be visible. The current build shows ~12. If your build shows big airy text, your font sizes are wrong — re-read this table.

---

## §3 THE DATA MODEL

This is the foundation. The current build has no model — stream deltas become views directly (Anti-Pattern AP1). Build this first.

```swift
// ChatModel.swift

import Foundation
import Combine

// MARK: - Parts: one message is an ordered list of typed parts.
// The lane router (§4) appends/mutates these. Views render them 1:1.

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
    var hunks: [DiffHunk]       // see §6
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
```

```swift
// ChatStore.swift — the single mutation point.

@MainActor
final class ChatStore: ObservableObject {
    @Published private(set) var messages: [ChatMessage] = []
    @Published var status = SessionStatus()     // tokens, pct, cost, model, running
    @Published var subagent: SubagentStatus?    // drives the strip (§5.12)

    // Streaming targets — the ids of the parts currently receiving deltas.
    private var activeProse: UUID?
    private var activeThinking: UUID?

    // All mutations go through methods like these (signatures only —
    // the router in §4 calls them):
    func appendUser(_ text: String, queued: Bool) { /* … */ }
    func beginAssistantTurn(agent: String, model: String) { /* … */ }
    func appendProseDelta(_ delta: String) { /* append to activeProse part */ }
    func appendThinkingDelta(_ delta: String) { /* … */ }
    func beginTool(name: String, title: String) -> UUID { /* … */ }
    func setToolDetail(id: UUID, _ detail: String) { /* … */ }
    func completeTool(id: UUID, ok: Bool, payload: String?) { /* … */ }
    func setPhase(_ text: String) { /* creates/replaces the ONE phase part */ }
    func clearPhase() { /* … */ }
    func beginBash(title: String, command: String) -> UUID { /* … */ }
    func appendBashOutput(id: UUID, _ delta: String) { /* … */ }
    func attachDiff(path: String, hunks: [DiffHunk]) { /* … */ }
    func attachWrite(path: String, bytes: Int, content: String) { /* … */ }
    func completeTurn() { /* stamps completedAt, appends turnFooter part */ }
}

struct SessionStatus: Equatable {
    var tokens: Int = 0
    var contextPct: Int = 0
    var costUSD: Double = 0
    var modelDisplayName: String = ""   // ← from engine config. Today: "kimi K3".
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
```

**Model rules (non-negotiable):**
1. Views NEVER create parts. Views render `store.messages`. All mutation flows engine → router → store.
2. Text deltas MUTATE an existing part's `text` (`messages[i].parts[j].text += delta`). They never create new parts per delta. (This was the word-per-line bug.)
3. Every part has a stable `UUID` created once. SwiftUI's `LazyVStack` diffs by identity — stable ids are what make completed blocks never re-render.
4. `Equatable` everywhere so SwiftUI skips unchanged rows.

---

## §4 THE LANE ROUTER

The engine emits a stream of raw events (SSE deltas, tool-call JSON, status ticks). The router classifies each into a lane and calls the right store method. **File content can only ever reach `attachWrite`/`attachDiff` — there is no code path from tool arguments to prose.**

```swift
// LaneRouter.swift

struct LaneRouter {
    let store: ChatStore

    /// The ONLY entry point for engine events.
    func handle(_ event: EngineEvent) {
        switch event {

        case .userMessage(let text):
            store.appendUser(text, queued: store.status.isRunning)

        case .turnBegin(let agent, let model):
            store.beginAssistantTurn(agent: agent, model: model)

        case .reasoningDelta(let delta):          // lane 3
            store.appendThinkingDelta(delta)

        case .textDelta(let delta):               // lane 1
            store.appendProseDelta(delta)

        case .toolPhase(let toolName):            // lane 7
            store.setPhase("~ Preparing \(toolName.lowercased())...")

        case .toolBegin(let name, let title):     // lane 4
            store.clearPhase()
            _ = store.beginTool(name: name, title: title)

        case .toolArgs(let id, let name, let args):
            // CRITICAL ROUTING RULE:
            // args for write/edit go to payload — NEVER to prose.
            switch name {
            case "write":
                store.attachWrite(path: args.path,
                                  bytes: args.content.utf8.count,
                                  content: args.content)
            case "edit":
                store.attachDiff(path: args.path,
                                 hunks: DiffEngine.hunks(old: args.oldString,
                                                         new: args.newString,
                                                         context: args.fileContext))
            default:
                store.setToolPayload(id: id, payload: args.rawJSON)
            }

        case .toolEnd(let id, let ok, let detail):
            store.completeTool(id: id, ok: ok, payload: nil)
            if let detail { store.setToolDetail(id: id, detail) }

        case .bashBegin(let title, let command):  // lane 5
            _ = store.beginBash(title: title, command: command)

        case .bashOutput(let id, let delta):
            store.appendBashOutput(id: id, delta)

        case .nonFileTool(let name, let summary): // lane 6
            store.appendOneLiner("⚙ \(name) [\(summary)]")

        case .status(let s):                      // footer/header ticks
            store.status = s

        case .subagentStatus(let s):              // strip ticks
            store.subagent = s

        case .turnEnd:
            store.completeTurn()
        }
    }
}
```

**Router invariants (assert these in tests):**
- `toolArgs` for `write`/`edit` NEVER calls `appendProseDelta`. (forge/f0010 regression test.)
- `toolPhase` is always followed by `clearPhase` before the tool row appears — exactly one phase line exists at any time.
- A completed turn's parts are never mutated after `turnEnd`.

---

## §5 COMPONENT SPECIFICATIONS WITH FULL IMPLEMENTATIONS

### 5.1 TranscriptView — the scroll container

```swift
// TranscriptView.swift

struct TranscriptView: View {
    @ObservedObject var store: ChatStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: TuiTheme.blockGap) {
                    ForEach(store.messages) { message in
                        MessageView(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, TuiTheme.transcriptPad)
                .padding(.vertical, TuiTheme.blockGap)
            }
            .background(TuiTheme.bg)
            // Auto-scroll on new content. Throttled — NOT on every delta.
            .onChange(of: store.messages.last?.parts.count) { _ in
                scrollToEnd(proxy)
            }
            .onReceive(store.statusTick.throttled) { _ in   // 15 fps max
                scrollToEnd(proxy)
            }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        guard let last = store.messages.last else { return }
        withAnimation(.linear(duration: 0.08)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}
```

**Rules:** `ScrollViewReader` + `scrollTo`. NEVER the flipped-`scaleEffect` trick (it produced mirrored text — AP2). The terminal view is NOT in this hierarchy in chat mode (AP3) — it lives behind a header `terminal` icon as a `.sheet`.

### 5.2 MessageView — role dispatch

```swift
struct MessageView: View {
    let message: ChatMessage

    var body: some View {
        switch message.role {
        case .user(let queued):
            UserMessageView(text: message.parts.first?.text ?? "", queued: queued)
        case .assistant:
            VStack(alignment: .leading, spacing: TuiTheme.blockGap) {
                ForEach(message.parts) { part in
                    PartView(part: part)
                }
            }
        }
    }
}

struct PartView: View {
    let part: Part
    var body: some View {
        switch part.kind {
        case .prose:        MarkdownText(part.text)
        case .thinking:     ThinkingView(text: part.text)
        case .tool:         ToolRowView(state: part.tool!)
        case .bash:         BashPanelView(state: part.bash!)
        case .toolOneLiner: Text(part.text).font(TuiTheme.smallFont)
                                .foregroundStyle(TuiTheme.textDim).lineLimit(2)
        case .phase:        Text(part.text).font(TuiTheme.smallFont.italic())
                                .foregroundStyle(TuiTheme.textDim)
        case .diff:         DiffView(state: part.diff!)
        case .write:        WritePanelView(state: part.write!)
        case .turnFooter:   AgentTurnFooter(text: part.text)
        case .statusBanner: StatusBannerView(text: part.text)
        }
    }
}
```

### 5.3 ThinkingView (ref3/f0035 — orange label + shaded italic body)

```swift
struct ThinkingView: View {
    let text: String
    @State private var collapsed = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(TuiTheme.gutterBar)
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Thinking:")
                    .font(TuiTheme.bodyFont.bold())
                    .foregroundStyle(TuiTheme.orange)   // ← ORANGE label. Measured.
                if !collapsed {
                    Text(text)
                        .font(TuiTheme.bodyFont.italic())
                        .foregroundStyle(TuiTheme.textDim)
                        .lineSpacing(TuiTheme.lineSpacing)
                }
            }
        }
        // Long completed blocks MAY collapse on tap; expanded while streaming.
        .onTapGesture { withAnimation { collapsed.toggle() } }
    }
}
```

### 5.4 MarkdownText — prose with opencode's emphasis rules

opencode prose is NOT flat white. Bold segments render **bold orange**; inline code renders **rust-tinted**; success phrases (`GREEN`, `passed`) render green-bold. Implement as an AttributedString pass:

```swift
// MarkdownText.swift

struct MarkdownText: View {
    let raw: String

    var body: some View {
        // Block-level split: tables and code fences become their own
        // views; everything else is inline-attributed text.
        VStack(alignment: .leading, spacing: TuiTheme.blockGap) {
            ForEach(MarkdownBlocks.split(raw)) { block in
                switch block {
                case .text(let s):
                    Text(InlineStyler.style(s))
                        .font(TuiTheme.bodyFont)
                        .lineSpacing(TuiTheme.lineSpacing)
                case .code(let lang, let code):
                    CodeBlockView(code: code, language: lang)
                case .table(let header, let rows):
                    TableView(header: header, rows: rows)
                }
            }
        }
    }
}

enum InlineStyler {
    /// **bold** → bold orange. `code` → rust on 12% rust pill.
    /// *italic* → italic. Everything else → textPrimary.
    static func style(_ s: String) -> AttributedString {
        var out = AttributedString()
        var rest = s[...]
        while !rest.isEmpty {
            if let m = rest.firstMatch(of: /\*\*(.+?)\*\*/) {
                out += plain(rest[..<m.range.lowerBound])
                var b = AttributedString(String(m.1))
                b.font = TuiTheme.bodyFont.bold()
                b.foregroundColor = TuiTheme.orange      // ← measured behavior
                out += b
                rest = rest[m.range.upperBound...]
            } else if let m = rest.firstMatch(of: /`([^`]+)`/) {
                out += plain(rest[..<m.range.lowerBound])
                var c = AttributedString(String(m.1))
                c.font = TuiTheme.codeFont
                c.foregroundColor = TuiTheme.synString
                c.backgroundColor = TuiTheme.synString.opacity(0.12)
                out += c
                rest = rest[m.range.upperBound...]
            } else {
                out += plain(rest); rest = rest[rest.endIndex...]
            }
        }
        return out

        func plain(_ s: Substring) -> AttributedString {
            var a = AttributedString(String(s))
            a.foregroundColor = TuiTheme.textPrimary
            return a
        }
    }
}
```

`TableView`: real `Grid` with 1px `panelBorder` separators, bold header row, cell padding 6/8, horizontal `ScrollView` if content exceeds width. Reference: ref1/f0001 (Before/After table).

### 5.5 UserMessageView + QUEUED badge (ref2/f0010)

```swift
struct UserMessageView: View {
    let text: String
    let queued: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(LinearGradient(colors: [TuiTheme.violet, TuiTheme.violetDeep],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: TuiTheme.barWidth)
            VStack(alignment: .leading, spacing: 4) {
                Text(text)
                    .font(TuiTheme.bodyFont)
                    .foregroundStyle(TuiTheme.textPrimary)
                if queued {
                    Text("QUEUED")
                        .font(TuiTheme.smallFont.bold())
                        .foregroundStyle(TuiTheme.queuedText)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(TuiTheme.queuedBg, in: RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}
```

### 5.6 ToolRowView + PhaseLineView (ref2/f0010, ref3/f0125 header)

```swift
struct ToolRowView: View {
    let state: ToolState
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(glyph).foregroundStyle(glyphColor)
                Text(state.name).foregroundStyle(TuiTheme.violet).bold()
                Text(state.title).foregroundStyle(TuiTheme.textPrimary)
                Spacer()
            }
            .font(TuiTheme.bodyFont)
            if let detail = state.detail {
                Text("└ \(detail)")
                    .font(TuiTheme.smallFont)
                    .foregroundStyle(TuiTheme.textDim)
                    .padding(.leading, 20)
            }
            if state.expanded, let payload = state.payload {
                CodeBlockView(code: payload, language: nil)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { /* toggle expanded via store */ }
    }

    private var glyph: String {
        switch state.status {
        case .preparing, .running: return "⠋"   // animate: cycle ⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏ via Timer
        case .done(let ok):        return ok ? "✓" : "✗"
        }
    }
    private var glyphColor: Color {
        switch state.status {
        case .preparing, .running: return TuiTheme.violet
        case .done(let ok):        return ok ? TuiTheme.success : TuiTheme.failure
        }
    }
}
```

Phase lines (`~ Preparing edit...`) are plain dim italic small text. The store guarantees at most one exists; `toolBegin` replaces it (§4).

### 5.7 BashPanelView (ref3/f0005, ref2/f0210)

```swift
struct BashPanelView: View {
    let state: BashState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("# \(state.title)")
                .font(TuiTheme.smallFont)
                .foregroundStyle(TuiTheme.textDim)
            HStack(alignment: .top, spacing: 4) {
                Text("$").foregroundStyle(TuiTheme.textDim)
                Text(state.command).foregroundStyle(TuiTheme.textPrimary)
            }
            .font(TuiTheme.bodyFont)

            if state.output.isEmpty {
                Text("(no output)").font(TuiTheme.smallFont.italic())
                    .foregroundStyle(TuiTheme.textDim)
            } else {
                Text(OutputStyler.style(displayOutput))
                    .font(TuiTheme.codeFont)
                    .lineSpacing(2)
                if isTruncated && !state.expanded {
                    Text("Click to expand")
                        .font(TuiTheme.smallFont)
                        .foregroundStyle(TuiTheme.textDim)
                        .frame(maxWidth: .infinity)
                        .onTapGesture { /* store.expand */ }
                }
            }
        }
        .padding(TuiTheme.panelPad)
        .background(TuiTheme.bg)                       // interior = bg
        .overlay(RoundedRectangle(cornerRadius: TuiTheme.panelRadius)
                    .stroke(TuiTheme.panelBorder, lineWidth: 1))  // BORDER defines the panel
        .clipShape(RoundedRectangle(cornerRadius: TuiTheme.panelRadius))
    }

    private var lines: [String] { state.output.components(separatedBy: "\n") }
    private var isTruncated: Bool { lines.count > BashState.collapsedLineLimit }
    private var displayOutput: String {
        (state.expanded || !isTruncated) ? state.output
            : lines.prefix(BashState.collapsedLineLimit).joined(separator: "\n") + "\n…"
    }
}

enum OutputStyler {
    /// Semantic recoloring of raw stdout:
    /// FAIL / error: → failure red.  ✓ / passed / LINT_OK / DONE → success green.
    /// "quoted strings" → synString. Numbers → synNumber. Rest → textDim.
    static func style(_ s: String) -> AttributedString { /* regex passes */ }
}
```

### 5.8 WritePanelView (ref3/f0265 — syntax-highlighted payload panel)

```swift
struct WritePanelView: View {
    let state: WriteState
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: { /* toggle expanded via store */ }) {
                HStack {
                    Text(state.expanded ? "▾" : "▸")
                    Text(state.path).foregroundStyle(TuiTheme.textPrimary)
                    Text("— \(state.bytes) bytes").foregroundStyle(TuiTheme.textDim)
                }
                .font(TuiTheme.bodyFont)
            }
            if state.expanded {
                CodeBlockView(code: state.content,
                              language: Language.from(pathExtension: state.path))
            }
        }
    }
}
```

### 5.9 CodeBlockView — the syntax panel

```swift
struct CodeBlockView: View {
    let code: String
    let language: Language?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(SyntaxHighlighter.highlight(code, language))
                .font(TuiTheme.codeFont)
                .lineSpacing(2)
                .fixedSize(horizontal: true, vertical: false)  // ← NEVER wrap code
                .padding(TuiTheme.panelPad)
        }
        .background(TuiTheme.bg)
        .overlay(RoundedRectangle(cornerRadius: TuiTheme.panelRadius)
                    .stroke(TuiTheme.panelBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: TuiTheme.panelRadius))
    }
}

enum SyntaxHighlighter {
    /// Regex tokenizer is sufficient (keywords/strings/comments/numbers/types).
    /// js/ts/swift/python/html/css share the same pass set.
    static func highlight(_ code: String, _ lang: Language?) -> AttributedString {
        // Order matters: comments first (so // inside strings doesn't win),
        // then strings, then keywords, then numbers, then types.
        // Each pass colors matches with the §2 syn* tokens.
    }
}
```

### 5.10 ComposerView + selector chips (ref2/f0010)

```swift
struct ComposerView: View {
    @Binding var draft: String
    let isRunning: Bool
    let onSend: (String) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom) {
                TextField("Message", text: $draft, axis: .vertical)
                    .font(TuiTheme.bodyFont)
                    .foregroundStyle(TuiTheme.textPrimary)
                    .lineLimit(1...6)
                    .focused($focused)
                Button(action: { onSend(draft); draft = "" }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(TuiTheme.violet)
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(10)
            .background(TuiTheme.bg)
            .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(focused ? TuiTheme.violet : TuiTheme.panelBorder,
                                lineWidth: 1))

            // Selector chips line — model name from SessionConfig, NEVER hardcoded.
            HStack(spacing: 6) {
                Text(agentName).foregroundStyle(TuiTheme.violet)
                Text("·").foregroundStyle(TuiTheme.textDim)
                Text(modelName).foregroundStyle(TuiTheme.textPrimary)   // "kimi K3"
                Spacer()
                Text("OpenCode Go").foregroundStyle(TuiTheme.textDim)
                Text("·").foregroundStyle(TuiTheme.textDim)
                Text("max").foregroundStyle(TuiTheme.orange)            // the ONLY orange chip
            }
            .font(TuiTheme.smallFont)
        }
    }
}
```

### 5.11 StatusFooterView — with the ANIMATED equalizer bars

REF3 shows the footer's left cluster is an animated equalizer (bar heights cycle while the agent works). Reproduce it:

```swift
struct StatusFooterView: View {
    let status: SessionStatus
    let onInterrupt: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if status.isRunning {
                EqualizerBars()                              // animated
                Button("esc interrupt", action: onInterrupt)
                    .font(TuiTheme.smallFont)
                    .foregroundStyle(TuiTheme.textDim)
            }
            Spacer()
            Text("\(status.tokens.kFormatted) (\(status.contextPct)%) · \(status.costUSD.usdFormatted)")
                .foregroundStyle(TuiTheme.textPrimary)
            Text("·").foregroundStyle(TuiTheme.textDim)
            Text("\(status.workspace):\(status.branch)")
                .foregroundStyle(TuiTheme.textDim)
            Text("·").foregroundStyle(TuiTheme.textDim)
            HStack(spacing: 3) {
                Circle().fill(TuiTheme.success).frame(width: 5, height: 5)
                Text(status.version).foregroundStyle(TuiTheme.textDim)
            }
        }
        .font(TuiTheme.smallFont)
        .padding(.horizontal, TuiTheme.transcriptPad)
        .frame(height: 30)
        .background(TuiTheme.bg)
    }
}

struct EqualizerBars: View {
    // 5 bars, heights cycle through a fixed pattern while running.
    // Colors: shades of violet/blue (measured from REF3 footer).
    @State private var tick = 0
    private let pattern: [[CGFloat]] = [[4,8,12,8,4],[8,12,8,4,8],[12,8,4,8,12],[8,4,8,12,8]]
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i % 2 == 0 ? TuiTheme.violet : TuiTheme.agentBlue)
                    .frame(width: 3, height: pattern[tick % pattern.count][i])
            }
        }
        .onReceive(Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()) { _ in
            tick += 1
        }
    }
}
```

### 5.12 SubagentStripView (ref2/f0190)

```swift
struct SubagentStripView: View {
    let s: SubagentStatus
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Rectangle().fill(TuiTheme.agentBlue).frame(width: 6, height: 6)
                Text("\(s.name) (\(s.step) of \(s.totalSteps))")
                    .foregroundStyle(TuiTheme.textPrimary)
                Text("\(s.tokens.kFormatted) (\(s.pct)%) · \(s.costUSD.usdFormatted)")
                    .foregroundStyle(TuiTheme.textDim)
            }
            Spacer()
        }
        .font(TuiTheme.smallFont)
        .padding(.horizontal, TuiTheme.transcriptPad)
        .frame(height: 26)
        .background(TuiTheme.bg)
        .overlay(alignment: .top) { Divider().overlay(TuiTheme.panelBorder) }
    }
}
```

### 5.13 AgentTurnFooter + StatusBannerView

```swift
struct AgentTurnFooter: View {          // "■ Build · DeepSeek V4 Flash (New) · 2m 41s"
    let text: String                    // precomposed by the store
    var body: some View {
        Text(text).font(TuiTheme.smallFont).foregroundStyle(TuiTheme.textDim)
    }
}

struct StatusBannerView: View {         // "✅ DONE — Here's the truth…"
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Text("✅")
            Text(text).font(TuiTheme.bodyFont.bold())
                .foregroundStyle(TuiTheme.textPrimary)
        }
    }
}
```

### 5.14 ContextDrawerView (sidebar → drawer)

From the header ☰. Content mirrors the reference sidebar exactly:

```swift
struct ContextDrawerView: View {
    let status: SessionStatus
    let mcpServers: [(name: String, connected: Bool)]
    let lspStatus: String                       // "LSPs are disabled"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(projectTitle).font(TuiTheme.bodyFont.bold())
                .foregroundStyle(TuiTheme.textPrimary)

            section("Context") {
                VStack(alignment: .leading, spacing: 2) {
                    row("\(status.tokens) tokens")
                    row("\(status.contextPct)% used")
                    row("\(status.costUSD.usdFormatted) spent")
                }
            }
            section("MCP") {
                ForEach(mcpServers, id: \.name) { s in
                    HStack {
                        Text(s.name).foregroundStyle(TuiTheme.textDim)
                        Spacer()
                        Text(s.connected ? "Connected" : "—")
                            .foregroundStyle(s.connected ? TuiTheme.success
                                                         : TuiTheme.textDim)
                    }
                }
            }
            section("LSP") { row(lspStatus) }
            Spacer()
        }
        .font(TuiTheme.smallFont)
        .padding(16)
        .frame(width: 300)
        .background(TuiTheme.bg)
    }
    // section/row helpers …
}
```

Absent data renders `—`. NEVER fabricate MCP/LSP entries.

### 5.15 Screen assembly (the layout)

```
┌──────────────────────────────┐
│ HeaderBar (44pt)             │  ☰  FORGE-Demo · kimi K3     3.5K (0%) · $0.00
├──────────────────────────────┤
│                              │
│ TranscriptView (scrolls)     │
│                              │
├──────────────────────────────┤
│ SubagentStripView (26pt,     │  only while a task tool runs
│  conditional)                │
├──────────────────────────────┤
│ ComposerView + chips         │
├──────────────────────────────┤
│ StatusFooterView (30pt)      │
└──────────────────────────────┘
```

```swift
struct SessionScreen: View {
    @StateObject var store: ChatStore
    @State private var showDrawer = false
    @State private var showTerminal = false
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(status: store.status,
                      onMenu: { showDrawer = true },
                      onTerminal: { showTerminal = true })
            TranscriptView(store: store)
            if let sub = store.subagent { SubagentStripView(s: sub) }
            ComposerView(draft: $draft, isRunning: store.status.isRunning,
                         onSend: { store.sendUser($0) })
            StatusFooterView(status: store.status,
                             onInterrupt: { store.interrupt() })
        }
        .background(TuiTheme.bg.ignoresSafeArea())
        .sheet(isPresented: $showDrawer) { ContextDrawerView(...) }
        .sheet(isPresented: $showTerminal) { TerminalSheet() }   // raw terminal lives HERE
    }
}
```

Header is ONE 44pt row. The giant `FORGE` nav title, back chevron, and the duplicate `# FORGE-Demo … 3.5K 0% ($0.00)` second row are DELETED. Brand lives on the home screen.

---

## §6 THE DIFF ENGINE

The edit tool gives you `oldString`/`newString` (+ file context for line numbers). Produce unified rows:

```swift
// DiffEngine.swift

struct DiffRow: Equatable {
    enum Kind: Equatable { case context, removed, added }
    var kind: Kind
    var oldLineNo: Int?        // shown on context + removed rows
    var newLineNo: Int?        // shown on context + added rows
    var text: String
}

struct DiffHunk: Equatable {
    var rows: [DiffRow]
}

enum DiffEngine {
    /// Line-level LCS diff of old vs new, with 3 lines of context above
    /// and below the change, and correct dual line numbering.
    static func hunks(old: String, new: String,
                      context fileContext: (startLine: Int, lines: [String])?) -> [DiffHunk] {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        let ops = lcsDiff(oldLines, newLines)   // [(kind, oldIdx?, newIdx?, text)]
        // Attach line numbers:
        //   removed rows → oldLineNo only
        //   added rows   → newLineNo only
        //   context rows → both
        // Prepend/append 3 context rows from fileContext when available.
        // Wrap rows longer than the view width are handled by the VIEW
        // (continuation rows, no line number) — see DiffView.
        return [DiffHunk(rows: ops)]
    }
}
```

```swift
// DiffView.swift — THE CENTERPIECE. Reference: ref3/f0125, f0145, f0165.

struct DiffView: View {
    let state: DiffState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: "← Edit <path>"
            HStack(spacing: 6) {
                Text("←").foregroundStyle(TuiTheme.violet)
                Text("Edit").foregroundStyle(TuiTheme.violet).bold()
                Text(state.path).foregroundStyle(TuiTheme.textPrimary)
            }
            .font(TuiTheme.bodyFont)
            .padding(.bottom, 4)

            VStack(spacing: 0) {
                ForEach(state.hunks.indices, id: \.self) { h in
                    ForEach(state.hunks[h].rows.indices, id: \.self) { r in
                        DiffRowView(row: state.hunks[h].rows[r])
                    }
                }
            }
        }
        .padding(TuiTheme.panelPad)
        .background(TuiTheme.bg)
        .overlay(RoundedRectangle(cornerRadius: TuiTheme.panelRadius)
                    .stroke(TuiTheme.panelBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: TuiTheme.panelRadius))
    }
}

struct DiffRowView: View {
    let row: DiffRow

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // Gutter: the PAIRED line number (old for −, new for +, both for ctx)
            Text(gutterText)
                .font(TuiTheme.codeFont)
                .foregroundStyle(TuiTheme.textFaint)
                .frame(width: 34, alignment: .trailing)
            Text(marker)
                .font(TuiTheme.codeFont)
                .foregroundStyle(markerColor)
            // Code with syntax highlighting; wraps → continuation has no gutter
            Text(SyntaxHighlighter.highlight(row.text, .from(path: rowPath)))
                .font(TuiTheme.codeFont)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
        .background(rowBackground)   // FULL-WIDTH tint, incl. behind the gutter
    }

    private var gutterText: String {
        switch row.kind {
        case .removed: return row.oldLineNo.map(String.init) ?? ""
        case .added:   return row.newLineNo.map(String.init) ?? ""
        case .context: return row.newLineNo.map(String.init) ?? ""
        }
    }
    private var marker: String {
        switch row.kind { case .removed: return "-"; case .added: return "+"; case .context: return " " }
    }
    private var markerColor: Color {
        switch row.kind { case .removed: return TuiTheme.failure; case .added: return TuiTheme.success; case .context: return .clear }
    }
    private var rowBackground: Color {
        switch row.kind {
        case .removed: return TuiTheme.diffRemoveBg      // #36202A measured
        case .added:   return TuiTheme.diffAddBg         // #1E2F37 measured
        case .context: return .clear
        }
    }
}
```

**Diff details observed in frames that you MUST reproduce:**
- Added comment lines (`// P4-POL-2: the root sits ABOVE the eye…`) render inside green rows with dim-green comment coloring — tint and syntax coexist.
- Interleaved bands keep logical order: a `309 +` green band sits directly above the `307 -` red band it replaced (ref3/f0145).
- Row tints span the FULL width of the panel, including behind the line-number gutter.
- Context rows show ~3 lines above/below the change, not the whole file.

---

## §7 ANTI-PATTERNS — each of these ALREADY shipped as a bug

### AP1 — Per-delta views (the word-per-line bug)
**What shipped:** every SSE delta became its own `Text` in a `VStack`. Result (forge/f0010, f0045): `it / with / no / dependencies / .` — one fragment per line at random x-offsets, mid-token wraps, paragraph duplicated 3×.
```swift
// WRONG — never do this:
ForEach(deltas, id: \.self) { d in Text(d) }

// RIGHT — mutate one string, render one view:
// store: messages[i].parts[j].text += delta
Text(InlineStyler.style(part.text))
```

### AP2 — Flipped ScrollView (the mirrored text bug)
**What shipped:** `scaleEffect(x: 1, y: -1)` on the scroll view for bottom-pinning, without counter-flipping content. Result: upside-down mirrored text bleeding under the chat (`chuOL any LUOL PLUCKS`).
```swift
// WRONG:
ScrollView { … }.scaleEffect(y: -1)

// RIGHT: ScrollViewReader + scrollTo(last.id) (§5.1)
```

### AP3 — Dual render path (the compositing bug)
**What shipped:** chat layer rendered ON TOP of the terminal layer; terminal hidden with opacity/frame tricks. `opacity(0)` still composites; `styledGEAT` = two layers on the same rect.
```swift
// WRONG:
ZStack { TerminalView().opacity(0); ChatView() }

// RIGHT: the terminal is NOT IN THE HIERARCHY in chat mode.
// It lives in a .sheet (§5.15).
```

### AP4 — Tool arguments routed to prose (the worst bug)
**What shipped:** the file content being written streamed into the chat as prose. Raw CSS/JS as chat text (forge/f0010).
**Rule:** `toolArgs` for `write`/`edit` have exactly one destination — `attachWrite`/`attachDiff`. There is no code path from args to prose (§4 invariant).

### AP5 — Hardcoded model/provider strings
**What shipped:** header + footer say `deepseek-v4-flash-free`. The model is now kimi K3. Both are stale.
```swift
// WRONG: Text("deepseek-v4-flash-free")
// RIGHT:  Text(store.status.modelDisplayName)   // from engine config
```
Acceptance: `grep -ri "deepseek" iOS/FORGE/Presentation/` returns 0.

### AP6 — Wrapping code
**What shipped:** code/content wraps mid-token (`margi` / `n-top`).
```swift
// RIGHT: horizontal ScrollView + .fixedSize(horizontal: true, vertical: false)
```
Diff rows are the ONLY exception — they wrap by design, onto un-numbered continuation rows.

### AP7 — Orange identity in the transcript
**What shipped:** orange accents on tool rows, status lines, footer pipes. In opencode, orange appears in exactly three places: the `Thinking:` label, prose emphasis, and the `max` chip. Transcript accent is VIOLET. Diff semantics are red/green. Orange FORGE branding stays on the home screen, icon, and CTAs only.

### AP8 — Guessing colors
Every color comes from `TuiTheme` (§2). A color literal outside that file is a review blocker.

### AP9 — @State for streamed text inside row views
`LazyVStack` reuses rows; `@State` in a row view loses/mixes streamed text. Streamed text lives in the STORE (§3), never in view state.

### AP10 — Big airy type
~30pt body text = 12 lines/screen = looks like a children's book. Reference density is ~48 lines/950px. Use §2 typography exactly; verify with the §1.2 density check.

### AP11 — Fabricated chrome data
No MCP servers connected? Render the MCP section with `—`. Never invent entries, never hide the section. The reference shows `LSPs are disabled` — honest emptiness is part of the look.

### AP12 — Rebuilding the whole list per delta
Re-rendering 500 blocks per token stalls the main thread (the current build's pixel-frozen end-state). Stable UUIDs + `Equatable` + in-place string mutation make SwiftUI skip completed rows. Verify: smooth scroll at 500+ blocks.

---

## §8 BUILD ORDER — step by step

Files live under `iOS/FORGE/Presentation/Shared/` (renderers) and `iOS/FORGE/Bridge/` (router/store hooks). After each phase: xcodegen → build → simulator screenshot → compare to the cited frame.

### Phase 0 — Pipeline (foundation; nothing visual ships without it)
1. `ChatModel.swift` — §3 verbatim.
2. `ChatStore.swift` — §3, all mutation methods.
3. `LaneRouter.swift` — §4. Wire the engine bridge to emit `EngineEvent`s; delete every direct terminal/chat write path for chat content.
4. Remove the terminal from the chat hierarchy; add `TerminalSheet`.
5. Remove any flipped-transform scroll hack; add `ScrollViewReader`.
**Acceptance:** scripted session with a 200-line `write` → zero file-content tokens in any prose part (assert in code); no mirrored text; one text layer per block.

### Phase 1 — Theme + chrome skeleton
1. `TuiTheme.swift` — §2 verbatim.
2. `HeaderBar` (44pt, one row), `StatusFooterView` + `EqualizerBars`, screen assembly §5.15. Delete the giant FORGE title row and the duplicate status row on this screen.
3. Model/workspace/branch/version all read from `SessionStatus`.
**Acceptance:** ≥40 transcript lines on 390×844; footer shows live token ticks; no `deepseek` strings (AP5 grep).

### Phase 2 — Text renderers
1. `MarkdownText` + `InlineStyler` + `MarkdownBlocks` splitter (§5.4).
2. `TableView` (bordered grid — ref1/f0001).
3. `CodeBlockView` + `SyntaxHighlighter` (§5.9, AP6).
4. `ThinkingView` (§5.3 — ORANGE label, shaded italic body).
**Acceptance:** fixture message with bold/inline-code/table/code-fence/thinking renders as ref1/f0001 + ref3/f0035. Vision score ≥8/10.

### Phase 3 — The working surface
1. `ToolRowView` + spinner animation + `└ detail` + expand (§5.6).
2. Phase lines (§4 semantics: exactly one, replaced by tool row).
3. `DiffEngine` + `DiffView` (§6 — THE CENTERPIECE; ref3/f0125 is your target).
4. `WritePanelView` (§5.8 — ref3/f0265).
5. `BashPanelView` + `OutputStyler` (§5.7 — ref3/f0005).
6. Tool one-liners (lane 6).
**Acceptance frame-pairs (each ≥8/10):** forge-diff vs ref3/f0125; forge-write vs ref3/f0265; forge-bash vs ref3/f0005.

### Phase 4 — Conversation chrome
1. `UserMessageView` + QUEUED (§5.5). Queued messages stack above the composer.
2. `ComposerView` + chips (§5.10). Send-while-running enqueues.
3. `AgentTurnFooter`, `StatusBannerView` (§5.13).
4. `SubagentStripView` (§5.12) with live-ticking counters.
5. `ContextDrawerView` (§5.14).
6. Interrupt: footer stop while running → engine interrupt.
**Acceptance:** forge-composer vs ref2/f0010 (composer, QUEUED badge, chips, footer).

### Phase 5 — Identity + performance
1. Orange purge: transcript accents violet; orange only in Thinking label, prose emphasis, `max` chip.
2. Performance: 500-block session scrolls at 60fps; no pixel-freeze (AP12).
3. Full pass against §7 anti-pattern checklist — grep for each.

---

## §9 VERIFICATION PROTOCOL (per phase, mandatory)

1. **Build:** `xcodebuild -scheme FORGE -sdk iphonesimulator -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO clean build` → success.
2. **Scripted session** (fixtures allowed, labeled as fixtures) exercising: thinking stream, prose (bold + inline code + table), a new-file write, an edit diff, a bash command with >12 lines output, a non-file tool one-liner, a queued user message mid-run, a subagent strip.
3. **Screenshots** at multiple timestamps; compare against the cited frames.
4. **Frame-pair sign-offs (each ≥8/10):**
   - forge-diff vs `ref3/f0125.png` (unified edit diff)
   - forge-write vs `ref3/f0265.png` (write code panel)
   - forge-bash vs `ref3/f0005.png` (collapsed bash panel + tinted output)
   - forge-thinking vs `ref3/f0035.png` (orange label + shaded italic)
   - forge-composer vs `ref2/f0010.png` (composer + QUEUED + chips + footer)
   - forge-markdown vs `ref1/f0001.png` (table + inline code + sidebar-as-drawer)
5. **Mechanical invariants (CI-checkable):**
   - `grep -ri "deepseek" iOS/FORGE/Presentation` → 0 matches
   - `grep -rn "scaleEffect" iOS/FORGE/Presentation` → 0 matches
   - `grep -rn "opacity(0)" iOS/FORGE/Presentation` → 0 matches
   - `grep -rn "Color(red:" iOS/FORGE/Presentation --include="*.swift" | grep -v TuiTheme` → 0 matches
   - Scripted write: zero file-content tokens in prose parts (assert)
   - ≥40 lines visible on 390×844 (screenshot line count)
6. **Demo video** per phase → `evidence/video/forge-tui-p<phase>.mp4`.

**Definition of done:** all six frame-pairs pass in ONE build; all mechanical invariants green; a human flipping between forge and reference frames cannot tell which app a frame came from without reading the content.

---

## §10 CANONICAL FRAME INDEX (`evidence/reference-frames/`)

| Frame | What it proves |
|---|---|
| `ref3/f0125.png`, `ref3/f0145.png`, `ref3/f0165.png` | **Unified edit diff** — paired line numbers, `#36202A`/`#1E2F37` rows, wrap-continuation rows, interleaved bands, syntax in tints |
| `ref3/f0035.png`, `ref3/f0085.png` | Thinking: **bold orange label** + shaded dim italic body, long-form reasoning |
| `ref3/f0265.png`, `ref3/f0273.png` | Write tool = syntax-highlighted code panel + stdout lines |
| `ref3/f0005.png`, `ref3/f0001.png` | Bash panel: `# title`, `$ cmd`, JSON-tinted output, `Click to expand`, green status, per-turn footer |
| `ref3/f0225.png` | Tool one-liner, orange prose emphasis, rust inline code |
| `ref2/f0010.png` | Composer, QUEUED badges, chips (`max` orange), footer, sidebar |
| `ref2/f0070.png`, `ref2/f0090.png` | Side-by-side diff (landscape/iPad variant) |
| `ref2/f0190.png` | Subagent strip `(41 of 41) 276.6K (28%) · $0.09` |
| `ref1/f0001.png`, `ref1/f0007.png` | Markdown table, ✅ banner, tool one-liners, sidebar (Context/MCP/LSP) |
| `forge/f0010.png` | THE smoking gun: file content streaming as prose at random offsets |
| `forge/f0045.png` | Frozen corrupted end-state: duplication ×3, mirrored bleed, overlap |

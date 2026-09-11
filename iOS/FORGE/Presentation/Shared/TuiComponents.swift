import SwiftUI

// TuiComponents.swift — all opencode-TUI component views (spec §5).
//
// Every color/typography/spacing value comes from `TuiTheme` — there are NO
// color literals in this file (AP8). Orange appears ONLY in the Thinking
// label, prose bold emphasis, and the "max" chip (AP7). Transcript accent is
// violet. Code never wraps (AP6). Body is 12pt monospaced (AP10).

// MARK: - Language detection

enum Language: String {
    case js, ts, html, css, swift, python, json, bash, unknown

    static func from(pathExtension: String) -> Language {
        switch pathExtension.lowercased() {
        case "js", "mjs", "cjs", "jsx":   return .js
        case "ts", "tsx":                 return .ts
        case "html", "htm":               return .html
        case "css", "scss":               return .css
        case "swift":                     return .swift
        case "py", "python":              return .python
        case "json":                      return .json
        case "sh", "bash", "zsh":         return .bash
        default:                          return .unknown
        }
    }
}

// MARK: - SyntaxHighlighter (regex tokenizer; spec §5.9)

enum SyntaxHighlighter {
    /// Colors comments/strings/keywords/numbers/types across the shared
    /// language pass set. Order matters: comments first (so `//` inside
    /// strings doesn't win), then strings, then keywords, then numbers.
    static func highlight(_ code: String, _ lang: Language?) -> AttributedString {
        guard !code.isEmpty else { return AttributedString() }
        let mutable = NSMutableAttributedString(string: code)
        let full = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.foregroundColor, value: UIColor(TuiTheme.synPlain),
                             range: full)

        func color(_ pattern: String, _ clr: Color) {
            guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return }
            for match in re.matches(in: code, options: [], range: full) {
                mutable.addAttribute(.foregroundColor, value: UIColor(clr),
                                     range: match.range)
            }
        }

        // Line comments (// # <!-- /*) — run first so spans inside strings
        // do not override string coloring for the remainder of the line.
        // NOTE: no `.*` lookahead patterns here — they backtrack catastrophically
        // on large streamed files (the crash). Simple anchored patterns only.
        color("//[^\n]*|/\\*[\\s\\S]*?\\*/|<!--[^>]*-->", TuiTheme.synComment)
        // Strings: "..." '...' `...`
        color("\"(?:\\\\.|[^\"\\\\])*\"|'(?:\\\\.|[^'\\\\])*'|`(?:\\\\.|[^`\\\\])*`", TuiTheme.synString)
        // Keywords (union across the supported language set).
        let keywords = keywordSet(for: lang)
        if !keywords.isEmpty {
            let pattern = "\\b(?:" + keywords.joined(separator: "|") + ")\\b"
            color(pattern, TuiTheme.synKeyword)
        }
        // Numbers.
        color("\\b\\d+(?:\\.\\d+)?\\b", TuiTheme.synNumber)

        return AttributedString(mutable)
    }

    private static func keywordSet(for lang: Language?) -> [String] {
        var kws = ["true", "false", "null", "nil", "undefined", "return", "if", "else",
                   "for", "while", "break", "continue", "new", "this", "self", "super",
                   "import", "export", "from", "default", "await", "async", "function",
                   "const", "let", "var", "class", "struct", "enum", "extension", "guard",
                   "switch", "case", "func", "throw", "throws", "try", "catch", "public",
                   "private", "static", "final"]
        switch lang {
        case .swift:
            kws += ["let", "var", "func", "init", "deinit", "protocol", "some", "any", "@MainActor"]
        case .python:
            kws += ["def", "lambda", "elif", "pass", "with", "as", "yield", "in", "not", "and", "or", "is", "None"]
        default: break
        }
        return kws
    }
}

// MARK: - OutputStyler (semantic recoloring of raw stdout; spec §5.7)

enum OutputStyler {
    static func style(_ s: String) -> AttributedString {
        let mutable = NSMutableAttributedString(string: s)
        let full = NSRange(location: 0, length: mutable.length)
        mutable.addAttribute(.foregroundColor, value: UIColor(TuiTheme.textDim), range: full)
        func color(_ pattern: String, _ clr: Color, options: NSRegularExpression.Options = []) {
            guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            for match in re.matches(in: s, options: [], range: full) {
                mutable.addAttribute(.foregroundColor, value: UIColor(clr), range: match.range)
            }
        }
        color("\\bFAIL|error:|Error|fatal\\b", TuiTheme.failure)
        color("✓|passed|LINT_OK|DONE|success", TuiTheme.success)
        color("\"[^\"]*\"", TuiTheme.synString)
        color("\\b\\d+(?:\\.\\d+)?\\b", TuiTheme.synNumber)
        return AttributedString(mutable)
    }
}

// MARK: - Markdown block splitter (spec §5.4)

enum MarkdownBlock: Identifiable {
    case text(String)
    case code(lang: Language?, code: String)
    case table(header: [String], rows: [[String]])

    var id: String {
        switch self {
        case .text(let s):       return "t:\(s.count):\(s.prefix(12))"
        case .code(let l, let c): return "c:\(l?.rawValue ?? "?"):\(c.count)"
        case .table(let h, _):   return "tb:\(h.count)"
        }
    }
}

enum MarkdownBlocks {
    /// Splits raw markdown into block-level pieces: fenced code blocks, pipe
    /// tables, and runs of inline text.
    static func split(_ raw: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = raw.components(separatedBy: "\n")
        var i = 0
        var textBuffer: [String] = []

        func flushText() {
            guard !textBuffer.isEmpty else { return }
            let joined = textBuffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !joined.isEmpty { blocks.append(.text(joined)) }
            textBuffer = []
        }

        while i < lines.count {
            let line = lines[i]
            // Fenced code block: ```lang ... ```
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                flushText()
                let info = line.trimmingCharacters(in: .whitespaces)
                let langStr = String(info.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let lang = langStr.isEmpty ? nil : Language.from(pathExtension: langStr)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[i])
                    i += 1
                }
                if i < lines.count { i += 1 } // consume closing fence
                blocks.append(.code(lang: lang, code: codeLines.joined(separator: "\n")))
                continue
            }
            // Pipe table: a line containing '|' followed by a separator row.
            if line.contains("|"), i + 1 < lines.count,
               lines[i + 1].contains("-") && lines[i + 1].contains("|") {
                flushText()
                let header = pipeCells(line)
                i += 2 // skip header + separator
                var rows: [[String]] = []
                while i < lines.count && lines[i].contains("|") {
                    rows.append(pipeCells(lines[i]))
                    i += 1
                }
                blocks.append(.table(header: header, rows: rows))
                continue
            }
            textBuffer.append(line)
            i += 1
        }
        flushText()
        return blocks
    }

    private static func pipeCells(_ line: String) -> [String] {
        line.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - InlineStyler (spec §5.4)

enum InlineStyler {
    /// **bold** → bold orange. `code` → rust on 12% rust pill. *italic* → italic.
    /// Everything else → textPrimary.
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
            } else if let m = rest.firstMatch(of: /\*(.+?)\*/) {
                out += plain(rest[..<m.range.lowerBound])
                var it = AttributedString(String(m.1))
                it.font = TuiTheme.bodyFont.italic()
                it.foregroundColor = TuiTheme.emphYellow   // vanilla markdownEmph #e5c07b
                out += it
                rest = rest[m.range.upperBound...]
            } else {
                out += plain(rest)
                rest = rest[rest.endIndex...]
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

// MARK: - MarkdownText (spec §5.4)

struct MarkdownText: View {
    let raw: String

    var body: some View {
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

// MARK: - TableView (bordered grid; ref1/f0001)

struct TableView: View {
    let header: [String]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                            .font(TuiTheme.smallFont.bold())
                            .foregroundStyle(TuiTheme.textPrimary)
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(TuiTheme.smallFont)
                                .foregroundStyle(TuiTheme.textDim)
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Divider().overlay(TuiTheme.panelBorder)
                }
            }
            .overlay(Rectangle().stroke(TuiTheme.panelBorder, lineWidth: 1))
        }
    }
}

// MARK: - CodeBlockView (spec §5.9 — never wraps; AP6)

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
        // Vanilla BlockTool: panel background (#141414) with an INVISIBLE
        // border (borderColor=background) — depth from the elevation ladder,
        // not a stroked box.
        .background(TuiTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: TuiTheme.panelRadius))
    }
}

// MARK: - ThinkingView (vanilla: italic _Thinking:_ label, muted stream)

struct ThinkingView: View {
    let text: String
    @State private var collapsed = false
    @ObservedObject private var prefs = TuiPrefs.shared

    var body: some View {
        if prefs.showThinking {
            // Vanilla ReasoningPart: near-invisible left rail (#1e1e1e),
            // markdown stream in textMuted, the label is italic markdown
            // emphasis (_Thinking:_ in #e5c07b) — inline, not a bold header.
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(TuiTheme.gutterBar)
                    .frame(width: 2)
                VStack(alignment: .leading, spacing: 2) {
                    if collapsed {
                        Text("Thinking:")
                            .font(TuiTheme.bodyFont.italic())
                            .foregroundStyle(TuiTheme.emphYellow)
                    } else {
                        (Text("Thinking: ")
                            .font(TuiTheme.bodyFont.italic())
                            .foregroundStyle(TuiTheme.emphYellow)
                         + Text(text)
                            .font(TuiTheme.bodyFont.italic())
                            .foregroundStyle(TuiTheme.textDim))
                            .lineSpacing(TuiTheme.lineSpacing)
                    }
                }
            }
            // Long completed blocks MAY collapse on tap; expanded while streaming.
            .onTapGesture { withAnimation { collapsed.toggle() } }
        }
    }
}

// MARK: - UserMessageView + QUEUED badge (ref2/f0010)

struct UserMessageView: View {
    let text: String
    let queued: Bool

    var body: some View {
        // Vanilla UserMessage: left `┃` rail in the AGENT color + panel-bg
        // body (#141414) — not a floating bubble.
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(TuiTheme.violet)
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
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TuiTheme.panel)
        }
    }
}

// MARK: - Message dispatch (spec §5.2)

struct MessageView: View {
    let message: ChatMessage
    var isRunning: Bool = false

    var body: some View {
        switch message.role {
        case .user(let queued):
            UserMessageView(text: message.parts.first?.text ?? "", queued: queued)
        case .assistant:
            VStack(alignment: .leading, spacing: TuiTheme.blockGap) {
                ForEach(message.parts) { part in
                    PartView(part: part, isRunning: isRunning)
                }
            }
        }
    }
}

struct PartView: View {
    let part: Part
    var isRunning: Bool = false
    var body: some View {
        switch part.kind {
        case .prose:        MarkdownText(raw: part.text)
        case .thinking:     ThinkingView(text: part.text)
        case .tool:         if let t = part.tool { ToolRowView(state: t) }
        case .bash:         if let b = part.bash { BashPanelView(state: b) }
        case .toolOneLiner: Text(part.text).font(TuiTheme.smallFont)
                                .foregroundStyle(TuiTheme.textDim).lineLimit(2)
        case .phase:        PhaseLineView(text: part.text)
        case .diff:         if let d = part.diff { DiffView(state: d) }
        case .write:        if let w = part.write { WritePanelView(state: w, isStreaming: isRunning) }
        case .turnFooter:   AgentTurnFooter(text: part.text)
        case .statusBanner: StatusBannerView(text: part.text)
        case .error:        Text(part.text).font(TuiTheme.smallFont)
                                .foregroundStyle(TuiTheme.failure)
        }
    }
}

// MARK: - AnimatedSpinner (braille cycle for working/phase indicators)

/// Cycles through braille spinner characters at 10fps. Used for phase lines
/// (working indicator) and tool-row running glyphs.
struct AnimatedSpinner: View {
    @State private var idx = 0
    private let frames = ["⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"]
    var color: Color = TuiTheme.violet

    var body: some View {
        Text(frames[idx % frames.count])
            .foregroundStyle(color)
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                idx += 1
            }
    }
}

// MARK: - PhaseLineView (animated working/preparing indicator)

/// Renders a phase line ("■ working · model" or "~ Preparing write...") with
/// a braille spinner so the user ALWAYS sees activity — even during the
/// 10-25s LLM round-trip before the first token arrives (the "dead screen"
/// bug).
struct PhaseLineView: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            AnimatedSpinner()
            Text(text)
                .font(TuiTheme.smallFont.italic())
                .foregroundStyle(TuiTheme.textDim)
        }
    }
}

// MARK: - ToolRowView (spec §5.6 — vanilla N4 alignment)

/// ONE-LINE tool summary in the VANILLA opencode style: per-tool icon
/// (`$ → ← ✱ ⚙ │`) + args; the whole completed row is textMuted #808080
/// (no colored tool-name, no green ✓ — vanilla renders exactly that).
/// Running = braille spinner in text color. Tap expands the payload (N3).
struct ToolRowView: View {
    let state: ToolState
    @State private var userExpanded = false
    private var showPayload: Bool { userExpanded && state.payload != nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if case .preparing = state.status {
                    Text("~").foregroundStyle(rowColor)
                } else if case .running = state.status {
                    AnimatedSpinner(color: rowColor).font(TuiTheme.bodyFont)
                } else {
                    Text(TuiTheme.toolIcon(state.name)).foregroundStyle(rowColor)
                }
                Text(state.name).foregroundStyle(rowColor)
                Text(state.title).foregroundStyle(rowColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
                if state.payload != nil {
                    Text(userExpanded ? "▾" : "▸")
                        .foregroundStyle(TuiTheme.textDim)
                        .font(TuiTheme.smallFont)
                }
            }
            .font(TuiTheme.bodyFont)
            if showPayload, let payload = state.payload {
                if let detail = state.detail {
                    Text("↳ \(detail)")
                        .font(TuiTheme.smallFont)
                        .foregroundStyle(TuiTheme.textDim)
                        .padding(.leading, 20)
                }
                CodeBlockView(code: payload, language: nil)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { userExpanded.toggle() } }
    }

    /// Vanilla row colors: completed → textMuted; running → text; error → error.
    private var rowColor: Color {
        switch state.status {
        case .preparing, .running: return TuiTheme.textPrimary
        case .done(let ok):        return ok ? TuiTheme.textDim : TuiTheme.failure
        }
    }
}

// MARK: - BashPanelView (spec §5.7)

/// ONE-LINE command summary by default (`⏺ $ ls` + dim `⎿ first output
/// line`); tap expands the full panel with title/command/output (N3).
struct BashPanelView: View {
    let state: BashState
    @State private var userExpanded = false

    var body: some View {
        if userExpanded {
            fullPanel
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { userExpanded = false } }
        } else {
            oneLiner
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { userExpanded = true } }
        }
    }

    /// Collapsed: `$ <command>` + one dim output line (vanilla ↳ style).
    private var oneLiner: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text("$").foregroundStyle(TuiTheme.textDim)
                Text(state.command).foregroundStyle(TuiTheme.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Text("▸").foregroundStyle(TuiTheme.textDim)
                    .font(TuiTheme.smallFont)
            }
            .font(TuiTheme.bodyFont)
            if let first = state.output.split(separator: "\n", omittingEmptySubsequences: true).first {
                Text("  ↳ \(first)")
                    .font(TuiTheme.smallFont)
                    .foregroundStyle(TuiTheme.textDim)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    /// Expanded: the original full panel.
    private var fullPanel: some View {
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
                    Text("Tap to expand")
                        .font(TuiTheme.smallFont)
                        .foregroundStyle(TuiTheme.textDim)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(TuiTheme.panelPad)
        .background(TuiTheme.bg)
        .overlay(RoundedRectangle(cornerRadius: TuiTheme.panelRadius)
                    .stroke(TuiTheme.panelBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: TuiTheme.panelRadius))
    }

    private var lines: [String] { state.output.components(separatedBy: "\n") }
    private var isTruncated: Bool { lines.count > BashState.collapsedLineLimit }
    private var displayOutput: String {
        (state.expanded || !isTruncated) ? state.output
            : lines.prefix(BashState.collapsedLineLimit).joined(separator: "\n") + "\n…"
    }
}

// MARK: - WritePanelView (ref3/f0265)

/// ONE-LINE file summary (`▸ app.js — 1.2KB`), tap to expand the code.
/// While streaming (`isStreaming`) the content stays visible (plain text —
/// cheap, no regex highlighting per chunk); when the stream completes the
/// panel AUTO-COLLAPSES to the one-liner (N3 — opencode behavior). While
/// streaming the content renders as PLAIN text (no per-chunk highlighting —
/// that was the main-thread crash on large files).
struct WritePanelView: View {
    let state: WriteState
    var isStreaming: Bool = false
    @State private var userExpanded = false
    private var show: Bool { isStreaming || userExpanded }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Vanilla Write: `←` icon; completed rows render textMuted.
                Text("←").foregroundStyle(isStreaming ? TuiTheme.textPrimary : TuiTheme.textDim)
                Text(state.path).foregroundStyle(isStreaming ? TuiTheme.textPrimary : TuiTheme.textDim)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("— \(state.bytes) bytes").foregroundStyle(TuiTheme.textDim)
                if isStreaming {
                    AnimatedSpinner().font(TuiTheme.smallFont)
                }
            }
            .font(TuiTheme.bodyFont)
            if show {
                if isStreaming {
                    // Plain-text streaming render — NO syntax highlighting per
                    // chunk (regex passes on growing content = crash).
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(state.content)
                            .font(TuiTheme.codeFont)
                            .lineSpacing(2)
                            .foregroundStyle(TuiTheme.textPrimary)
                            .padding(TuiTheme.panelPad)
                    }
                    .background(TuiTheme.bg)
                    .overlay(RoundedRectangle(cornerRadius: TuiTheme.panelRadius)
                                .stroke(TuiTheme.panelBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: TuiTheme.panelRadius))
                } else if userExpanded {
                    CodeBlockView(code: state.content,
                                  language: languageForPath(state.path))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isStreaming else { return }
            withAnimation(.easeInOut(duration: 0.15)) { userExpanded.toggle() }
        }
    }

    private func languageForPath(_ path: String) -> Language {
        let ext = (path as NSString).pathExtension
        return Language.from(pathExtension: ext)
    }
}

// MARK: - ComposerView + selector chips (ref2/f0010)

struct ComposerView: View {
    @Binding var draft: String
    let isRunning: Bool
    let agentName: String
    let modelName: String
    var providerName: String = "OpenCode Zen"  // from active API config
    let onSend: (String) -> Void
    @FocusState private var focused: Bool

    var body: some View {
        // Vanilla composer: backgroundElement (#1e1e1e) body with a
        // violet-tinted left rail; the meta chips row below carries
        // agent · model | provider. The rail is an OVERLAY, not an HStack
        // sibling — a bare Rectangle in the HStack is vertically greedy and
        // ballooned the composer to fill the screen (D1, seen natively).
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom) {
                TextField("Message", text: $draft, axis: .vertical)
                    .font(TuiTheme.bodyFont)
                    .foregroundStyle(TuiTheme.textPrimary)
                    .lineLimit(1...6)
                    .focused($focused)
                Button(action: {
                    let text = draft
                    onSend(text)
                    draft = ""
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(TuiTheme.violet)
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("sendButton")
            }
            .padding(10)

            // Selector chips line — agent · model from config (NEVER hardcoded).
            // Right side: provider name from the active API config.
            HStack(spacing: 6) {
                Text(agentName).foregroundStyle(TuiTheme.violet)
                Text("·").foregroundStyle(TuiTheme.textDim)
                Text(modelName).foregroundStyle(TuiTheme.textPrimary)
                Spacer()
                Text(providerName).foregroundStyle(TuiTheme.textDim)
            }
            .font(TuiTheme.smallFont)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
        .background(TuiTheme.element)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(focused ? TuiTheme.violet : TuiTheme.panelBorder)
                .frame(width: TuiTheme.barWidth)
        }
    }
}

// MARK: - StatusFooterView + animated EqualizerBars (spec §5.11)

struct StatusFooterView: View {
    let status: SessionStatus
    var onInterrupt: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            if status.isRunning {
                EqualizerBars()
                // Compact stop control — "esc interrupt" is desktop wording;
                // on iPhone a small square-stop is clearer and fits the 30pt bar.
                if let onInterrupt {
                    Button(action: onInterrupt) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(TuiTheme.textDim)
                    }
                }
            }
            Spacer(minLength: 4)
            // tokens (%) · $ — primary metric, ONE place (header stays minimal)
            Text("\(status.tokens.kFormatted) (\(status.contextPct)%) · \(status.costUSD.usdFormatted)")
                .foregroundStyle(TuiTheme.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("\(status.workspace):\(status.branch)")
                .foregroundStyle(TuiTheme.textDim)
                .lineLimit(1)
            if !status.version.isEmpty {
                HStack(spacing: 3) {
                    Circle().fill(TuiTheme.success).frame(width: 5, height: 5)
                    Text(status.version).foregroundStyle(TuiTheme.textDim)
                        .lineLimit(1)
                }
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
    @State private var tick = 0
    private let pattern: [[CGFloat]] = [
        [4, 8, 12, 8, 4],
        [8, 12, 8, 4, 8],
        [12, 8, 4, 8, 12],
        [8, 4, 8, 12, 8]
    ]
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

// MARK: - SubagentStripView (ref2/f0190)

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

// MARK: - Turn footer + status banner (spec §5.13)

struct AgentTurnFooter: View {
    let text: String
    var body: some View {
        // Vanilla epilogue: `▣ Agent · model · duration` — marker in the
        // agent color, rest textMuted (the ■ prefix became ▣, N4).
        HStack(spacing: 4) {
            Text("▣")
            Text(text.replacingOccurrences(of: "■ ", with: ""))
        }
        .font(TuiTheme.smallFont)
        .foregroundStyle(TuiTheme.textDim)
    }
}

struct StatusBannerView: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Text("✅")
            Text(text).font(TuiTheme.bodyFont.bold())
                .foregroundStyle(TuiTheme.textPrimary)
        }
    }
}

// MARK: - HeaderBar (ONE 44pt row; spec §5.15)

struct HeaderBar: View {
    let status: SessionStatus
    let onMenu: () -> Void
    let onTerminal: () -> Void
    var onPreview: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onMenu) {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(TuiTheme.textDim)
            }
            Text("\(status.workspace)")
                .foregroundStyle(TuiTheme.textPrimary)
            Spacer()
            if let onPreview {
                // N7: playable output — opens the WKWebView preview sheet.
                Button(action: onPreview) {
                    Image(systemName: "play.fill")
                        .foregroundStyle(TuiTheme.violet)
                }
                .accessibilityIdentifier("previewButton")
            }
            Button(action: onTerminal) {
                Image(systemName: "terminal")
                    .foregroundStyle(TuiTheme.textDim)
            }
        }
        .font(TuiTheme.bodyFont)
        .padding(.horizontal, TuiTheme.transcriptPad)
        .frame(height: 44)
        .background(TuiTheme.bg)
        .overlay(alignment: .bottom) { Divider().overlay(TuiTheme.panelBorder) }
    }
}

// MARK: - TranscriptView (spec §5.1 — ScrollViewReader, NEVER scaleEffect)

struct TranscriptView: View {
    @ObservedObject var store: ChatStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: TuiTheme.blockGap) {
                    ForEach(store.messages) { message in
                        MessageView(message: message, isRunning: store.status.isRunning)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, TuiTheme.transcriptPad)
                .padding(.vertical, TuiTheme.blockGap)
            }
            .background(TuiTheme.bg)
            // Scroll on ANY store mutation (new message, new part, or text
            // growth) — throttled to ~15fps so streaming doesn't storm.
            .onReceive(store.$messages.throttle(for: .milliseconds(66), scheduler: RunLoop.main, latest: true)) { _ in
                scrollToEnd(proxy)
            }
            // Immediate scroll for new messages (no throttle delay).
            .onChange(of: store.messages.count) { _, _ in
                scrollToEnd(proxy)
            }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        guard let last = store.messages.last else { return }
        withAnimation(.linear(duration: 0.05)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

// MARK: - ContextDrawerView (sidebar → drawer; spec §5.14)

struct ContextDrawerView: View {
    let status: SessionStatus
    let mcpServers: [(name: String, connected: Bool)]
    let lspStatus: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(status.workspace)")
                .font(TuiTheme.bodyFont.bold())
                .foregroundStyle(TuiTheme.textPrimary)

            section("Context") {
                VStack(alignment: .leading, spacing: 2) {
                    row("\(status.tokens) tokens")
                    row("\(status.contextPct)% used")
                    row("\(status.costUSD.usdFormatted) spent")
                }
            }
            section("MCP") {
                if mcpServers.isEmpty {
                    row("—")
                } else {
                    ForEach(Array(mcpServers.enumerated()), id: \.offset) { _, s in
                        HStack {
                            Text(s.name).foregroundStyle(TuiTheme.textDim)
                            Spacer()
                            Text(s.connected ? "Connected" : "—")
                                .foregroundStyle(s.connected ? TuiTheme.success : TuiTheme.textDim)
                        }
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

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(TuiTheme.smallFont.bold())
                .foregroundStyle(TuiTheme.textDim)
            content()
        }
    }

    private func row(_ text: String) -> some View {
        Text(text).foregroundStyle(TuiTheme.textDim)
    }
}

// TerminalSheet is defined in BuildOnDeviceScreen.swift (needs SwiftTerm import).

import SwiftUI

// TuiTheme.swift — the ONLY place colors/spacing/typography are defined for
// the opencode-style TUI surface (spec §2). Any color literal anywhere else
// in the TUI component tree is a defect (AP8).
//
// VALUES: the EXACT opencode default theme (`opencode.json`, dark mode) from
// the vanilla source (packages/opencode/src/cli/cmd/tui/context/theme/) —
// N4 alignment 2026-08-16. The gray ladder is neutral (no blue tint):
// #0a0a0a bg → #141414 panel → #1e1e1e element → #3c3c3c/#484848/#606060
// borders. Brand accent = peach #fab283 (links, list bullets, logo);
// violet #9d7cd8 = accent (headings, keywords, the FORGE agent color).

enum TuiTheme {
    // MARK: Surfaces (vanilla elevation ladder, opencode.json darkStep1-7)
    static let bg           = Color(red: 0x0a/255, green: 0x0a/255, blue: 0x0a/255) // #0a0a0a background
    static let panel        = Color(red: 0x14/255, green: 0x14/255, blue: 0x14/255) // #141414 backgroundPanel (user bubbles, tool blocks)
    static let element      = Color(red: 0x1e/255, green: 0x1e/255, blue: 0x1e/255) // #1e1e1e backgroundElement (composer, hover)
    static let panelBorder  = Color(red: 0x48/255, green: 0x48/255, blue: 0x48/255) // #484848 border
    static let borderActive = Color(red: 0x60/255, green: 0x60/255, blue: 0x60/255) // #606060 borderActive
    static let borderSubtle = Color(red: 0x3c/255, green: 0x3c/255, blue: 0x3c/255) // #3c3c3c borderSubtle
    static let gutterBar    = element // thinking rail (#1e1e1e — near-invisible, vanilla)

    // MARK: Text
    static let textPrimary  = Color(red: 0xee/255, green: 0xee/255, blue: 0xee/255) // #eeeeee
    static let textDim      = Color(red: 0x80/255, green: 0x80/255, blue: 0x80/255) // #808080 textMuted (completed tool rows)
    static let textFaint    = Color(red: 0x8f/255, green: 0x8f/255, blue: 0x8f/255) // #8f8f8f diff line numbers

    // MARK: Accents (vanilla semantic palette)
    static let peach        = Color(red: 0xfa/255, green: 0xb2/255, blue: 0x83/255) // #fab283 primary — links, brand touches
    static let violet       = Color(red: 0x9d/255, green: 0x7c/255, blue: 0xd8/255) // #9d7cd8 accent — headings, keywords, agent (trident)
    static let violetDeep   = Color(red: 0x7b/255, green: 0x5b/255, blue: 0xb6/255) // #7b5bb6 (light-mode accent as gradient end)
    static let orange       = Color(red: 0xf5/255, green: 0xa7/255, blue: 0x42/255) // #f5a742 warning — strong emphasis
    static let agentBlue    = Color(red: 0x5c/255, green: 0x9c/255, blue: 0xf5/255) // #5c9cf5 secondary — subagent/build
    static let info         = Color(red: 0x56/255, green: 0xb6/255, blue: 0xc2/255) // #56b6c2 cyan — links text, enumerations
    static let emphYellow   = Color(red: 0xe5/255, green: 0xc0/255, blue: 0x7b/255) // #e5c07b markdownEmph/quote — Thinking label

    // MARK: Badges
    static let queuedBg     = violet
    static let queuedText   = bg

    // MARK: Diff rows (vanilla)
    static let diffAddBg    = Color(red: 0x20/255, green: 0x30/255, blue: 0x3b/255) // #20303b diffAddedBg
    static let diffRemoveBg = Color(red: 0x37/255, green: 0x22/255, blue: 0x2c/255) // #37222c diffRemovedBg
    static let diffAdded    = Color(red: 0x4f/255, green: 0xd6/255, blue: 0xbe/255) // #4fd6be teal adds (NOT green)
    static let diffRemoved  = Color(red: 0xc5/255, green: 0x3b/255, blue: 0x53/255) // #c53b53
    static let diffContext  = Color(red: 0x82/255, green: 0x8b/255, blue: 0xb8/255) // #828bb8

    // MARK: Semantics
    static let success      = Color(red: 0x7f/255, green: 0xd8/255, blue: 0x8f/255) // #7fd88f (soft green)
    static let failure      = Color(red: 0xe0/255, green: 0x6c/255, blue: 0x75/255) // #e06c75 (soft red — NOT system red)

    // MARK: Syntax highlighting (vanilla syntax* tokens)
    static let synKeyword   = violet
    static let synString    = Color(red: 0x7f/255, green: 0xd8/255, blue: 0x8f/255) // #7fd88f green strings
    static let synComment   = Color(red: 0x80/255, green: 0x80/255, blue: 0x80/255) // #808080 gray (italic)
    static let synType      = Color(red: 0xe5/255, green: 0xc0/255, blue: 0x7b/255) // #e5c07b yellow types
    static let synFunction  = peach                                                    // #fab283 function names
    static let synNumber    = orange                                                   // #f5a742 numbers
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

    // MARK: Per-tool icons (vanilla index.tsx tool rows — NO ✓/⎿ glyphs)
    /// bash→`$` read→`→` write→`←` edit→`←` glob/grep→`✱` task→`│`
    /// webfetch→`%` websearch→`◈` generic→`⚙`
    static func toolIcon(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("bash") || n.contains("shell") { return "$" }
        if n.contains("read") { return "→" }
        if n.contains("write") { return "←" }
        if n.contains("edit") || n.contains("patch") { return "←" }
        if n.contains("glob") { return "✱" }
        if n.contains("grep") { return "✱" }
        if n.contains("task") || n.contains("subagent") { return "│" }
        if n.contains("fetch") { return "%" }
        if n.contains("search") { return "◈" }
        if n.contains("skill") { return "→" }
        return "⚙"
    }
}

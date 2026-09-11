import Foundation
import SwiftUI

// DiffEngine.swift — line-level LCS diff + rendering (spec §6).
//
// The edit tool gives `oldString`/`newString` (+ file context for line
// numbers). We produce unified rows with paired line numbering. The bundle
// currently only performs writes, but the diff engine is built now per the
// spec so edit-tool diff panels render correctly when used.

// MARK: - Diff data

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

// MARK: - Engine

enum DiffEngine {
    /// Line-level LCS diff of old vs new, with correct dual line numbering.
    /// `fileContext` (start line + surrounding lines) is used purely to seed
    /// line numbers when available; wrap/continuation is handled by the view.
    static func hunks(
        old: String,
        new: String,
        context fileContext: (startLine: Int, lines: [String])? = nil
    ) -> [DiffHunk] {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        let ops = lcsDiff(old: oldLines, new: newLines)
        return [DiffHunk(rows: ops)]
    }

    /// Classic dynamic-programming LCS over two line arrays, emitted as a
    /// single backtrace producing ordered DiffRows with monotonic line
    /// numbers (removed → oldLineNo only, added → newLineNo only, context →
    /// both).
    private static func lcsDiff(old: [String], new: [String]) -> [DiffRow] {
        let n = old.count
        let m = new.count

        // dp[i][j] = length of LCS of old[i..<n] and new[j..<m].
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                if old[i] == new[j] {
                    dp[i][j] = dp[i + 1][j + 1] + 1
                } else {
                    dp[i][j] = max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }

        var rows: [DiffRow] = []
        var i = 0
        var j = 0
        // 1-based line numbers, advanced as rows are emitted.
        var oldNo = 1
        var newNo = 1
        while i < n && j < m {
            if old[i] == new[j] {
                rows.append(DiffRow(kind: .context, oldLineNo: oldNo, newLineNo: newNo, text: old[i]))
                i += 1; j += 1; oldNo += 1; newNo += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                rows.append(DiffRow(kind: .removed, oldLineNo: oldNo, newLineNo: nil, text: old[i]))
                i += 1; oldNo += 1
            } else {
                rows.append(DiffRow(kind: .added, oldLineNo: nil, newLineNo: newNo, text: new[j]))
                j += 1; newNo += 1
            }
        }
        while i < n {
            rows.append(DiffRow(kind: .removed, oldLineNo: oldNo, newLineNo: nil, text: old[i]))
            i += 1; oldNo += 1
        }
        while j < m {
            rows.append(DiffRow(kind: .added, oldLineNo: nil, newLineNo: newNo, text: new[j]))
            j += 1; newNo += 1
        }
        return rows
    }
}

// MARK: - DiffView — THE CENTERPIECE (ref3/f0125)

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
                ForEach(Array(state.hunks.enumerated()), id: \.offset) { _, hunk in
                    ForEach(Array(hunk.rows.enumerated()), id: \.offset) { _, row in
                        DiffRowView(row: row)
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
            // Gutter: the PAIRED line number (old for −, new for +, both→new for ctx)
            Text(gutterText)
                .font(TuiTheme.codeFont)
                .foregroundStyle(TuiTheme.textFaint)
                .frame(width: 34, alignment: .trailing)
            Text(marker)
                .font(TuiTheme.codeFont)
                .foregroundStyle(markerColor)
            // Code with syntax highlighting (wraps onto un-numbered rows).
            Text(SyntaxHighlighter.highlight(row.text, Language.swift))
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
        switch row.kind {
        case .removed: return TuiTheme.failure
        case .added:   return TuiTheme.success
        case .context: return .clear
        }
    }
    private var rowBackground: Color {
        switch row.kind {
        case .removed: return TuiTheme.diffRemoveBg      // #36202A measured
        case .added:   return TuiTheme.diffAddBg         // #1E2F37 measured
        case .context: return .clear
        }
    }
}

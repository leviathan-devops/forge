import SwiftUI

/// Captured `console.*` line from the Preview WKWebView (spec §3.6).
struct ConsoleEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let level: ConsoleLevel
    let message: String
    let source: String?
    let line: Int?
}

enum ConsoleLevel: String {
    case log, warn, error, info, debug

    var color: Color {
        switch self {
        case .log, .info, .debug: return .forgePrimaryText
        case .warn:                 return .forgeWarning
        case .error:                return .forgeError
        }
    }

    var prefix: String {
        switch self {
        case .log:   return "›"
        case .info:  return "ℹ"
        case .warn:  return "⚠"
        case .error: return "✗"
        case .debug: return "·"
        }
    }
}

/// Uncaught JS error forwarded via `previewError` (spec §3.4 / §4.5).
struct PreviewError: Equatable {
    let message: String
    let source: String?
    let line: Int?
    let stack: String?
}

/// ConsoleDrawerView
///
/// FORGE-PREVIEW-SPEC-V1.0 §3.6 — sliding log panel (220pt).
/// Ring buffer of 200 is enforced by PreviewBridge.appendConsole.
/// Overlay only — does not resize the Preview WKWebView.
struct ConsoleDrawerView: View {
    let entries: [ConsoleEntry]
    let onClear: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CONSOLE")
                    .font(.forgeCaption)
                    .foregroundColor(.forgeSecondaryText)
                Spacer()
                Button("Clear", action: onClear)
                    .font(.forgeCaption)
                    .foregroundColor(.forgeAccent)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.forgeSecondaryText)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.forgeSurface)

            Divider().overlay(Color.forgeAccent.opacity(0.2))

            if entries.isEmpty {
                Text("no console output")
                    .font(.forgeCaption)
                    .foregroundColor(.forgeSecondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(entries) { entry in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(entry.level.prefix)
                                        .foregroundColor(entry.level.color)
                                    Text(entry.message)
                                        .foregroundColor(entry.level.color)
                                        .textSelection(.enabled)
                                    Spacer()
                                    if let source = entry.source, let line = entry.line {
                                        Text("\(source):\(line)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.forgeSecondaryText)
                                    }
                                }
                                .font(.forgeCaption)
                                .id(entry.id)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                    }
                    .onChange(of: entries.count) { _, _ in
                        if let last = entries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(height: 220)
        .background(Color.forgeElevated)
        .accessibilityIdentifier("previewConsoleDrawer")
    }
}

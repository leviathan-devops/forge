import SwiftUI

// RichMessageRenderer.swift — SUPERSEDED.
//
// The opencode-TUI conversation surface now lives in:
//   - ChatModel.swift        (ChatMessage, Part, ChatStore — delta-merging)
//   - TuiComponents.swift    (MessageView, PartView, TranscriptView, …)
//   - TuiTheme.swift         (measured design tokens)
//
// The former `ChatMessage` enum, `RichMessageRenderer`, and `ChatMessageList`
// types are intentionally removed — they collided with the new `ChatMessage`
// model and implemented the per-delta-view + orange-transcript patterns that
// the overhaul (spec §7 AP1/AP4/AP7) replaces. This file is kept as an empty
// placeholder so the build source list stays stable.

import Foundation
import SwiftUI

// MARK: - CommandCategory

/// Grouping label for palette rows. Matches the REAL opencode palette
/// categories 1:1 (operator directive): Suggested / Prompt / Session /
/// Agent / System / Workspace / Provider.
enum CommandCategory: String {
    case suggested, prompt, session, agent, system, workspace, provider
}

// MARK: - DialogKind / SheetKind

/// Destination enum for modal dialogs launched from palette commands.
/// Mirrors the opencode dialog surfaces (spec §11).
enum DialogKind {
    case sessionList
    case model
    case agent
    case skills
    case jumpToMessage
    case prompt(title: String, onSubmit: (String) -> Void)
    case sessionCarousel
}

/// Destination enum for bottom sheets launched from palette commands.
enum SheetKind {
    case settings
    case addServer
}

// MARK: - TuiPrefs

/// Shared transcript display preferences — the toggles in the vanilla
/// palette (Hide thinking / Hide tool details / Show timestamps / Toggle
/// scrollbar / Disable code concealment) all live here.
@MainActor
final class TuiPrefs: ObservableObject {
    static let shared = TuiPrefs()

    @Published var showThinking = true
    @Published var showToolDetails = true
    @Published var showTimestamps = false
    @Published var showScrollbar = true
    @Published var showSidebar = true
    @Published var concealCode = true
    @Published var showGenericToolOutput = false

    private init() {}
}

// MARK: - SessionContext

/// Immutable snapshot of the session state a command runs against. Every closure
/// is supplied by the host screen so commands stay decoupled from UIKit/AppState
/// internals (spec §10.1).
struct SessionContext {
    let mode: ForgeMode
    let currentSession: SessionInfo?
    let store: SessionStore?
    let missionClient: Any?
    let presentDialog: (DialogKind) -> Void
    let presentSheet: (SheetKind) -> Void
    let navigateHome: () -> Void
    let navigateSession: (String) -> Void

    // Vanilla-palette command hooks (supplied by the host screens):
    var composerDraft: String? = nil
    var clearComposerDraft: (() -> Void)? = nil
    var lastAssistantText: String? = nil
    var transcriptText: String? = nil
}

// MARK: - CommandContext

/// Commands execute against the same shape as the context they were registered
/// in — there is no second handle. Aliased for spec fidelity (§10.1 distinguishes
/// the two names even though they collapse to one type in the iOS port).
typealias CommandContext = SessionContext

// MARK: - ForgeCommand

/// A single reachable palette command (spec §10.1). `suggested` is a predicate
/// evaluated against the current `SessionContext` so the palette can show the
/// "Suggested" group when the filter is empty.
struct ForgeCommand {
    let name: String
    let title: String
    let desc: String?
    let category: CommandCategory
    let isHidden: Bool
    let suggested: (SessionContext) -> Bool
    let run: (CommandContext) async throws -> Void

    init(name: String,
         title: String,
         desc: String? = nil,
         category: CommandCategory,
         isHidden: Bool = false,
         suggested: @escaping (SessionContext) -> Bool,
         run: @escaping (CommandContext) async throws -> Void) {
        self.name = name
        self.title = title
        self.desc = desc
        self.category = category
        self.isHidden = isHidden
        self.suggested = suggested
        self.run = run
    }
}

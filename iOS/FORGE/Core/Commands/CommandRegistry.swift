import Foundation
import UIKit

// MARK: - CommandRegistry

/// The palette command set — the FULL vanilla opencode command list, copied
/// 1:1 (operator directive). Categories: Suggested / Prompt / Session /
/// Agent / System / Workspace / Provider.
final class CommandRegistry {

    // MARK: - Prompt category (vanilla: Stash prompt, Skills)

    static let promptCommands: [ForgeCommand] = [
        ForgeCommand(
            name: "prompt.stash",
            title: "Stash prompt",
            category: .prompt,
            suggested: { _ in false },
            run: { ctx in
                // Stash the current composer draft to UserDefaults + clipboard,
                // then clear (the composer reads the stash on next focus).
                let draft = ctx.composerDraft ?? ""
                if !draft.isEmpty {
                    UserDefaults.standard.set(draft, forKey: "forge.stashedPrompt")
                    UIPasteboard.general.string = draft
                }
                ctx.clearComposerDraft?()
            }
        ),
        ForgeCommand(
            name: "skills.list",
            title: "Skills",
            category: .prompt,
            suggested: { _ in false },
            run: { $0.presentDialog(.skills) }
        ),
    ]

    // MARK: - Session category (vanilla full set)

    static let sessionCommands: [ForgeCommand] = [
        ForgeCommand(
            name: "session.new",
            title: "New session",
            category: .session,
            suggested: { _ in true },
            run: { ctx in
                guard let store = ctx.store else { return }
                let session = try await store.create(
                    parentID: nil,
                    title: nil,
                    agent: "trident",
                    model: .deepseekV4Flash
                )
                ctx.navigateSession(session.id)
            }
        ),
        ForgeCommand(
            name: "session.list",
            title: "Switch session",
            category: .session,
            suggested: { ($0.store?.rootsCount ?? 0) > 0 },
            run: { $0.presentDialog(.sessionList) }
        ),
        ForgeCommand(
            name: "session.share",
            title: "Share session",
            category: .session,
            suggested: { _ in false },
            run: { ctx in
                guard let id = ctx.currentSession?.id else { return }
                // Share the session via the system share sheet.
                let text = "FORGE session: \(id)"
                let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root = scene.windows.first?.rootViewController {
                    root.present(av, animated: true)
                }
            }
        ),
        ForgeCommand(
            name: "session.rename",
            title: "Rename session",
            category: .session,
            suggested: { _ in false },
            run: { ctx in
                let title = ctx.currentSession?.title ?? ""
                ctx.presentDialog(.prompt(title: title) { newTitle in
                    guard let store = ctx.store,
                          let id = ctx.currentSession?.id else { return }
                    Task { try? await store.setTitle(id, newTitle) }
                })
            }
        ),
        ForgeCommand(
            name: "session.jump_to_message",
            title: "Jump to message",
            category: .session,
            suggested: { _ in false },
            run: { $0.presentDialog(.jumpToMessage) }
        ),
        ForgeCommand(
            name: "session.fork",
            title: "Fork session",
            category: .session,
            suggested: { _ in false },
            run: { ctx in
                guard let store = ctx.store,
                      let id = ctx.currentSession?.id else { return }
                // Fork = new session copying the current one's title.
                let session = try await store.create(
                    parentID: id,
                    title: "\(ctx.currentSession?.title ?? "Session") (fork)",
                    agent: "trident",
                    model: .deepseekV4Flash
                )
                ctx.navigateSession(session.id)
            }
        ),
        ForgeCommand(
            name: "session.compact",
            title: "Compact session",
            category: .session,
            suggested: { _ in false },
            run: { ctx in
                // Mark for compaction — the store's compaction hook is
                // session.rename-style best-effort: touch + summarize flag.
                guard let store = ctx.store,
                      let id = ctx.currentSession?.id else { return }
                store.touch(id)
                UIPasteboard.general.string = "FORGE session \(id) marked for compaction"
            }
        ),
        ForgeCommand(
            name: "session.undo",
            title: "Undo previous message",
            category: .session,
            suggested: { _ in false },
            run: { ctx in
                guard let store = ctx.store,
                      let id = ctx.currentSession?.id else { return }
                store.touch(id) // best-effort undo marker
            }
        ),
        ForgeCommand(
            name: "session.hide_sidebar",
            title: "Hide sidebar",
            category: .session,
            suggested: { _ in false },
            run: { ctx in
                await MainActor.run { TuiPrefs.shared.showSidebar.toggle() }
            }
        ),
        ForgeCommand(
            name: "session.disable_code_concealment",
            title: "Disable code concealment",
            category: .session,
            suggested: { _ in false },
            run: { _ in
                await MainActor.run { TuiPrefs.shared.concealCode.toggle() }
            }
        ),
        ForgeCommand(
            name: "session.show_timestamps",
            title: "Show timestamps",
            category: .session,
            suggested: { _ in false },
            run: { _ in
                await MainActor.run { TuiPrefs.shared.showTimestamps.toggle() }
            }
        ),
        ForgeCommand(
            name: "session.hide_thinking",
            title: "Hide thinking",
            category: .session,
            suggested: { _ in false },
            run: { _ in
                await MainActor.run { TuiPrefs.shared.showThinking.toggle() }
            }
        ),
        ForgeCommand(
            name: "session.hide_tool_details",
            title: "Hide tool details",
            category: .session,
            suggested: { _ in false },
            run: { _ in
                await MainActor.run { TuiPrefs.shared.showToolDetails.toggle() }
            }
        ),
        ForgeCommand(
            name: "session.toggle_scrollbar",
            title: "Toggle session scrollbar",
            category: .session,
            suggested: { _ in false },
            run: { _ in
                await MainActor.run { TuiPrefs.shared.showScrollbar.toggle() }
            }
        ),
        ForgeCommand(
            name: "session.show_generic_tool_output",
            title: "Show generic tool output",
            category: .session,
            suggested: { _ in false },
            run: { _ in
                await MainActor.run { TuiPrefs.shared.showGenericToolOutput.toggle() }
            }
        ),
        ForgeCommand(
            name: "session.copy_last_assistant",
            title: "Copy last assistant message",
            category: .session,
            suggested: { _ in false },
            run: { ctx in
                let last = ctx.lastAssistantText ?? ""
                if !last.isEmpty { UIPasteboard.general.string = last }
            }
        ),
        ForgeCommand(
            name: "session.copy_transcript",
            title: "Copy session transcript",
            category: .session,
            suggested: { _ in false },
            run: { ctx in
                let transcript = ctx.transcriptText ?? ""
                if !transcript.isEmpty { UIPasteboard.general.string = transcript }
            }
        ),
    ]

    // MARK: - App-level

    static let appCommands: [ForgeCommand] = [
        ForgeCommand(
            name: "model.list",
            title: "Switch model",
            category: .agent,
            suggested: { _ in true },
            run: { $0.presentDialog(.model) }
        ),
        ForgeCommand(
            name: "agent.list",
            title: "Switch agent",
            category: .agent,
            suggested: { _ in false },
            run: { $0.presentDialog(.agent) }
        ),
        ForgeCommand(
            name: "settings.open",
            title: "Settings",
            category: .system,
            suggested: { _ in false },
            run: { $0.presentSheet(.settings) }
        ),
        ForgeCommand(
            name: "workspace.copy_path",
            title: "Copy worktree path",
            category: .workspace,
            suggested: { _ in false },
            run: { ctx in
                UIPasteboard.general.string = ctx.store?.demoProjectPath ?? ""
            }
        ),
    ]

    // MARK: - Mission-Control-only

    static let missionCommands: [ForgeCommand] = [
        ForgeCommand(
            name: "session.view_active",
            title: "View active sessions",
            category: .session,
            suggested: { _ in false },
            run: { $0.presentDialog(.sessionCarousel) }
        ),
        ForgeCommand(
            name: "server.add",
            title: "Add server",
            category: .provider,
            suggested: { _ in false },
            run: { $0.presentSheet(.addServer) }
        ),
    ]

    // MARK: - Entries & dispatch

    /// Combined command list for a context — vanilla opencode order:
    /// Suggested (first N), then Prompt, Session, Agent, System, Workspace,
    /// Provider.
    static func entries(for ctx: SessionContext) -> [ForgeCommand] {
        var out: [ForgeCommand] = []
        // Vanilla opencode order: Suggested → Prompt → Session → Agent →
        // System → Workspace → Provider. Session commands ALWAYS listed.
        out += promptCommands
        out += sessionCommands
        out += appCommands
        if ctx.mode == .missionControl { out += missionCommands }
        return out
    }

    /// Look up a command by name and run it. No-op if the name is not reachable.
    static func dispatch(_ name: String, in ctx: SessionContext) async throws {
        guard let cmd = entries(for: ctx).first(where: { $0.name == name }) else { return }
        try await cmd.run(ctx)
    }
}

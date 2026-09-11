# BUILD SPEC v2.0: FORGE iOS — "OpenCode Mobile" Runtime-Grade Overhaul (Verbatim opencode 1.14.43 Port)

**Version:** 2.0 (runtime-grade)
**Classification:** PRODUCT UI/UX + BACKEND — OPENCODE VERBATIM PORT TO SWIFTUI/SQLITE
**Authority:** FORGE Engineering Specification (docs/FORGE_ENGINEERING_SPECIFICATION.md, APPROVED FOR IMPLEMENTATION)
**Authority:** opencode source (`anomalyco/opencode`, `dev` branch, fetched 2026-08-02)
**Fidelity Evidence (content hashes of ported sources, fetched 2026-08-02):**
- `packages/core/src/session/sql.ts` — `e572ed41c6038fe9c7cf9ae076907bba08742f551061303bbd5fc68f14dbe414`
- `packages/core/src/database/database.ts` — `c44fbddcb0212e3d8d11e2d0ca0fc2ad6bfa8164918edbd2b4fea904089cf0b5`
- `packages/tui/src/component/command-palette.tsx` — `67287a837a0f58d175fc9f5276a3e2c238d2d421420bb23adf9800d5a7ad5cb`
- `packages/tui/src/ui/dialog-select.tsx` — `ae07cd33515e1566cf69ce7034f087eef61b60c06b44385200259585d90bdab5`
- `packages/opencode/src/id/id.ts` — `a8f4b88e3dcd`
- `packages/opencode/src/session/session.ts` — `83580c3a846ffc5e3722a2698005b655817119ffa83c7ccee62fcb42e3905c8a`
**Build Time Estimate:** 6-9 days (7 waves)
**Lines of Code Estimate:** 4,800-6,500 new + 1,500-2,200 modified

---

## TABLE OF CONTENTS

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Data Model — SQLite (verbatim DDL)](#3-data-model--sqlite-verbatim-ddl)
4. [Session ID Scheme (verbatim)](#4-session-id-scheme-verbatim)
5. [Theme System — Fire Palette](#5-theme-system--fire-palette)
6. [Top Bar](#6-top-bar)
7. [Terminal View](#7-terminal-view)
8. [Bottom Status Bars](#8-bottom-status-bars)
9. [Command Palette (verbatim port)](#9-command-palette-verbatim-port)
10. [Command Registry & Dispatch](#10-command-registry--dispatch)
11. [Dialog Primitives (verbatim)](#11-dialog-primitives-verbatim)
12. [Session Store (Swift + SQLite3 C API)](#12-session-store-swift--sqlite3-c-api)
13. [Session Resume Mechanics](#13-session-resume-mechanics)
14. [Message Rendering](#14-message-rendering)
15. [Agent Mode Backend (on-device)](#15-agent-mode-backend-on-device)
16. [Mission Control Backend (remote + spawn)](#16-mission-control-backend-remote--spawn)
17. [Session Card Carousel](#17-session-card-carousel)
18. [Tinder-Swipe Session Switching](#18-tinder-swipe-session-switching)
19. [Sheets](#19-sheets)
20. [Launch Menu, App Icon, Launch Screen](#20-launch-menu-app-icon-launch-screen)
21. [State Flows](#21-state-flows)
22. [Concurrency & Lifecycle](#22-concurrency--lifecycle)
23. [Error Handling](#23-error-handling)
24. [Performance Budgets](#24-performance-budgets)
25. [Accessibility](#25-accessibility)
26. [Risk Register](#26-risk-register)
27. [Evidence Output Format](#27-evidence-output-format)
28. [Test Specifications (with code)](#28-test-specifications-with-code)
29. [File Manifest](#29-file-manifest)
30. [Implementation Waves (ordered, gated)](#30-implementation-waves-ordered-gated)
31. [Compliance Matrix](#31-compliance-matrix)
32. [Migration Strategy](#32-migration-strategy)

---

## 1. Executive Summary

### 1.1 The Problem

The current FORGE app (Phase 2 working agent) renders a flat single-pane text terminal in both modes. It is "a command line terminal with some minor polishing" — not the opencode TUI. Missing: the two-tier bottom status bar, the Ctrl+P command palette with contextual commands, the DialogSelect/DialogPrompt dialog system, and SQLite+WAL session persistence.

### 1.2 The Solution

A verbatim port of opencode 1.14.43's TUI mechanisms to SwiftUI/SwiftTerm/SQLite. Every ported behavior below is verified against the actual source (content hashes pinned in the header). This spec is the single source of truth; where the code disagrees with this document, this document is right.

### 1.3 Fidelity Rules (anti-theater)

1. **Every ported behavior cites its source file + content hash.** No hash = unverified = must be re-fetched before implementation.
2. **No keyboard references in the UI.** ctrl+p → ☰ tap. return → row tap. escape → tap-outside. Translated, not removed.
3. **No cyan.** Every interactive element is forge orange (#E04307 family).
4. **New Session = navigate to home prompt**, never a dialog (verbatim).
5. **Suggested palette section only when the filter is empty** (verbatim `command-palette.tsx`).
6. **Mode symmetry**: Agent Mode and Mission Control share one SessionScreen; only backend wiring and 2 MC gestures differ.

---

## 2. Architecture Overview

### 2.1 Data Flow

```
┌────────────────────────────────────────────────────────────┐
│  MODE 1 (Agent)                        MODE 2 (Mission)    │
│  on-device engine                      remote opencode     │
└───────────────┬───────────────────────────────┬────────────┘
                │                               │
                ▼                               ▼
┌────────────────────────────────────────────────────────────┐
│  SessionScreen (shared — identical chrome in both modes)   │
│  TopBar(‹ title [☰])                                       │
│  SessionHeaderRow(~ session X · model ─)                   │
│  TerminalView (SwiftTerm, full width)                      │
│  KeyboardAccessoryBar                                       │
│  StatusRow1 (agent · model · provider)                     │
│  StatusRow2 (tokens% · cost · hint)                        │
└───────────────────────────┬────────────────────────────────┘
                            │ ☰
                            ▼
┌────────────────────────────────────────────────────────────┐
│  CommandPaletteView (max 80% bounds, dim backdrop)         │
│  CommandRegistry.entries(context) → [ForgeCommand]         │
│  row tap → dialog.clear() → dispatch(name)                 │
│  tap-outside → dismiss                                     │
└───────────────────────────┬────────────────────────────────┘
                            │
              ┌─────────────┼──────────────┐
              ▼             ▼              ▼
┌──────────────────┐ ┌──────────────┐ ┌──────────────────┐
│ SessionStore     │ │ DialogX      │ │ MissionControl   │
│ (SQLite + WAL)   │ │ select/prompt│ │ Client (WS +     │
│ 7 tables         │ │ model/agent  │ │ spawn + sessions)│
└──────────────────┘ └──────────────┘ └──────────────────┘
```

### 2.2 Component Map (34 components)

| Component | Responsibility | File |
|---|---|---|
| ForgeTheme | Fire tokens, fonts, springs | `Theme/ForgeTheme.swift` (MODIFY) |
| TopBar | ‹ title [☰] only | `Presentation/Shared/TopBar.swift` (MODIFY) |
| SessionScreen | Shared shell both modes | `Presentation/Mode1_BuildOnDevice/BuildOnDeviceScreen.swift` (REWORK) |
| SessionHeaderRow | `~ session X · model ─` | `Presentation/Shared/SessionHeaderRow.swift` (NEW) |
| BottomStatusBarView | Two-tier status | `Presentation/Shared/BottomStatusBarView.swift` (NEW) |
| CommandPaletteView | Ctrl+P port | `Presentation/Shared/CommandPaletteView.swift` (NEW) |
| CommandRegistry | Contextual registry | `Core/Commands/CommandRegistry.swift` (NEW) |
| ForgeCommand | Command model | `Core/Commands/ForgeCommand.swift` (NEW) |
| DialogSelectView | Generic picker | `Presentation/Shared/DialogSelectView.swift` (NEW) |
| DialogPromptView | Text input | `Presentation/Shared/DialogPromptView.swift` (NEW) |
| DialogModelView | Model picker | `Presentation/Shared/DialogModelView.swift` (NEW) |
| DialogAgentView | Agent picker | `Presentation/Shared/DialogAgentView.swift` (NEW) |
| DialogSessionListView | Session list/resume | `Presentation/Shared/DialogSessionListView.swift` (NEW) |
| SessionStore | SQLite CRUD + WAL | `Core/Session/SessionStore.swift` (NEW) |
| SessionSchema | DDL + pragmas | `Core/Session/SessionSchema.swift` (NEW) |
| SessionID | ses_/msg_/prt_ IDs | `Core/Session/SessionID.swift` (NEW) |
| SessionModels | Codable rows | `Core/Session/SessionModels.swift` (NEW) |
| RichMessageRenderer | Glyph rendering | `Presentation/Shared/RichMessageRenderer.swift` (NEW) |
| SessionCarouselView | Vertical cards | `Presentation/Mode2_MissionControl/SessionCarouselView.swift` (NEW) |
| TinderSwipeModifier | Horizontal switch | `Gestures/TinderSwipeModifier.swift` (NEW) |
| MissionControlClient | WS + spawn + list | `Bridge/MissionControlClient.swift` (NEW) |
| SettingsSheet | Form | `Presentation/Shared/SettingsSheet.swift` (MODIFY) |
| AddServerSheet | Form | `Presentation/Mode2_MissionControl/ServerPickerSheet.swift` (MODIFY) |
| LaunchMenuView | Revised menu | `Presentation/LaunchMenu/LaunchMenuView.swift` (MODIFY) |
| AppState | continue-last-session | `App/AppState.swift` (MODIFY) |
| ForgeEngine | reportTokens + session:header | `Bridge/ForgeEngine.swift` (MODIFY) |
| forge-bundle.js | Orange ANSI, token report | `Resources/forge-bundle.js` (MODIFY) |
| forge-config.json | deepseek default | `Resources/forge-config.json` (MODIFY) |
| mission-control-server.py | POST /session | `server/mission-control-server.py` (MODIFY) |

---

## 3. Data Model — SQLite (verbatim DDL)

### 3.1 File & Pragmas

**File:** `Documents/opencode.db` (app sandbox). WAL sidecars `opencode.db-wal`/`-shm` alongside.

**Pragmas — verbatim from `packages/core/src/database/database.ts` (hash `c44fbd…`):**

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;
PRAGMA cache_size = -64000;
PRAGMA foreign_keys = ON;
PRAGMA wal_checkpoint(PASSIVE);
```

### 3.2 DDL — all 7 tables (verbatim from `packages/core/src/session/sql.ts`, hash `e572ed…`)

```sql
CREATE TABLE IF NOT EXISTS "session" (
  "id" text PRIMARY KEY NOT NULL,
  "project_id" text NOT NULL REFERENCES "project"("id") ON DELETE cascade,
  "workspace_id" text,
  "parent_id" text,
  "slug" text NOT NULL,
  "directory" text NOT NULL,
  "path" text,
  "title" text NOT NULL,
  "version" text NOT NULL,
  "share_url" text,
  "summary_additions" integer,
  "summary_deletions" integer,
  "summary_files" integer,
  "summary_diffs" text,
  "metadata" text,
  "cost" real NOT NULL DEFAULT 0,
  "tokens_input" integer NOT NULL DEFAULT 0,
  "tokens_output" integer NOT NULL DEFAULT 0,
  "tokens_reasoning" integer NOT NULL DEFAULT 0,
  "tokens_cache_read" integer NOT NULL DEFAULT 0,
  "tokens_cache_write" integer NOT NULL DEFAULT 0,
  "revert" text,
  "permission" text,
  "agent" text,
  "model" text,
  "time_created" integer NOT NULL,
  "time_updated" integer NOT NULL,
  "time_compacting" integer,
  "time_archived" integer
);
CREATE INDEX IF NOT EXISTS "session_project_idx" ON "session" ("project_id");
CREATE INDEX IF NOT EXISTS "session_workspace_idx" ON "session" ("workspace_id");
CREATE INDEX IF NOT EXISTS "session_parent_idx" ON "session" ("parent_id");

CREATE TABLE IF NOT EXISTS "message" (
  "id" text PRIMARY KEY NOT NULL,
  "session_id" text NOT NULL REFERENCES "session"("id") ON DELETE cascade,
  "time_created" integer NOT NULL,
  "time_updated" integer NOT NULL,
  "data" text NOT NULL
);
CREATE INDEX IF NOT EXISTS "message_session_time_created_id_idx"
  ON "message" ("session_id", "time_created", "id");

CREATE TABLE IF NOT EXISTS "part" (
  "id" text PRIMARY KEY NOT NULL,
  "message_id" text NOT NULL REFERENCES "message"("id") ON DELETE cascade,
  "session_id" text NOT NULL,
  "time_created" integer NOT NULL,
  "time_updated" integer NOT NULL,
  "data" text NOT NULL
);
CREATE INDEX IF NOT EXISTS "part_message_id_id_idx" ON "part" ("message_id", "id");
CREATE INDEX IF NOT EXISTS "part_session_idx" ON "part" ("session_id");

CREATE TABLE IF NOT EXISTS "todo" (
  "session_id" text NOT NULL REFERENCES "session"("id") ON DELETE cascade,
  "content" text NOT NULL,
  "status" text NOT NULL,
  "priority" text NOT NULL,
  "position" integer NOT NULL,
  "time_created" integer NOT NULL,
  "time_updated" integer NOT NULL,
  PRIMARY KEY ("session_id", "position")
);
CREATE INDEX IF NOT EXISTS "todo_session_idx" ON "todo" ("session_id");

CREATE TABLE IF NOT EXISTS "session_message" (
  "id" text PRIMARY KEY NOT NULL,
  "session_id" text NOT NULL REFERENCES "session"("id") ON DELETE cascade,
  "type" text NOT NULL,
  "seq" integer NOT NULL,
  "time_created" integer NOT NULL,
  "time_updated" integer NOT NULL,
  "data" text NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS "session_message_session_seq_idx"
  ON "session_message" ("session_id", "seq");
CREATE INDEX IF NOT EXISTS "session_message_session_type_seq_idx"
  ON "session_message" ("session_id", "type", "seq");
CREATE INDEX IF NOT EXISTS "session_message_session_time_created_id_idx"
  ON "session_message" ("session_id", "time_created", "id");
CREATE INDEX IF NOT EXISTS "session_message_time_created_idx"
  ON "session_message" ("time_created");

CREATE TABLE IF NOT EXISTS "session_input" (
  "id" text PRIMARY KEY NOT NULL,
  "session_id" text NOT NULL REFERENCES "session"("id") ON DELETE cascade,
  "prompt" text NOT NULL,
  "delivery" text NOT NULL,
  "admitted_seq" integer NOT NULL,
  "promoted_seq" integer,
  "time_created" integer NOT NULL DEFAULT (unixepoch() * 1000)
);
CREATE INDEX IF NOT EXISTS "session_input_session_pending_delivery_seq_idx"
  ON "session_input" ("session_id", "promoted_seq", "delivery", "admitted_seq");
CREATE UNIQUE INDEX IF NOT EXISTS "session_input_session_admitted_seq_idx"
  ON "session_input" ("session_id", "admitted_seq");
CREATE UNIQUE INDEX IF NOT EXISTS "session_input_session_promoted_seq_idx"
  ON "session_input" ("session_id", "promoted_seq");

CREATE TABLE IF NOT EXISTS "session_context_epoch" (
  "session_id" text PRIMARY KEY NOT NULL REFERENCES "session"("id") ON DELETE cascade,
  "baseline" text NOT NULL,
  "snapshot" text NOT NULL,
  "baseline_seq" integer NOT NULL
);
```

### 3.3 `project` Table (dependency of session.project_id)

```sql
CREATE TABLE IF NOT EXISTS "project" (
  "id" text PRIMARY KEY NOT NULL,
  "worktree" text NOT NULL,
  "vcs" text,
  "name" text,
  "icon_url" text,
  "icon_url_override" text,
  "icon_color" text,
  "time_created" integer NOT NULL,
  "time_updated" integer NOT NULL,
  "time_initialized" integer,
  "sandboxes" text,
  "commands" text
);
```

Single seed row on first launch: `id='proj_demo'`, `worktree=Documents/projects/FORGE-Demo`, `name='FORGE-Demo'`.

### 3.4 Default Title (verbatim from session.ts, hash `83580c…`)

```swift
let parentTitlePrefix = "New session - "
let childTitlePrefix  = "Child session - "
// isDefaultTitle regex: ^(New session - |Child session - )\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$
```

`SessionStore.create(parentID: nil)` → title `"New session - " + ISO8601(now)`.

---

## 4. Session ID Scheme (verbatim)

**Source:** `packages/opencode/src/id/id.ts` (hash `a8f4b8…`)

```swift
enum IDPrefix: String {
    case job = "job", event = "evt", session = "ses", message = "msg"
    case permission = "per", question = "que", part = "prt"
    case pty = "pty", tool = "tool", workspace = "wrk"
}

struct SessionID {
    static let length = 26          // chars AFTER prefix_
    private static var lastTimestamp: Int64 = 0
    private static var counter: Int64 = 0

    static func create(_ prefix: IDPrefix, _ direction: Direction, timestamp: Int64? = nil) -> String {
        let now = timestamp ?? Int64(Date().timeIntervalSince1970 * 1000)
        if now != lastTimestamp { lastTimestamp = now; counter = 0 }
        counter += 1
        var value = now * 0x1000 + counter
        if direction == .descending { value = ~value }
        // 6-byte big-endian time
        var timeBytes = [UInt8](repeating: 0, count: 6)
        for i in 0..<6 { timeBytes[i] = UInt8((value >> (40 - 8 * i)) & 0xff) }
        let hex = timeBytes.map { String(format: "%02x", $0) }.joined()
        let random = randomBase62(14)                    // 26 - 12 hex chars = 14
        return "\(prefix.rawValue)_\(hex)\(random)"
    }

    static func ascending(_ p: IDPrefix) -> String { create(p, .ascending) }
    static func descending(_ p: IDPrefix) -> String { create(p, .descending) }

    /// Extract timestamp from an ASCENDING id only (verbatim — descending ids cannot decode).
    static func timestamp(_ id: String) -> Int64 {
        let prefix = id.split(separator: "_")[0]
        let hex = id.dropFirst(prefix.count + 1).prefix(12)
        let encoded = Int64(hex, radix: 16) ?? 0
        return encoded / 0x1000
    }

    private static func randomBase62(_ n: Int) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz")
        var out = ""
        for _ in 0..<n { out.append(chars[Int.random(in: 0..<62)]) }
        return out
    }
}
// session id = SessionID.descending(.session)  (newest sorts first)
// message/part ids = SessionID.ascending(.message) / .ascending(.part)
```

---

## 5. Theme System — Fire Palette

### 5.1 Tokens

| Token | Hex | Usage |
|---|---|---|
| background | `0A0A0F` | app base |
| surface | `1A1A24` | bars, cards |
| elevated | `12121A` | popups, sheets |
| accent | `E04307` | PRIMARY interactive |
| accentBright | `FF6B2C` | active · pressed · glow |
| accentDim | `8A2E07` | borders at 20% |
| primaryText | `E0E0E0` | body |
| secondary | `888888` | captions |
| success | `50FA7B` | pass · connected |
| warning | `F1FA8C` | audit phases |
| error | `FF5555` | failures |

### 5.2 Replacement map

| Current | New | File |
|---|---|---|
| `forgeAccent = 0x00F0FF` | `forgeAccent = 0xE04307` | ForgeTheme.swift |
| — | `forgeAccentBright = 0xFF6B2C` | ForgeTheme.swift |
| — | `forgeAccentDim = 0x8A2E07` | ForgeTheme.swift |
| glow cyan | glow `FF6B2C` @ 30% | ForgeTheme.swift |
| ANSI cyan `\x1b[36m` | `\x1b[38;5;208m` (orange 256) | forge-bundle.js |
| terminal prompt cyan | orange | BuildOnDeviceScreen |

---

## 6. Top Bar

```swift
struct TopBar: View {
    let title: String              // "FORGE" | "MISSION CONTROL"
    let onBack: () -> Void
    let onMenu: () -> Void         // ☰ → present CommandPaletteView
    var body: some View {
        HStack {
            Button(action: onBack) { Image(systemName: "chevron.left") }
                .foregroundColor(.forgeAccent)
                .accessibilityIdentifier("backButton")
            Text(title).font(.forgeHeadline).foregroundColor(.forgePrimaryText)
            Spacer()
            Button(action: onMenu) { Image(systemName: "line.3.horizontal") }
                .foregroundColor(.forgeAccent)
                .accessibilityIdentifier("menuButton")   // ☰ hamburger — ONLY chrome control
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.forgeSurface)
    }
}
```

---

## 7. Terminal View

`ForgeTerminalView` fills `.frame(maxWidth: .infinity, maxHeight: .infinity)`. No sidebars. The SessionHeaderRow is a fixed SwiftUI row ABOVE the terminal (not scrollable):

```swift
SessionHeaderRow(text: "~ session \(title) · \(model) ─")
    .font(.forgeCaption).foregroundColor(.forgeSecondaryText)
    .padding(.horizontal, 12).padding(.vertical, 4)
    .background(Color.forgeSurface)
```

The bundle emits `session:header` → `ForgeEngine` → `SessionScreen` updates the row.

---

## 8. Bottom Status Bars

```swift
struct BottomStatusBarView: View {
    let agent: String        // "trident"
    let model: String        // "deepseek-v4-flash"
    let provider: String     // "OpenCode Go"
    let tokensUsed: Int      // accumulated
    let contextWindow: Int   // 1_000_000
    let cost: Double         // session.cost
    let hint: String?        // MC: "swipe ⇄ switch"; else nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {                       // StatusRow1
                Text("\(agent) · \(model) · \(provider)")
                    .font(.forgeCaption).foregroundColor(.forgeSecondaryText)
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 3)
            .background(Color.forgeElevated)
            Divider().overlay(Color.forgeAccentDim.opacity(0.3))
            HStack {                       // StatusRow2
                Text(formatTokens(tokensUsed))       // "670.8K (67%)"
                Spacer()
                Text(String(format: "$%.2f", cost))
                if let hint {
                    Spacer()
                    Text(hint).foregroundColor(.forgeSecondaryText)
                }
            }
            .font(.forgeCaption).foregroundColor(.forgePrimaryText)
            .padding(.horizontal, 12).padding(.vertical, 3)
            .background(Color.forgeElevated)
        }
    }
    func formatTokens(_ n: Int) -> String {
        let pct = Double(n) / Double(contextWindow) * 100
        if n >= 1_000_000 { return String(format: "%.1fM (%.0f%%)", Double(n)/1e6, pct) }
        if n >= 1_000 { return String(format: "%.1fK (%.0f%%)", Double(n)/1e3, pct) }
        return "\(n) (\(Int(pct))%)"
    }
}
```

---

## 9. Command Palette (verbatim port)

### 9.1 Verbatim behavior (from command-palette.tsx, hash `67287a…`)

```
entries = keymap.getCommandEntries({ namespace:"palette", visibility:"reachable" })
          .filter(cmd.hidden !== true && cmd.name !== "command.palette.show")
options = entries.map { title, desc?, category?, footer?, value: name, suggested, onSelect }
list():
  if filter EMPTY:
      [ suggested options first, value:"suggested:<name>", category:"Suggested" ]
      + ALL options
  else:
      filtered options only (fuzzysort)
onSelect: dialog.clear() THEN dispatchCommand(name)
```

### 9.2 SwiftUI implementation

```swift
struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    let context: SessionContext
    @State private var filter = ""

    private var allEntries: [PaletteEntry] { CommandRegistry.entries(for: context) }
    private var visible: [PaletteEntry] {
        let q = filter.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return allEntries }
        return allEntries.filter { matches($0, q) }      // multi-token AND, case-insensitive
    }
    private var listRows: [PaletteRow] {
        if filter.trimmingCharacters(in: .whitespaces).isEmpty {
            return visible.filter(\.suggested).map { PaletteRow(title: $0.title, category: "Suggested", value: "suggested:\($0.name)", command: $0) }
                 + visible.map { PaletteRow(title: $0.title, category: $0.category, value: $0.name, command: $0) }
        }
        return visible.map { PaletteRow(title: $0.title, category: $0.category, value: $0.name, command: $0) }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { dismiss() }               // ESCAPE EQUIVALENT
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.forgeSecondaryText)
                    TextField("Commands", text: $filter)
                        .font(.forgeBody).foregroundColor(.forgePrimaryText)
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .foregroundColor(.forgeSecondaryText)
                        .accessibilityIdentifier("paletteClose")
                }
                .padding(10).background(Color.forgeSurface)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(listRows, id: \.value) { row in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.category.uppercased())
                                    .font(.forgeCaption).foregroundColor(.forgeAccentBright)
                                    .padding(.horizontal, 12).padding(.top, 8)
                                Button {
                                    dismiss()                    // dialog.clear()
                                    Task { try await CommandRegistry.dispatch(row.command.name, in: context) }
                                } label: {
                                    HStack {
                                        Text("▶").foregroundColor(.forgeAccent)
                                        Text(row.title).foregroundColor(.forgePrimaryText)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                }
                                .accessibilityIdentifier("paletteRow_\(row.value)")
                            }
                        }
                    }
                }
                Text("tap outside to close")
                    .font(.forgeCaption).foregroundColor(.forgeSecondaryText)
                    .frame(maxWidth: .infinity).padding(6)
                    .background(Color.forgeSurface)
            }
            .frame(maxWidth: 320, maxHeight: 0.8 * 874)     // ≤80% bounds (iPhone 17 Pro 402×874)
            .background(Color.forgeElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.forgeAccentDim.opacity(0.4), lineWidth: 1))
        }
    }
}
```

### 9.3 Sizing math (iPhone-first)

| Device | Bounds (pt) | Palette max (80%) |
|---|---|---|
| iPhone 17 Pro | 402 × 874 | 321 × 699 |
| iPhone SE (3rd) | 375 × 667 | 300 × 533 |
| iPad (deferred) | — | — |

Palette frame: `maxWidth: min(bounds.width * 0.8, 360)`, `maxHeight: bounds.height * 0.8`.

---

## 10. Command Registry & Dispatch

### 10.1 Models

```swift
enum CommandCategory: String { case suggested, session, agent, system, workspace, provider }

struct ForgeCommand {
    let name: String
    let title: String
    let desc: String?
    let category: CommandCategory
    let isHidden: Bool                       // verbatim hidden flag
    let suggested: (SessionContext) -> Bool  // boolean or predicate (verbatim)
    let run: (CommandContext) async throws -> Void
}

struct SessionContext {
    let mode: ForgeMode                      // .agent | .missionControl
    let currentSession: SessionInfo?
    let store: SessionStore
    let missionClient: MissionControlClient?
    let presentDialog: (DialogKind) -> Void
    let presentSheet: (SheetKind) -> Void
    let navigateHome: () -> Void             // new session → prompt
    let navigateSession: (String) -> Void    // switch session
}

enum DialogKind { case sessionList, model, agent, prompt(title: String, onSubmit: (String)->Void) }
enum SheetKind { case settings, addServer }
```

### 10.2 Registry (verbatim command set, iOS-adapted)

```swift
final class CommandRegistry {
    // App-level — always reachable
    static let appCommands: [ForgeCommand] = [
        .init(name: "session.new", title: "New session", category: .session,
              suggested: { _ in false },
              run: { ctx in
                  let s = try await ctx.store.create(parentID: nil, title: nil, agent: "trident", model: .deepseekV4Flash)
                  ctx.navigateSession(s.id)      // home prompt focused (verbatim: navigate home, input focused)
              }),
        .init(name: "session.list", title: "Switch session", category: .session,
              suggested: { $0.store.rootsCount > 0 },
              run: { $0.presentDialog(.sessionList) }),
        .init(name: "model.list", title: "Switch model", category: .agent,
              suggested: { _ in true },          // ALWAYS suggested (verbatim)
              run: { $0.presentDialog(.model) }),
        .init(name: "agent.list", title: "Switch agent", category: .agent,
              suggested: { _ in false },
              run: { $0.presentDialog(.agent) }),
        .init(name: "theme.switch", title: "Switch theme", category: .system,
              suggested: { _ in false }, isHidden: true,   // single Fire theme — hidden (verbatim: hidden when 1)
              run: { _ in }),
        .init(name: "settings.open", title: "Settings", category: .system,
              suggested: { _ in false },
              run: { $0.presentSheet(.settings) }),
        .init(name: "workspace.copy_path", title: "Copy worktree path", category: .workspace,
              suggested: { _ in false },
              run: { ctx in UIPasteboard.general.string = ctx.store.demoProjectPath }),
    ]
    // Session-level — only when a session is open
    static let sessionCommands: [ForgeCommand] = [
        .init(name: "session.rename", title: "Rename session", category: .session,
              suggested: { _ in false },
              run: { ctx in
                  let title = ctx.currentSession?.title ?? ""
                  ctx.presentDialog(.prompt(title: title) { newTitle in
                      Task { try await ctx.store.setTitle(ctx.currentSession!.id, newTitle) }
                  })
              }),
    ]
    // Mission-Control-only
    static let missionCommands: [ForgeCommand] = [
        .init(name: "session.view_active", title: "View active sessions", category: .session,
              suggested: { _ in false },
              run: { ctx in ctx.presentDialog(.sessionCarousel) }),
        .init(name: "server.add", title: "Add server", category: .provider,
              suggested: { $0.missionClient?.servers.isEmpty ?? false },
              run: { $0.presentSheet(.addServer) }),
    ]

    static func entries(for ctx: SessionContext) -> [ForgeCommand] {
        var out = appCommands.filter { !$0.isHidden }
        if ctx.currentSession != nil { out += sessionCommands }
        if ctx.mode == .missionControl { out += missionCommands }
        return out
    }
    static func dispatch(_ name: String, in ctx: SessionContext) async throws {
        guard let cmd = entries(for: ctx).first(where: { $0.name == name }) else { return }
        try await cmd.run(ctx)
    }
}
```

### 10.3 Default model constant

```swift
extension ModelRef {
    static let deepseekV4Flash = ModelRef(id: "deepseek-v4-flash", providerID: "zen")
}
// forge-config.json: { "model": "deepseek-v4-flash", "provider": "zen" }
```

---

## 11. Dialog Primitives (verbatim)

### 11.1 DialogSelectOption shape (verbatim from dialog-select.tsx, hash `ae07cd…`)

```swift
struct DialogOption: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let description: String?
    let category: String?
    let suggested: Bool
    let onSelect: (() -> Void)?
}
```

### 11.2 DialogSelectView (generic)

```swift
struct DialogSelectView: View {
    let title: String
    let options: [DialogOption]
    let onClose: () -> Void
    @State private var filter = ""

    var filtered: [DialogOption] {
        let q = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return options }
        let tokens = q.split(separator: " ")
        return options.filter { opt in
            tokens.allSatisfy { tok in
                opt.title.lowercased().contains(tok) || (opt.description?.lowercased().contains(tok) ?? false)
            }
        }
    }
    var grouped: [(String, [DialogOption])] {
        // group by category, preserving order; Suggested group first when filter empty
    }
    // body: same chrome as palette (⌕ input, ScrollView LazyVStack, tap-outside close)
}
```

### 11.3 DialogPromptView (rename)

```swift
struct DialogPromptView: View {
    let title: String
    let initial: String
    let onSubmit: (String) -> Void
    let onClose: () -> Void
    @State private var text = ""
    // body: label + TextField(initial) + [SAVE] button (disabled when trimmed empty)
    //       [SAVE] → onSubmit(trimmed); onClose()
}
```

### 11.4 DialogModelView

Rows grouped FAVORITES / RECENT / ALL PROVIDERS. Source list from opencode Zen models endpoint (see §16.4). Selecting: `store.setAgentModel(id, agent: "trident", model: ref)`; persist recent to UserDefaults `forge.recentModels` (JSON array, max 10).

### 11.5 DialogAgentView

Rows: `trident` (single until Phase-2 vendor). Selecting: `store.setAgentModel(id, agent: name, model: current)`.

### 11.6 DialogSessionListView

Groups TODAY / EARLIER by `time_updated`. Row: title + model + relative time. Tap → `store.get(id)` → `messages(id, limit:50)` → `navigateSession(id)` → `store.touch(id)`.

---

## 12. Session Store (Swift + SQLite3 C API)

```swift
import SQLite3

final class SessionStore: ObservableObject {
    private var db: OpaquePointer?
    @Published private(set) var currentSession: SessionInfo?
    @Published private(set) var roots: [SessionInfo] = []
    private let queue = DispatchQueue(label: "forge.sqlite", qos: .userInitiated)

    init() {
        let path = Self.dbPath()
        sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil)
        execute(SessionSchema.pragmas)      // 6 pragmas
        execute(SessionSchema.ddl)          // project + 7 tables
        seedProjectIfNeeded()
    }

    static func dbPath() -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("opencode.db").path
    }

    // MARK: - Resume (verbatim -c query)
    func loadRoots() {
        queue.async { [weak self] in
            let sql = """
                SELECT * FROM session
                WHERE project_id = ? AND parent_id IS NULL
                ORDER BY time_updated DESC LIMIT 100
            """
            // bind proj_demo → step → map rows → main.async publish roots
        }
    }
    func resumeLatest() -> SessionInfo? { roots.first }

    // MARK: - CRUD
    func create(parentID: String?, title: String?, agent: String?, model: ModelRef?) async throws -> SessionInfo {
        let id = SessionID.descending(.session)
        let title = title ?? defaultTitle(parentID: parentID)
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let modelJSON = model.map { "{\"id\":\"\($0.id)\",\"providerID\":\"\($0.providerID)\"}" } ?? "null"
        // INSERT INTO session (id, project_id, slug, directory, title, version, cost, tokens_*, agent, model, time_created, time_updated)
        // slug = base62(8); version = "1.0.0"; directory = demoProjectPath
        return SessionInfo(id: id, ...)
    }
    func setTitle(_ id: String, _ title: String) async throws {
        // UPDATE session SET title = ?, time_updated = ? WHERE id = ?
    }
    func setAgentModel(_ id: String, agent: String, model: ModelRef) async throws {
        // UPDATE session SET agent = ?, model = ?, time_updated = ? WHERE id = ?
    }
    func touch(_ id: String) {
        // UPDATE session SET time_updated = ? WHERE id = ?
    }
    func remove(_ id: String) {
        // DELETE FROM session WHERE id = ?   (cascades message/part)
    }
    func messages(sessionID: String, limit: Int = 50, before: String? = nil) async throws -> [Message] {
        // SELECT * FROM message WHERE session_id = ? [AND id < ?]
        // ORDER BY time_created DESC, id DESC LIMIT ?   then reversed
    }
    func appendMessage(sessionID: String, data: String) throws -> String {
        let id = SessionID.ascending(.message); let now = nowMs()
        // INSERT INTO message (id, session_id, time_created, time_updated, data)
        return id
    }
    func appendPart(messageID: String, sessionID: String, data: String) throws -> String {
        let id = SessionID.ascending(.part)
        // INSERT INTO part ...
        return id
    }
    func accumulateTokens(sessionID: String, input: Int, output: Int, reasoning: Int, cacheRead: Int, cacheWrite: Int, cost: Double) {
        // UPDATE session SET tokens_input = tokens_input + ?, ..., cost = cost + ?,
        //        time_updated = ? WHERE id = ?
    }
    private func execute(_ sql: String) {
        // sqlite3_exec wrapper; assert SQLITE_OK
    }
}
```

---

## 13. Session Resume Mechanics

### 13.1 "Continue last session" (launch menu)

```
1. SessionStore.loadRoots()          // parent_id IS NULL ORDER BY time_updated DESC LIMIT 100
2. roots.first → navigateSession(id)
3. messages(id, limit: 50)           // page backwards on scroll up
4. touch(id)                         // keeps it first
```

### 13.2 "Switch session" (palette → DialogSessionListView)

```
1. loadRoots() grouped TODAY/EARLIER
2. tap row → get(id) → messages(id, 50) → navigateSession → touch(id)
```

---

## 14. Message Rendering

### 14.1 Glyph contract (verified source: routes/session/index.tsx + spinner.tsx)

| Element | Glyph | ANSI/color |
|---|---|---|
| User message | left-border box (agent color) | accentBright border |
| Assistant text | 3-space indent, markdown | primaryText |
| Reasoning | `Thought: {title} · {duration}` + `-`/`+` | secondary |
| Tool running | braille `⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏` | accentBright |
| Tool completed | `✓` U+2713 | success |
| Tool error | `✗` U+2717 | error |
| Tool pending | `~` | secondary |
| Bash | `$ {command}` | primaryText |

### 14.2 RichMessageRenderer

```swift
struct RichMessageRenderer: View {
    let part: PartPayload        // decoded from part.data
    var body: some View {
        switch part.type {
        case .text:      Text(part.text).font(.forgeTerminal).foregroundColor(.forgePrimaryText).padding(.leading, 12)
        case .reasoning: ReasoningRow(part)   // "Thought: X · 3s" + collapse
        case .tool:      ToolRow(part)        // gutter icon + tool name + status
        case .stepStart, .stepFinish: EmptyView()
        }
    }
}
```

The existing ANSI→AttributedString bridge in `ForgeTerminalView` continues to feed SwiftTerm; RichMessageRenderer is used for the scrollback reconstruction from SQLite (resumed sessions).

---

## 15. Agent Mode Backend (on-device)

### 15.1 Pipeline (verified working Phase 2 — keep)

```
Terminal input → ForgeEngine.sendInput → window.__forgeInput
  → runForgeAgent(prompt) → native httpRequest bridge → LLM (deepseek-v4-flash via zen)
  → parse ```file/```command blocks (or heuristic fallback)
  → writeFile/runCommand bridges → sandbox
  → output ANSI → SwiftTerm
```

### 15.2 New bridge messages (exact contracts)

**JS → Swift** (add to ForgeEngine.userContentController switch):

```jsonc
// reportTokens — after every LLM response
{ "method": "reportTokens",
  "args": { "input": 178, "output": 21, "reasoning": 0,
            "cacheRead": 114, "cacheWrite": 0, "cost": 0.0013 } }
// → SessionStore.accumulateTokens(...) → StatusRow2 updates

// session:header — engine boot / model change
{ "method": "session:header",
  "args": { "title": "FORGE-Demo", "model": "deepseek-v4-flash" } }
// → SessionHeaderRow text update
```

**Swift → JS** (existing evalJS):
```js
window.__forgeConfig = { provider, apiKey, model, baseUrl }   // unchanged (deepseek default)
```

### 15.3 Persistence hooks

- User prompt sent → `appendMessage(sessionID, data: {role:"user",...})`
- Assistant response received → `appendMessage(role:"assistant")` + `appendPart(messageID, data: {type:"text", text:...})` for text, `{type:"tool",...}` for tools
- Session title auto-update: after first user prompt, if `isDefaultTitle(title)` → `setTitle(id, firstPromptPrefix(40))` (verbatim behavior)

---

## 16. Mission Control Backend (remote + spawn)

### 16.1 MissionControlClient

```swift
final class MissionControlClient: ObservableObject {
    @Published var servers: [ServerConnection] = []      // from ConnectionManager (existing)
    @Published var sessions: [RemoteSessionInfo] = []    // polled /api/sessions (existing)
    private let poller = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    // NEW: spawn — POST /session
    func spawnSession(server: ServerConnection, title: String? = nil) async throws -> RemoteSessionInfo {
        var req = URLRequest(url: server.baseURL.appendingPathComponent("session"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(SpawnRequest(
            title: title, agent: "trident", model: "deepseek-v4-flash"))
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 201 else { throw SpawnError.badStatus }
        return try JSONDecoder().decode(RemoteSessionInfo.self, from: data)
    }
}
struct SpawnRequest: Codable {
    let title: String?
    let agent: String
    let model: String
}
```

### 16.2 Spawn flow

```
palette → session.new (MC mode)
  → MissionControlClient.spawnSession(activeServer, title: nil)
  → returns RemoteSessionInfo { id, name, active, lastLines, agent }
  → join via existing RemoteSessionViewModel.connect(ws://server/ws/session/{id})
  → navigate SessionScreen to that session
```

### 16.3 Server-side (mission-control-server.py — in-VM demo)

Add handler:

```python
# POST /session  → create a session, append to SESSIONS, return 201 JSON
if method == "POST" and path == "/session":
    body = json.loads(data.decode().split('\r\n\r\n',1)[-1] or '{}')
    sid = "ses_" + secrets.token_hex(12)
    SESSIONS.insert(0, {
        "id": sid, "name": body.get("title") or f"session-{len(SESSIONS)+1}",
        "active": True, "agent": "trident",
        "lastLines": ["[EXECUTE] session spawned from FORGE iOS"],
    })
    resp = 201 + json.dumps(SESSIONS[0])
```

### 16.4 Model list endpoint (for DialogModelView)

```
GET {zenBase}/models   → {"data":[{"id":"deepseek-v4-flash",...}]}
Filter: ids containing deepseek/minimax/kimi/glm/qwen — sorted alphabetically.
```

---

## 17. Session Card Carousel

```swift
struct SessionCarouselView: View {
    let sessions: [RemoteSessionInfo]
    let onJoin: (RemoteSessionInfo) -> Void
    let onSpawn: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { onClose() }
            VStack(spacing: 0) {
                HStack { Text("ACTIVE SESSIONS"); Spacer(); Button(onClose) { Image(systemName: "xmark") } }
                ScrollView {                      // VERTICAL — obvious scroll
                    LazyVStack(spacing: 10) {
                        ForEach(sessions) { s in SessionCard(session: s, onJoin: { onJoin(s) }) }
                        SpawnCard(onTap: onSpawn)
                    }.padding(12)
                }
                Text("tap outside to close").font(.forgeCaption).foregroundColor(.forgeSecondaryText).padding(6)
            }
            .frame(maxWidth: 340, maxHeight: 0.8 * 874)
            .background(Color.forgeElevated).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
```

Card: status dot (● active / ○ idle) + name + ACTIVE/IDLE pill + host·agent + last-2-lines preview (7pt mono) + relative time + `[JOIN]` button.

---

## 18. Tinder-Swipe Session Switching

```swift
struct TinderSwipeModifier: ViewModifier {
    let sessions: [RemoteSessionInfo]
    @Binding var index: Int
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 15)      // threshold (verbatim direction-lock §18.1)
                    .onChanged { offset = $0.translation.width }
                    .onEnded { g in
                        let velocity = g.predictedEndTranslation.width - g.translation.width
                        let shouldCommit = abs(g.translation.width) > 0.4 * UIScreen.main.bounds.width
                                            || abs(velocity) > 800                    // pt/s
                        if shouldCommit {
                            withAnimation(.easeOut(duration: 0.25)) {
                                if g.translation.width < 0, index < sessions.count - 1 { index += 1 }
                                else if g.translation.width > 0, index > 0 { index -= 1 }
                            }
                        }
                        withAnimation { offset = 0 }
                    }
            )
    }
}
```

Direction-lock coexistence: reuse `DirectionLockPanGesture` — vertical stays terminal scroll, horizontal commits swipe. WS teardown/join on index change via existing `RemoteSessionViewModel`.

---

## 19. Sheets

SettingsSheet: add `zen` provider option; model field default `deepseek-v4-flash`; API key → Keychain `forge.apiKey`. AddServerSheet: unchanged form; Bonjour rows auto-fill name+hostname+port (existing fix).

---

## 20. Launch Menu, App Icon, Launch Screen

### 20.1 Launch menu

```
┌────────────────────────────────────────────────────────────┐
│  F O R G E                                                   │
│  ───────────────────────────────────────────────────────     │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  ⚡  AGENT MODE                                        │  │
│  │  Local coding agent · Fully sandboxed · Runs on-device │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  ◉  MISSION CONTROL                                    │  │
│  │  Pilot your opencode desktop sessions remotely ·        │  │
│  │  Requires pre-existing opencode server active on host   │  │
│  └────────────────────────────────────────────────────────┘  │
│  Continue last session  →                                    │
│  ───────────────────────────────────────────────────────     │
│  v1.0.0                                                      │
└────────────────────────────────────────────────────────────┘
```
Footer = `Bundle.main.infoDictionary?["CFBundleShortVersionString"]` ONLY. Continue → `SessionStore.resumeLatest()`.

### 20.2 App icon

`scripts/generate-icon.mjs`: 1024×1024, bg `#0A0A0F`, bold "F" `#E04307`, flat. Regenerate → Assets.xcassets/AppIcon.

### 20.3 Launch screen

Storyboard label with FORGE block wordmark (5×5 block letters, primaryText). Static in storyboard; `FORGEApp` root plays fade-in 0.3s + spring `scaleEffect(0.95→1.0)` on first appear (`spring(response: 0.4, dampingFraction: 0.8)`).

---

## 21. State Flows

```
LAUNCH ──AGENT MODE──► SESSION(on-device) ──☰──► PALETTE ──► dialogs/sheets/home
LAUNCH ──MISSION CTRL─► SESSION(remote)  ──☰──► PALETTE ──► +view sessions/+add server
SESSION ◄──back── LAUNCH
PALETTE: tap row → dispatch → dismiss; tap outside → dismiss
MC: swipe ⇄ index change → WS switch; pinch-out → carousel → JOIN → switch
```

---

## 22. Concurrency & Lifecycle

### 22.1 SQLite threading

- `SessionStore` serial `queue` (label `forge.sqlite`) — ALL statements execute there
- UI reads via `@Published` published on main after queue hops
- WAL allows concurrent readers; single writer serialized by busy_timeout 5000
- `SQLITE_OPEN_FULLMUTEX` for the handle (defensive)

### 22.2 Lifecycle

| Event | Behavior |
|---|---|
| App background | SessionStore flushes pending writes (queue.sync); WS suspends (existing) |
| App foreground | `loadRoots()` refresh; WS reconnect (existing backoff) |
| Memory warning | SQLite `wal_checkpoint(PASSIVE)`; URLCache removeAll |
| Palette open → background | palette dismissed on foreground (state reset) |

---

## 23. Error Handling

| Error | Behavior |
|---|---|
| SQLite open/exec failure | `assertionFailure` in DEBUG; log + fall back to in-memory DB in release (never crash the app — spec §24) |
| Busy (SQLITE_BUSY) | busy_timeout waits 5s; surface "storage busy" caption if still failing |
| Spawn HTTP failure | red banner in SessionScreen "Failed to spawn session: {reason}" |
| WS disconnect mid-session | existing red "Connection lost — reconnecting…" banner + exp backoff |
| Palette dispatch error | toast (existing) |
| Rename empty | SAVE disabled when trimmed empty |

---

## 24. Performance Budgets

| Operation | Budget |
|---|---|
| Palette filter (50 cmds) | < 16ms (multi-token contains; no fuzzysort dep needed at this scale) |
| Session list render (500 rows) | LazyVStack; first frame < 100ms |
| Resume query | < 10ms (indexed) |
| messages(50) page | < 20ms |
| Token row update | debounced 500ms, no layout thrash |
| SQLite writes | queue-serialized; no main-thread blocking > 5ms |

---

## 25. Accessibility

- Every control has `accessibilityIdentifier` (backButton, menuButton, paletteClose, paletteRow_*, dialogRow_*, joinButton, spawnCard)
- VoiceOver labels: "Open command palette", "Switch session", etc.
- Palette/dialog/carousel: `.accessibilityViewIsModal` + focus trap
- Dynamic Type: captions scale; terminal font fixed (mono)

---

## 26. Risk Register

| Risk | L | I | Mitigation |
|---|---|---|---|
| SQLite3 C API misuse (leaks/corruption) | M | H | Wrapper with prepared statements only; queue-serialized; unit tests on CRUD |
| WAL file growth in sandbox | L | M | Periodic `wal_checkpoint(PASSIVE)` on background |
| Spawn API mismatch (server implements different contract) | M | H | Demo server updated in same wave; contract tests against it |
| Palette port drift (missed verbatim detail) | M | M | Fidelity table (§31) re-checked per wave |
| deepseek-v4-flash rate limits on zen | M | M | Provider list in DialogModel allows fallback models |
| Direction-lock + tinder conflict | M | M | Reuse existing axis-lock; XCUITest both gestures |
| xcodegen misses new files | L | H | `xcodegen generate` on VM; grep pbxproj for new files |

---

## 27. Evidence Output Format

Per wave under `tmp/evidence/ui-v2/`:

| Artifact | Requirement |
|---|---|
| `build.log` | BUILD SUCCEEDED (last 3 lines) |
| `wave{N}-*.png` | screenshots per wave |
| `schema.sql` | W2: `sqlite3 opencode.db .schema` output |
| `session-resume.txt` | W2: resume query output |
| `spawn.json` | W6: POST /session response |
| `ui-overhaul.mp4` | W7: combined Mode 1 + Mode 2 recording |
| `gate_d_manifest.json` | per-wave gate results |

---

## 28. Test Specifications (with code)

### 28.1 Unit tests — SessionIDTests.swift

```swift
func testSessionDescendingSortsNewestFirst() {
    let older = SessionID.descending(.session)
    Thread.sleep(forTimeInterval: 0.002)
    let newer = SessionID.descending(.session)
    XCTAssertLessThan(newer, older)          // lexicographic on time hex
}
func testIDLengthAndFormat() {
    let id = SessionID.descending(.session)
    XCTAssertTrue(id.hasPrefix("ses_"))
    XCTAssertEqual(id.count, 4 + 26)         // "ses_" + 26
}
func testTimestampDecodesAscendingOnly() {
    let m = SessionID.ascending(.message)
    let t = SessionID.timestamp(m)
    XCTAssertLessThan(abs(t - Int64(Date().timeIntervalSince1970 * 1000)), 5000)
}
```

### 28.2 Unit tests — SessionStoreTests.swift

```swift
func testCreateAndResume() async throws {
    let store = SessionStore(inMemory: true)
    let s = try await store.create(parentID: nil, title: nil, agent: "trident", model: .deepseekV4Flash)
    XCTAssertTrue(s.title.hasPrefix("New session - "))
    await store.loadRoots()
    XCTAssertEqual(store.roots.first?.id, s.id)          // newest first
}
func testRenamePersists() async throws {
    let s = try await store.create(...)
    try await store.setTitle(s.id, "osint-iran")
    await store.loadRoots()
    XCTAssertEqual(store.roots.first?.title, "osint-iran")
}
func testTokenAccumulation() async throws {
    let s = try await store.create(...)
    store.accumulateTokens(sessionID: s.id, input: 100, output: 50, reasoning: 0, cacheRead: 10, cacheWrite: 0, cost: 0.01)
    let info = try await store.get(s.id)
    XCTAssertEqual(info.tokens.input, 100)
    XCTAssertEqual(info.tokens.output, 50)
    XCTAssertEqual(info.cost, 0.01, accuracy: 0.0001)
}
func testCascadeDelete() async throws {
    let s = try await store.create(...)
    let m = try store.appendMessage(sessionID: s.id, data: "{}")
    _ = try store.appendPart(messageID: m, sessionID: s.id, data: "{}")
    try await store.remove(s.id)
    // message/part counts for s.id == 0
}
```

### 28.3 Unit tests — CommandRegistryTests.swift

```swift
func testContextualEntries() {
    let agentCtx = SessionContext(mode: .agent, currentSession: nil, ...)
    XCTAssertFalse(CommandRegistry.entries(for: agentCtx).contains { $0.name == "session.view_active" })
    XCTAssertFalse(CommandRegistry.entries(for: agentCtx).contains { $0.name == "server.add" })
    let mcCtx = SessionContext(mode: .missionControl, currentSession: nil, ...)
    XCTAssertTrue(CommandRegistry.entries(for: mcCtx).contains { $0.name == "session.view_active" })
}
func testSuggestedOnlyWhenRelevant() {
    // model.list always suggested; session.list only when roots > 0
}
func testDispatchNewSessionNavigatesHome() async throws {
    // session.new → create called + navigateSession invoked (mock)
}
```

### 28.4 UI tests (XCUITest)

```swift
func testPaletteOpensAndCloses() {
    app.buttons["menuButton"].tap()
    XCTAssertTrue(app.staticTexts["Commands"].waitForExistence(timeout: 5))
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).tap()  // shaded area
    XCTAssertFalse(app.staticTexts["Commands"].exists)
}
func testNewSessionShowsHomePrompt() {
    app.buttons["menuButton"].tap()
    app.buttons["paletteRow_session.new"].tap()
    XCTAssertTrue(app.textFields["terminalInput"].waitForExistence(timeout: 5))
}
func testMissionSwipeSwitchesSession() {
    // MC with 2 sessions: swipe left → subtitle changes session name
}
func testCarouselOpensFromPinch() {
    // pinch out on terminal → "ACTIVE SESSIONS" appears → tap JOIN → session switches
}
func testSpawnAddsSession() {
    // carousel → spawnCard → new session card appears
}
```

### 28.5 Adversarial

| Scenario | Expected |
|---|---|
| Palette open + background | dismissed on foreground, no crash |
| 500 sessions | resume < 50ms, list renders (LazyVStack) |
| Server dies mid-stream | reconnect banner + backoff, no crash |
| Rename empty | SAVE disabled |
| Rapid tinder swipes | last committed wins, no WS crash |
| SQLite concurrent write+read | WAL handles; no SQLITE_BUSY after 5s |

---

## 29. File Manifest

**New (18):** SessionSchema.swift, SessionStore.swift, SessionID.swift, SessionModels.swift, CommandRegistry.swift, ForgeCommand.swift, BottomStatusBarView.swift, SessionHeaderRow.swift, CommandPaletteView.swift, DialogSelectView.swift, DialogPromptView.swift, DialogModelView.swift, DialogAgentView.swift, DialogSessionListView.swift, RichMessageRenderer.swift, SessionCarouselView.swift, TinderSwipeModifier.swift, MissionControlClient.swift

**Modified (13):** ForgeTheme.swift, TopBar.swift, BuildOnDeviceScreen.swift, MissionControlScreen.swift, ForgeEngine.swift, AppState.swift, SettingsSheet.swift, ServerPickerSheet.swift, forge-bundle.js, forge-config.json, LaunchMenuView.swift, mission-control-server.py, scripts/generate-icon.mjs

---

## 30. Implementation Waves (ordered, gated)

| Wave | Scope | Gate (mechanical) |
|---|---|---|
| W1 | Fire theme + icon + bundle ANSI orange | build green; screenshot shows 0 cyan pixels (script: `python3 -c "check pixel #00F0FF absent"`) |
| W2 | SQLite (schema/pragmas/IDs/store/resume) | unit tests 28.1+28.2 pass; `schema.sql` evidence shows 7 tables + 6 pragmas |
| W3 | TopBar ☰ + CommandPaletteView + Registry + DialogSelect | unit 28.3 pass; UI: palette opens/closes/filters |
| W4 | Dialogs (sessionList/model/agent/prompt) + status bars + header | UI: switch/rename/model flows work in sim |
| W5 | Agent wiring: persistence, token accounting, resume, new-session home | agent loop persists to SQLite; status bars live; unit 28.2 full |
| W6 | MC: spawn (server POST /session), view sessions, carousel, tinder | spawn.json evidence; UI 28.4 MC tests pass |
| W7 | Launch menu, continue-last-session, icon, launch screen, evidence pack | combined .mp4; full regression; context docs updated |

Each wave: build green → simulator run → screenshot/video → update BUILD_STATE/TASK_QUEUE/EVIDENCE_STATE.

---

## 31. Compliance Matrix

### 31.1 vs opencode (fidelity)

| opencode | FORGE | Source hash | Wave |
|---|---|---|---|
| command-palette.tsx registry+Suggested+onSelect order | CommandPaletteView | `67287a…` | W3 |
| dialog-select.tsx DialogSelectOption shape + fuzzysort | DialogSelectView | `ae07cd…` | W3 |
| session sql.ts 7 tables + indexes | SessionSchema DDL | `e572ed…` | W2 |
| database.ts 6 pragmas | pragmas | `c44fbd…` | W2 |
| id.ts create/ascending/descending/timestamp | SessionID | `a8f4b8…` | W2 |
| session.ts default titles + isDefaultTitle + fromRow | SessionStore | `83580c…` | W2/W5 |
| -c resume (parent_id IS NULL ORDER BY time_updated DESC) | resumeLatest | verified pattern | W2 |
| glyph set (✓✗braille) | RichMessageRenderer | spinner/index.tsx | W5 |

### 31.2 vs FORGE spec

| Spec § | Requirement | Wave |
|---|---|---|
| §15 Mode 1 layout | 44pt top bar + terminal + accessory | W3-W5 |
| §15.4 keyboard accessory | ESC/CTRL/TAB/arrows | EXISTS |
| §16 Mode 2 | NWBrowser + WS + pager | W6 |
| §18 direction-lock | axis-lock | W6 |
| §20 theme | dark only, tokens | W1 |
| §24 error handling | never crash on recoverable | W2-W7 |

---

## 32. Migration Strategy

### 32.1 Legacy UserDefaults → SQLite

```swift
func migrateLegacySessionsIfNeeded() {
    guard let data = UserDefaults.standard.data(forKey: "forge.sessionsMetadata"),
          let legacy = try? JSONDecoder().decode([LegacySession].self, from: data),
          !legacy.isEmpty else { return }
    for s in legacy {
        try? store.create(title: s.name, agent: "trident", model: .deepseekV4Flash)
    }
    UserDefaults.standard.removeObject(forKey: "forge.sessionsMetadata")
}
```

### 32.2 Rollback

- git tag `phase-2-working-agent` before W1
- SQLite file additive; delete → empty state (never delete sandbox)
- `forge-vm-data` Docker volume NEVER wiped

### 32.3 Deployment order

W1→W2→W3→W4→W5→W6→W7, each wave independently shippable; W7 is the ship gate (combined .mp4 + full regression).

---

**END OF SPEC v2.0**

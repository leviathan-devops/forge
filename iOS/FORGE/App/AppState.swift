import SwiftUI
import Combine

// MARK: - Forge Mode

/// The two primary operational modes of the FORGE app.
///
/// `rawValue` is the stable internal + Codable identity (also used as the
/// `accessibilityIdentifier` so UI tests stay green). `displayName` is the
/// spec §20.1 card title shown to the user.
enum ForgeMode: String, CaseIterable, Codable {
    case onDevice = "BUILD ON-DEVICE"
    case missionControl = "MISSION CONTROL"

    /// Card title shown to the user (spec §20.1).
    var displayName: String {
        switch self {
        case .onDevice:       return "AGENT MODE"
        case .missionControl: return "MISSION CONTROL"
        }
    }

    /// Human-readable description shown on the mode card (spec §20.1).
    var subtitle: String {
        switch self {
        case .onDevice:
            return "Local coding agent · Fully sandboxed · Runs on-device"
        case .missionControl:
            // Shortened (operator directive 2026-08-29): must fit 3 lines on
            // the card, not 4.
            return "Pilot remote opencode sessions · Requires an active host server"
        }
    }

    /// SF Symbol icon name for the mode card.
    var icon: String {
        switch self {
        case .onDevice:
            return "bolt.fill"
        case .missionControl:
            return "antenna.radiowaves.left.and.right"
        }
    }
}

// MARK: - Project Model

/// A code project managed by FORGE.
struct ForgeProject: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var path: String
    var createdAt: Date
    var lastAccessed: Date
    var language: String
    var framework: String

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        language: String = "Swift",
        framework: String = "SwiftUI"
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.createdAt = Date()
        self.lastAccessed = Date()
        self.language = language
        self.framework = framework
    }
}

// MARK: - Server Model

/// A remote OpenCode server connection.
struct ForgeServer: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var isSecure: Bool
    var lastConnected: Date?
    var isActive: Bool

    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 3000,
        isSecure: Bool = false
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.isSecure = isSecure
        self.lastConnected = nil
        self.isActive = false
    }

    /// Full WebSocket URL string.
    var urlString: String {
        "\(isSecure ? "wss" : "ws")://\(host):\(port)"
    }

    /// HTTP base URL for REST calls.
    var httpURLString: String {
        "\(isSecure ? "https" : "http")://\(host):\(port)"
    }

    /// Display-friendly address string.
    var displayAddress: String {
        "\(host):\(port)"
    }
}

// MARK: - Session Model

/// A coding agent session within a project.
struct ForgeSession: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var projectID: UUID?
    var createdAt: Date
    var lastActivity: Date
    var messageCount: Int
    var status: SessionStatus

    enum SessionStatus: String, Codable {
        case active
        case idle
        case completed
        case archived

        var displayName: String {
            rawValue.capitalized
        }

        var color: SwiftUI.Color {
            switch self {
            case .active:    return .forgeSuccess
            case .idle:      return .forgeSecondaryText
            case .completed: return .forgeAccent
            case .archived:  return .forgeSecondaryText
            }
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        projectID: UUID? = nil,
        messageCount: Int = 0,
        status: SessionStatus = .idle
    ) {
        self.id = id
        self.title = title
        self.projectID = projectID
        self.createdAt = Date()
        self.lastActivity = Date()
        self.messageCount = messageCount
        self.status = status
    }
}

// MARK: - API Provider

/// Supported LLM API providers.
enum APIProvider: String, CaseIterable, Codable, Identifiable {
    case anthropic = "Anthropic"
    case openai = "OpenAI"
    case local = "Local (Ollama)"
    case custom = "Custom"

    var id: String { rawValue }

    /// The default model identifier for this provider.
    var defaultModel: String {
        switch self {
        case .anthropic: return ZenModelCatalog.defaultModelID
        case .openai:    return ZenModelCatalog.defaultModelID
        case .local:     return "llama3.2"
        case .custom:    return ""
        }
    }

    /// Whether an API key is required for this provider.
    var requiresAPIKey: Bool {
        switch self {
        case .anthropic, .openai: return true
        case .local, .custom:     return false
        }
    }

    /// SF Symbol for the provider.
    var icon: String {
        switch self {
        case .anthropic: return "brain.head.profile"
        case .openai:    return "sparkles"
        case .local:     return "server.rack"
        case .custom:    return "wrench.adjustable"
        }
    }
}

// MARK: - App State

/// The central observable state for the entire FORGE application.
/// Manages navigation, projects, servers, sessions, and settings persistence.
@MainActor
final class AppState: ObservableObject {

    // MARK: Navigation State

    @Published var selectedMode: ForgeMode?
    @Published var showingLaunchMenu: Bool = true
    /// Set by continueLastSession() — BuildOnDeviceScreen adopts this session
    /// (sets currentSessionID) and restores its persisted transcript instead
    /// of creating a fresh session (transcript-persistence resume wiring).
    @Published var pendingResumeSession: SessionInfo?
    @Published var showingSettings: Bool = false
    @Published var showingProjectManager: Bool = false
    @Published var showingServerConnection: Bool = false

    // MARK: Data Models

    @Published var currentProject: ForgeProject?
    @Published var projects: [ForgeProject] = []

    @Published var servers: [ForgeServer] = []
    @Published var connectedServer: ForgeServer?

    @Published var sessions: [ForgeSession] = []
    @Published var currentSession: ForgeSession?

    /// SQLite-backed session store (spec §20.1 continue-last-session).
    /// Owned here so the launch menu can resume the latest root session.
    /// Cache is warmed in `init()` so `resumeLatest()` is ready on demand.
    let sessionStore = SessionStore()

    // MARK: Settings

    @Published var apiProvider: APIProvider = .openai
    @Published var apiKey: String = ""
    @Published var modelName: String = ZenModelCatalog.defaultModelID
    @Published var apiBaseUrl: String = ""
    @Published var gitUserName: String = ""
    @Published var gitUserEmail: String = ""

    // MARK: Computed

    /// The most recently active session, if any.
    var lastSession: ForgeSession? {
        sessions
            .filter { $0.status == .active || $0.status == .idle }
            .max(by: { $0.lastActivity < $1.lastActivity })
    }

    /// Whether the user has any configurable settings saved.
    var hasConfiguredSettings: Bool {
        !apiKey.isEmpty || apiProvider == .local || apiProvider == .custom
    }

    // MARK: Initialization

    init() {
        loadSettings()
        loadProjects()
        loadSessions()
        loadServers()
        // Warm the SQLite root-session cache so resumeLatest() is ready when
        // the user taps "Continue last session" (spec §20.1).
        sessionStore.loadRoots()
        applyAgentLaunchOverrides()
        Task { [weak self] in
            await ZenModelCatalog.shared.refresh()
            await MainActor.run {
                self?.migrateModelToLiveCatalog()
            }
        }
    }

    /// Drop retired / vanished zen ids after a live GET /v1/models.
    /// Operator lockdown: the single allowed model is never migrated away —
    /// paid Go ids need not appear in the public live list to stay valid.
    func migrateModelToLiveCatalog() {
        if modelName == ZenModelCatalog.allowedModelID { return }
        let live = ZenModelCatalog.shared.entries
        if live.isEmpty { return }
        if ZenModelCatalog.isRetired(modelName) || !live.contains(where: { $0.id == modelName }) {
            modelName = live.first?.id ?? ZenModelCatalog.defaultModelID
            UserDefaults.standard.set(modelName, forKey: ForgeSettingsKeys.modelName)
        }
    }

    /// Agent/SSH sim path: open Mode1 or Mode2 without UI taps.
    ///
    /// simctl does **not** support `--setenv`. Export into the caller env with
    /// `SIMCTL_CHILD_` prefix, e.g.:
    ///   `SIMCTL_CHILD_FORGE_START_MODE=onDevice xcrun simctl launch booted com.forge.app`
    /// Also accepts UserDefaults key `FORGE_START_MODE` (set via
    /// `xcrun simctl spawn booted defaults write com.forge.app FORGE_START_MODE onDevice`).
    private func applyAgentLaunchOverrides() {
        let env = ProcessInfo.processInfo.environment
        // N2: continuous IN-APP navigation — menu → Mode1 → menu → MC →
        // menu → Mode1 → menu, all without relaunch (one process, mode
        // switches through selectMode/returnToLaunchMenu — the same paths
        // the UI cards + back buttons drive).
        if env["FORGE_TEST_NAV_FLOW"] == "1" || env["SIMCTL_CHILD_FORGE_TEST_NAV_FLOW"] == "1" {
            let steps: [(Double, ForgeMode?)] = [
                (3.0, .onDevice), (10.0, nil),
                (17.0, .missionControl), (24.0, nil),
                (31.0, .onDevice), (38.0, nil)
            ]
            for (delay, mode) in steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self else { return }
                    if let mode {
                        self.selectMode(mode)
                    } else {
                        self.returnToLaunchMenu()
                    }
                }
            }
        }
        // FULL E2E (one process, no relaunch):
        //   t+3   Mode-1 (FORGE_TEST_PROMPT runs the agent turn)
        //   preview opens 2s AFTER forgeTurnComplete (BuildOnDeviceScreen)
        //   post-turn chain fires 20s AFTER forgeTurnComplete — the preview
        //   has been up 18s by then — then launch menu → Mission Control.
        //   Fallback at t+180 covers a hung/failed turn (the tape still walks).
        //   (Fixed t+50/58/100 timers assumed a 12s turn; free-zen turns run
        //   45-60s+ and the script was robbing the turn mid-flight — the
        //   race the vil-e2e tape caught at ~t+50.)
        if env["FORGE_TEST_FULL_E2E"] == "1" || env["SIMCTL_CHILD_FORGE_TEST_FULL_E2E"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.selectMode(.onDevice)
            }
            var postTurnFired = false
            let postTurn: () -> Void = { [weak self] in
                guard let self, !postTurnFired else { return }
                postTurnFired = true
                // +25s: return to menu (preview has been visible ~23s — fixed from 2s that robbed ViL).
                DispatchQueue.main.asyncAfter(deadline: .now() + 25.0) { [weak self] in
                    self?.returnToLaunchMenu()
                }
                // +31s: Mission Control (connect + session list + swipe + Eagle).
                DispatchQueue.main.asyncAfter(deadline: .now() + 31.0) { [weak self] in
                    self?.selectMode(.missionControl)
                }
                // Hold MC, then back to menu. 48s standard; 75s when the MC
                // Eagle hook is set (Eagle fires at MC+32 — 48s cut it off).
                let mcHold: Double = (env["FORGE_TEST_MC_EAGLE"] == "1" || env["SIMCTL_CHILD_FORGE_TEST_MC_EAGLE"] == "1") ? 75.0 : 48.0
                DispatchQueue.main.asyncAfter(deadline: .now() + mcHold) { [weak self] in
                    self?.returnToLaunchMenu()
                }
            }
            let token = NotificationCenter.default.addObserver(
                forName: .forgeTurnComplete, object: nil, queue: .main
            ) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 20.0, execute: postTurn)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 180.0) { [weak self] in
                NotificationCenter.default.removeObserver(token)
                postTurn()
            }
        }
        // Test hook: drive the "Continue last session" path headlessly (J3).
        if env["FORGE_TEST_CONTINUE_LAST"] == "1" || env["SIMCTL_CHILD_FORGE_TEST_CONTINUE_LAST"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.continueLastSession()
            }
        }
        let fromEnv = env["FORGE_START_MODE"]
            ?? env["SIMCTL_CHILD_FORGE_START_MODE"]
        let fromDefaults = UserDefaults.standard.string(forKey: "FORGE_START_MODE")
        // WAVE 3 launch-BAR slot: if a live TEST_PROMPT is set and START_MODE
        // is unset, paint the launch menu first (~5s), then enter Mode 1.
        // START_MODE=onDevice skips launch (t9 t00 was SpringBoard).
        let prompt = env["FORGE_TEST_PROMPT"] ?? env["SIMCTL_CHILD_FORGE_TEST_PROMPT"] ?? ""
        if prompt.isEmpty == false && (fromEnv ?? fromDefaults ?? "").isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.selectMode(.onDevice)
            }
        }
        guard let raw = (fromEnv ?? fromDefaults)?.lowercased(), !raw.isEmpty else { return }
        switch raw {
        case "ondevice", "on-device", "mode1", "build", "build-on-device":
            selectedMode = .onDevice
            showingLaunchMenu = false
        case "missioncontrol", "mission-control", "mode2", "mission":
            selectedMode = .missionControl
            showingLaunchMenu = false
        default:
            break
        }
    }

    // MARK: - Navigation Actions

    /// Select and transition to a mode.
    func selectMode(_ mode: ForgeMode) {
        ForgeHaptic.impact(.medium)
        withAnimation(ForgeAnimation.cardTap) {
            selectedMode = mode
            showingLaunchMenu = false
        }
    }

    /// Return to the launch menu from any mode.
    func returnToLaunchMenu() {
        ForgeHaptic.impact(.light)
        withAnimation(ForgeAnimation.standard) {
            selectedMode = nil
            showingLaunchMenu = true
        }
    }

    /// Continue the last active session (spec §20.1).
    ///
    /// Tries the new SQLite-backed store first (`resumeLatest()`); if that
    /// yields a session, drops into on-device mode. Otherwise falls back to
    /// the legacy UserDefaults-backed `lastSession` (migration safety net).
    func continueLastSession() {
        // New path — SQLite root sessions (warm cache from init).
        if let sqliteSession = sessionStore.resumeLatest() {
            ForgeHaptic.impact(.light)
            currentSession = nil
            selectedMode = .onDevice
            showingLaunchMenu = false
            pendingResumeSession = sqliteSession // the screen adopts + restores the transcript
            return
        }

        // Legacy path — UserDefaults-backed sessions (migration fallback).
        guard let session = lastSession else {
            ForgeHaptic.notify(.warning)
            return
        }

        ForgeHaptic.impact(.light)
        currentSession = session

        if let projectID = session.projectID {
            currentProject = projects.first(where: { $0.id == projectID })
            selectedMode = .onDevice
        } else {
            selectedMode = .missionControl
        }

        showingLaunchMenu = false
    }

    // MARK: - Settings Persistence

    /// Save all settings to UserDefaults and Keychain.
    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(apiProvider.rawValue, forKey: ForgeSettingsKeys.apiProvider)
        defaults.set(modelName, forKey: ForgeSettingsKeys.modelName)
        let trimmedBaseUrl = apiBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBaseUrl.isEmpty {
            defaults.removeObject(forKey: ForgeSettingsKeys.apiBaseUrl)
        } else {
            defaults.set(trimmedBaseUrl, forKey: ForgeSettingsKeys.apiBaseUrl)
        }
        defaults.set(gitUserName, forKey: ForgeSettingsKeys.gitUserName)
        defaults.set(gitUserEmail, forKey: ForgeSettingsKeys.gitUserEmail)

        // Store API key securely in Keychain (delegates to Security/KeychainHelper.swift)
        if !apiKey.isEmpty {
            try? KeychainHelper.save(apiKey, for: ForgeSettingsKeys.apiKey)
        } else {
            KeychainHelper.delete(for: ForgeSettingsKeys.apiKey)
        }
    }

    /// Load settings from UserDefaults and Keychain.
    func loadSettings() {
        let defaults = UserDefaults.standard

        if let providerRaw = defaults.string(forKey: ForgeSettingsKeys.apiProvider),
           let provider = APIProvider(rawValue: providerRaw) {
            apiProvider = provider
        }

        let storedModel = defaults.string(forKey: ForgeSettingsKeys.modelName) ?? apiProvider.defaultModel
        modelName = ZenModelCatalog.isRetired(storedModel)
            ? ZenModelCatalog.defaultModelID
            : storedModel
        apiBaseUrl = defaults.string(forKey: ForgeSettingsKeys.apiBaseUrl) ?? ""
        gitUserName = defaults.string(forKey: ForgeSettingsKeys.gitUserName) ?? ""
        gitUserEmail = defaults.string(forKey: ForgeSettingsKeys.gitUserEmail) ?? ""
        apiKey = KeychainHelper.loadSync(for: ForgeSettingsKeys.apiKey) ?? ""
    }

    // MARK: - Project Management

    /// The filesystem directory where projects are stored.
    var projectsDirectory: URL {
        let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first
            ?? FileManager.default.temporaryDirectory
        return docs.appendingPathComponent("projects")
    }

    /// Load project metadata from UserDefaults.
    func loadProjects() {
        let fm = FileManager.default

        if !fm.fileExists(atPath: projectsDirectory.path) {
            try? fm.createDirectory(at: projectsDirectory, withIntermediateDirectories: true)
        }

        if let data = UserDefaults.standard.data(forKey: ForgeSettingsKeys.projectsMetadata),
           let decoded = try? JSONDecoder().decode([ForgeProject].self, from: data) {
            projects = decoded.sorted(by: { $0.lastAccessed > $1.lastAccessed })
        }
    }

    /// Create a new project on disk and in state.
    @discardableResult
    func createProject(name: String, language: String, framework: String) -> ForgeProject {
        let projectPath = projectsDirectory.appendingPathComponent(name)
        let project = ForgeProject(
            name: name,
            path: projectPath.path,
            language: language,
            framework: framework
        )

        let fm = FileManager.default
        try? fm.createDirectory(at: projectPath, withIntermediateDirectories: true)

        projects.insert(project, at: 0)
        persistProjects()
        currentProject = project

        // Create a default session for the project
        let session = ForgeSession(
            title: "\(name) — Session 1",
            projectID: project.id
        )
        sessions.insert(session, at: 0)
        persistSessions()

        return project
    }

    /// Open an existing project (updates lastAccessed).
    func openProject(_ project: ForgeProject) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].lastAccessed = Date()
            persistProjects()
        }
        currentProject = project
    }

    /// Delete a project from disk and state.
    func deleteProject(_ project: ForgeProject) {
        let fm = FileManager.default
        let projectDir = projectsDirectory.appendingPathComponent(project.name)
        try? fm.removeItem(at: projectDir)

        projects.removeAll(where: { $0.id == project.id })
        sessions.removeAll(where: { $0.projectID == project.id })
        persistProjects()
        persistSessions()

        if currentProject?.id == project.id {
            currentProject = nil
        }
    }

    /// Persist project array to UserDefaults.
    private func persistProjects() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: ForgeSettingsKeys.projectsMetadata)
        }
    }

    // MARK: - Session Management

    /// Load session metadata from UserDefaults.
    func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: ForgeSettingsKeys.sessionsMetadata),
           let decoded = try? JSONDecoder().decode([ForgeSession].self, from: data) {
            sessions = decoded.sorted(by: { $0.lastActivity > $1.lastActivity })
        }
    }

    /// Create a new session.
    @discardableResult
    func createSession(title: String, projectID: UUID? = nil) -> ForgeSession {
        let session = ForgeSession(title: title, projectID: projectID, status: .active)
        sessions.insert(session, at: 0)
        persistSessions()
        return session
    }

    /// Update session activity timestamp.
    func touchSession(_ session: ForgeSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].lastActivity = Date()
            sessions[index].messageCount += 1
            persistSessions()
        }
    }

    /// Persist session array to UserDefaults.
    private func persistSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: ForgeSettingsKeys.sessionsMetadata)
        }
    }

    // MARK: - Server Management

    /// Add a server to the list.
    func addServer(_ server: ForgeServer) {
        servers.append(server)
        persistServers()
    }

    /// Remove a server from the list.
    func removeServer(_ server: ForgeServer) {
        servers.removeAll(where: { $0.id == server.id })
        if connectedServer?.id == server.id {
            connectedServer = nil
        }
        persistServers()
    }

    /// Mark a server as connected.
    func connectToServer(_ server: ForgeServer) {
        connectedServer = server
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index].isActive = true
            servers[index].lastConnected = Date()
        }
        persistServers()
    }

    /// Load servers from UserDefaults.
    func loadServers() {
        if let data = UserDefaults.standard.data(forKey: ForgeSettingsKeys.serversMetadata),
           let decoded = try? JSONDecoder().decode([ForgeServer].self, from: data) {
            servers = decoded
        }
    }

    /// Persist server array to UserDefaults.
    private func persistServers() {
        if let data = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(data, forKey: ForgeSettingsKeys.serversMetadata)
        }
    }
}

// MARK: - Settings Keys

enum ForgeSettingsKeys {
    static let apiProvider       = "forge.apiProvider"
    static let apiKey            = "forge.apiKey"
    static let modelName         = "forge.modelName"
    static let apiBaseUrl        = "forge.apiBaseUrl"
    static let gitUserName       = "forge.gitUserName"
    static let gitUserEmail      = "forge.gitUserEmail"
    static let projectsMetadata  = "forge.projectsMetadata"
    static let sessionsMetadata  = "forge.sessionsMetadata"
    static let serversMetadata   = "forge.serversMetadata"
}

// KeychainHelper is defined in Security/KeychainHelper.swift.
// It is a struct with static methods: save(_:for:) throws, loadSync(for:), delete(for:), exists(for:).

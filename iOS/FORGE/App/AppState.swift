import SwiftUI
import Combine

// MARK: - Forge Mode

/// The two primary operational modes of the FORGE app.
enum ForgeMode: String, CaseIterable, Codable {
    case onDevice = "BUILD ON-DEVICE"
    case missionControl = "MISSION CONTROL"

    /// Human-readable description shown on the mode card.
    var subtitle: String {
        switch self {
        case .onDevice:
            return "Run coding agents locally on your device"
        case .missionControl:
            return "Connect to remote OpenCode servers"
        }
    }

    /// SF Symbol icon name for the mode card.
    var icon: String {
        switch self {
        case .onDevice:
            return "iphone.radiowaves.left.and.right"
        case .missionControl:
            return "network"
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
        case .anthropic: return "claude-sonnet-4-20250514"
        case .openai:    return "gpt-4o"
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

    // MARK: Settings

    @Published var apiProvider: APIProvider = .anthropic
    @Published var apiKey: String = ""
    @Published var modelName: String = "claude-sonnet-4-20250514"
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

    /// Continue the last active session.
    func continueLastSession() {
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

        modelName = defaults.string(forKey: ForgeSettingsKeys.modelName) ?? apiProvider.defaultModel
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
    static let gitUserName       = "forge.gitUserName"
    static let gitUserEmail      = "forge.gitUserEmail"
    static let projectsMetadata  = "forge.projectsMetadata"
    static let sessionsMetadata  = "forge.sessionsMetadata"
    static let serversMetadata   = "forge.serversMetadata"
}

// KeychainHelper is defined in Security/KeychainHelper.swift.
// It is a struct with static methods: save(_:for:) throws, loadSync(for:), delete(for:), exists(for:).

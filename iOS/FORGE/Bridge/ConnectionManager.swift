import Foundation
import Network
import Combine

/// ConnectionManager
///
/// Per FORGE Engineering Specification §12.2 and §16.
///
/// An `ObservableObject` that drives Mission Control's connectivity:
/// - Bonjour discovery of `_opencode._tcp` servers via `NWBrowser`.
/// - A list of manually-added servers (persisted to UserDefaults).
/// - Polling each connected server's `/session` endpoint every 10 s to
///   refresh the live session list.
/// - Creating and tracking a `RemoteSessionViewModel` for each active
///   WebSocket session.
///
/// Discovery results and the session list are `@Published` so SwiftUI views
/// update automatically.
final class ConnectionManager: ObservableObject {

    // MARK: - Published state

    /// Servers discovered via Bonjour on the local network / Tailscale mesh.
    @Published var discoveredServers: [DiscoveredServer] = []

    /// Manually-added servers (persisted). Each is a stable connection target.
    @Published var savedServers: [ServerConnection] = []

    /// All known sessions across all connected servers.
    @Published var sessions: [RemoteSession] = []

    /// Connection status per server, keyed by server id.
    @Published var serverStatus: [String: ConnectionStatus] = [:]

    // MARK: - Models

    /// A Bonjour-discovered server.
    struct DiscoveredServer: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let endpoint: NWEndpoint
        /// The service type that produced this entry ("_opencode._tcp" or
        /// "_http._tcp") — used to merge per-type browse results.
        var browseType: String = ""
    }

    /// A persistable server connection definition.
    struct ServerConnection: Identifiable, Codable, Hashable {
        var id: UUID
        var name: String
        var hostname: String
        var port: Int
        var bearerToken: String?
        var useTLS: Bool

        init(
            id: UUID = UUID(),
            name: String,
            hostname: String,
            port: Int = 8080,
            bearerToken: String? = nil,
            useTLS: Bool = false
        ) {
            self.id = id
            self.name = name
            self.hostname = hostname
            self.port = port
            self.bearerToken = bearerToken
            self.useTLS = useTLS
        }

        var baseURL: String {
            "\(useTLS ? "https" : "http")://\(hostname):\(port)"
        }
        var wsURL: String {
            "\(useTLS ? "wss" : "ws")://\(hostname):\(port)"
        }
    }

    /// Connection status for a server.
    enum ConnectionStatus: Equatable {
        case connecting
        case connected
        case disconnected
        case error(String)
    }

    // MARK: - Private state

    private var browser: NWBrowser?
    private var pollTimer: DispatchSourceTimer?
    private let pollQueue = DispatchQueue(label: "forge.connection.poll", qos: .utility)
    private let storageKey = "forge_saved_servers"

    // MARK: - Init

    init() {
        loadServers()
        // CI test hook: FORGE_TEST_SERVER="host:port" auto-adds a server
        // (same pattern as FORGE_TEST_PROMPT — used for automated Mission
        // Control end-to-end tests + screen recordings). SIMCTL_CHILD_ variant
        // included: tape launches prefix hook vars (E1 dual-read, Wave 4).
        let simEnv = ProcessInfo.processInfo.environment
        if let testServer = (simEnv["FORGE_TEST_SERVER"] ?? simEnv["SIMCTL_CHILD_FORGE_TEST_SERVER"]),
           !testServer.isEmpty {
            let parts = testServer.split(separator: ":")
            if parts.count >= 1 {
                let host = String(parts[0])
                let port = parts.count >= 2 ? Int(parts[1]) ?? 8080 : 8080
                let server = ServerConnection(
                    id: UUID(),
                    name: host,
                    hostname: host,
                    port: port
                )
                if !savedServers.contains(where: { $0.hostname == host && $0.port == port }) {
                    savedServers.append(server)
                    serverStatus[server.id.uuidString] = .disconnected
                    // PERSIST like the human path (connect-persistence bug,
                    // 2026-08-15): the auto-add never saved, and its in-memory
                    // entry then tripped the dedupe guard in addServer() so
                    // the form-submit's saveServers() never ran either — the
                    // server was forgotten on every relaunch.
                    saveServers()
                }
            }
        }
    }

    // MARK: - Server persistence

    func loadServers() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([ServerConnection].self, from: data) else {
            savedServers = []
            return
        }
        savedServers = decoded
        for server in savedServers {
            serverStatus[server.id.uuidString] = .disconnected
        }
    }

    func saveServers() {
        if let data = try? JSONEncoder().encode(savedServers) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func addServer(_ server: ServerConnection) {
        guard !savedServers.contains(where: { $0.hostname == server.hostname && $0.port == server.port }) else {
            return
        }
        savedServers.append(server)
        serverStatus[server.id.uuidString] = .disconnected
        saveServers()
    }

    func removeServer(_ server: ServerConnection) {
        savedServers.removeAll { $0.id == server.id }
        serverStatus.removeValue(forKey: server.id.uuidString)
        sessions.removeAll { $0.server.id == server.id }
        saveServers()
    }

    // MARK: - Bonjour discovery (§12.2)

    /// Starts browsing for opencode serves.
    ///
    /// BUG-F1 (fixed 2026-08-11): opencode's `--mdns` flag publishes its
    /// instance as `opencode-<port>` under `_http._tcp` (avahi "Web Site"),
    /// NOT under `_opencode._tcp`. The old code browsed only `_opencode._tcp`
    /// — a type nothing publishes — so auto-discovery could never find a real
    /// serve. We now browse BOTH types and filter `_http._tcp` results to
    /// instance names with the `opencode-` prefix.
    func startDiscovery() {
        guard browser == nil else { return }
        startBonjourBrowse(type: "_opencode._tcp", filterOpencodeInstances: false)
        startBonjourBrowse(type: "_http._tcp", filterOpencodeInstances: true)
    }

    /// Per-type browsers (keyed by service type for clean stop/merge).
    private var browsers: [String: NWBrowser] = [:]

    private func startBonjourBrowse(type: String, filterOpencodeInstances: Bool) {
        let params = NWParameters()
        params.includePeerToPeer = true
        let descriptor = NWBrowser.Descriptor.bonjour(type: type, domain: nil)
        let newBrowser = NWBrowser(for: descriptor, using: params)

        newBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                var found: [DiscoveredServer] = []
                for result in results {
                    if case .service(let name, _, _, _) = result.endpoint {
                        if filterOpencodeInstances && !name.hasPrefix("opencode-") {
                            continue
                        }
                        found.append(DiscoveredServer(name: name, endpoint: result.endpoint))
                    }
                }
                // Replace this type's entries, keep the other type's.
                let others = self.discoveredServers.filter { $0.browseType != type }
                self.discoveredServers = others + found.map { server in
                    DiscoveredServer(name: server.name, endpoint: server.endpoint, browseType: type)
                }
            }
        }

        newBrowser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error):
                DispatchQueue.main.async {
                    self?.serverStatus["__discovery_\(type)__"] = .error(error.localizedDescription)
                }
            default:
                break
            }
        }

        newBrowser.start(queue: .main)
        browsers[type] = newBrowser
        browser = newBrowser
    }

    func stopDiscovery() {
        browsers.values.forEach { $0.cancel() }
        browsers.removeAll()
        browser = nil
    }

    // MARK: - Session polling (§16.1)

    /// Begins polling every saved server for its session list at a 10 s
    /// interval. Each server's `/session` is fetched and the
    /// `sessions` array is rebuilt.
    func startSessionPolling() {
        guard pollTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: pollQueue)
        timer.schedule(deadline: .now(), repeating: 10.0)
        timer.setEventHandler { [weak self] in
            self?.refreshAllSessions()
        }
        timer.resume()
        pollTimer = timer
    }

    func stopSessionPolling() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    /// Fetches the session list from every saved server in parallel.
    private func refreshAllSessions() {
        for server in savedServers {
            refreshSessions(for: server)
        }
    }

    func refreshSessions(for server: ServerConnection) {
        // REAL opencode server exposes GET /session (NOT /api/sessions —
        // that path serves the web UI on real opencode serve).
        guard let url = URL(string: "\(server.baseURL)/session") else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        if let token = server.bearerToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        DispatchQueue.main.async {
            self.serverStatus[server.id.uuidString] = .connecting
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.serverStatus[server.id.uuidString] = .error(error.localizedDescription)
                    return
                }
                guard let resp = response as? HTTPURLResponse, resp.statusCode == 200 else {
                    self?.serverStatus[server.id.uuidString] = .disconnected
                    return
                }
                self?.serverStatus[server.id.uuidString] = .connected
            }

            guard let data = data else {
                NSLog("[MC] no data from %@", server.hostname)
                return
            }
            // Try the REAL opencode session shape first, then the legacy spec shape.
            do {
                let real = try JSONDecoder().decode([OpenCodeServerSession].self, from: data)
                let mapped = real.map { info in
                    RemoteSessionInfo(
                        id: info.id,
                        name: (info.title?.isEmpty ?? true) ? (info.slug ?? info.id) : info.title!,
                        active: true,
                        lastLines: nil,
                        agent: info.agent,
                        phase: nil,
                        timeCreated: info.time?.created,
                        timeUpdated: info.time?.updated
                    )
                }
                NSLog("[MC] decoded %d real sessions from %@", mapped.count, server.hostname)
                DispatchQueue.main.async {
                    self?.mergeSessions(infos: mapped, server: server)
                    NSLog("[MC] merged, total sessions now %d", self?.sessions.count ?? -1)
                }
            } catch {
                // Try the legacy shape; if that also fails, log for diagnosis.
                if let legacy = try? JSONDecoder().decode([RemoteSessionInfo].self, from: data) {
                    DispatchQueue.main.async {
                        self?.mergeSessions(infos: legacy, server: server)
                    }
                } else {
                    NSLog("[MC] decode failed for %@: %@", server.hostname, String(describing: error))
                }
            }
        }.resume()
    }

    /// Reconciles the fetched session list with the published `sessions`.
    /// STABLE MERGE (fix 2026-08-11): existing sessions are patched IN PLACE
    /// so their positions never change — the pager's `currentIndex` stays on
    /// the session the user is viewing. Brand-new sessions are prepended
    /// (the server returns newest-first). A wholesale replace made the
    /// visible page jump to a different session on every 10s poll.
    private func mergeSessions(infos: [RemoteSessionInfo], server: ServerConnection) {
        let others = sessions.filter { $0.server.id != server.id }
        let fetched = infos.map { info in
            RemoteSession(info: info, server: server)
        }
        let fetchedByID = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        // Patch in place: keep every existing session, updated from the fetch.
        let existing = sessions
            .filter { $0.server.id == server.id }
            .compactMap { old in fetchedByID[old.id] ?? old }
        // Genuinely new sessions go on top (newest-first server order).
        let fresh = fetched.filter { new in
            !existing.contains { $0.id == new.id }
        }
        sessions = others + fresh + existing
    }

    // MARK: - Lifecycle

    func start() {
        startDiscovery()
        startSessionPolling()
    }

    func stop() {
        stopDiscovery()
        stopSessionPolling()
    }
}

// MARK: - Remote Session Models

/// Lightweight session metadata normalized from the live `/session` response.
struct RemoteSessionInfo: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var active: Bool
    var lastLines: [String]?
    var agent: String?
    var phase: String?
    var timeCreated: Int64?
    var timeUpdated: Int64?
}

/// REAL opencode server session (GET /session + POST /session responses on
/// opencode serve). Field names match the live server — no mock shapes.
struct OpenCodeServerSession: Codable {
    var id: String
    var slug: String?
    var title: String?
    var agent: String?
    var model: ModelRef?
    var version: String?
    var time: TimeRef?

    struct ModelRef: Codable {
        var id: String?
        var providerID: String?
        var variant: String?
    }
    struct TimeRef: Codable {
        var created: Int64?
        var updated: Int64?
    }
}

/// Request body for POST /session on a REAL opencode server.
struct OpenCodeSpawnRequest: Codable {
    var title: String?
    var agent: String?
    var model: ModelRef?

    struct ModelRef: Codable {
        var id: String
        var providerID: String
        var variant: String
    }
}

/// A full remote session: metadata + the server it belongs to.
struct RemoteSession: Identifiable, Hashable {
    var id: String { info.id }
    var info: RemoteSessionInfo
    var server: ConnectionManager.ServerConnection

    var displayName: String { info.name.isEmpty ? "Session \(info.id.prefix(8))" : info.name }
}

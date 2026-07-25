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
/// - Polling each connected server's `/api/sessions` endpoint every 10 s to
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

    /// Starts browsing for `_opencode._tcp` services on the local network.
    func startDiscovery() {
        guard browser == nil else { return }
        let params = NWParameters()
        params.includePeerToPeer = true
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_opencode._tcp", domain: nil)
        let newBrowser = NWBrowser(for: descriptor, using: params)

        newBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.discoveredServers = results.compactMap { result in
                    if case .service(let name, _, _, _) = result.endpoint {
                        return DiscoveredServer(name: name, endpoint: result.endpoint)
                    }
                    return nil
                }
            }
        }

        newBrowser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error):
                DispatchQueue.main.async {
                    self?.serverStatus["__discovery__"] = .error(error.localizedDescription)
                }
            default:
                break
            }
        }

        newBrowser.start(queue: .main)
        browser = newBrowser
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
    }

    // MARK: - Session polling (§16.1)

    /// Begins polling every saved server for its session list at a 10 s
    /// interval. Each server's `/api/sessions` is fetched and the
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
        guard let url = URL(string: "\(server.baseURL)/api/sessions") else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
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

            guard let data = data,
                  let infos = try? JSONDecoder().decode([RemoteSessionInfo].self, from: data) else {
                return
            }
            DispatchQueue.main.async {
                self?.mergeSessions(infos: infos, server: server)
            }
        }.resume()
    }

    /// Reconciles the fetched session list with the published `sessions`,
    /// preserving identity by server + session id.
    private func mergeSessions(infos: [RemoteSessionInfo], server: ServerConnection) {
        let newSessions = infos.map { info in
            RemoteSession(info: info, server: server)
        }
        // Replace sessions for this server, keep others.
        sessions = sessions.filter { $0.server.id != server.id } + newSessions
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

/// Lightweight session metadata returned by `/api/sessions`.
struct RemoteSessionInfo: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var active: Bool
    var lastLines: [String]?
    var agent: String?
    var phase: String?
}

/// A full remote session: metadata + the server it belongs to.
struct RemoteSession: Identifiable, Hashable {
    var id: String { info.id }
    var info: RemoteSessionInfo
    var server: ConnectionManager.ServerConnection

    var displayName: String { info.name.isEmpty ? "Session \(info.id.prefix(8))" : info.name }
}

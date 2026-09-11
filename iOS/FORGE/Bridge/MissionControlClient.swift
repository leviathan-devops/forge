import Foundation

/// MissionControlClient
///
/// Per FORGE Engineering Specification §16 (Mission Control Backend + Spawn).
///
/// Owns the spawn path for new remote opencode sessions. The live session list
/// is sourced from `ConnectionManager` (existing polling of `/api/sessions`);
/// this client adds the `POST /session` create flow used by the W6 Session
/// Card Carousel's "Spawn New Session" card.
///
/// `RemoteSessionInfo` is the existing model defined in `ConnectionManager`
/// (it already conforms to `Codable`, so the 201 response decodes directly).
final class MissionControlClient: ObservableObject {

    /// Mirror of the polled session list (kept for spec fidelity; the live
    /// source of truth remains `ConnectionManager.sessions`).
    @Published var sessions: [RemoteSessionInfo] = []

    /// True while a spawn request is in flight (guards against re-entry).
    @Published var isSpawning: Bool = false

    /// Most recent spawn error, if any.
    @Published var lastSpawnError: String?

    // MARK: - Spawn (§16.1) — POST /session

    /// Creates a new session on the given server and returns its metadata.
    /// The REAL opencode server responds `200 OK` with the new session JSON
    /// (shape: {id, slug, title, agent, model, version, time}).
    ///
    /// - Parameters:
    ///   - baseURL: The server root (e.g. `http://host:8090`).
    ///   - title: Optional human title for the session.
    /// - Returns: The freshly spawned `RemoteSessionInfo`.
    func spawnSession(
        baseURL: URL,
        title: String? = nil
    ) async throws -> RemoteSessionInfo {
        var req = URLRequest(url: baseURL.appendingPathComponent("session"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Real opencode body: {title, agent, model: {id, providerID, variant}}.
        // TRIDENT-ONLY + FREE ZEN MODELS: the operator explicitly removed the
        // vanilla plan/build agent and paid models. Only trident + zen free
        // (Muse Spark 1.3 contributor-free default) are ever spawned.
        req.httpBody = try JSONEncoder().encode(
            OpenCodeSpawnRequest(
                title: title,
                agent: "trident",
                model: .init(id: ZenModelCatalog.defaultModelID,
                             providerID: "opencode",
                             variant: "default")
            )
        )

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw SpawnError.badStatus
        }
        // Decode the real opencode shape → map to RemoteSessionInfo.
        if let real = try? JSONDecoder().decode(OpenCodeServerSession.self, from: data) {
            return RemoteSessionInfo(
                id: real.id,
                name: (real.title?.isEmpty ?? true) ? (real.slug ?? real.id) : real.title!,
                active: true,
                lastLines: nil,
                agent: real.agent,
                phase: nil,
                timeCreated: real.time?.created,
                timeUpdated: real.time?.updated
            )
        }
        return try JSONDecoder().decode(RemoteSessionInfo.self, from: data)
    }
}

// MARK: - SpawnError

enum SpawnError: Error {
    case badStatus

    var localizedDescription: String {
        switch self {
        case .badStatus:
            return "Server did not return 201 Created."
        }
    }
}

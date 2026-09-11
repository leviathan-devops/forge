import Foundation
import Combine

/// Live OpenCode Zen model catalog.
///
/// FORGE used a frozen August list (`muse-spark-1.2-contributor-free`,
/// `deepseek-v4-flash-free`). Zen's live `GET /v1/models` is the source of
/// truth. Free-tier rows are `*free` / `*contributor-free`. DeepSeek V4 Flash
/// Free is retired from serving (zen returns "Model is unavailable") even if
/// the id still appears in the list — it is filtered out.
///
/// Default on-device model: `muse-spark-1.3-contributor` (operator lockdown:
/// the single allowed model on OpenCode Go).
final class ZenModelCatalog: ObservableObject {
    static let shared = ZenModelCatalog()

    static let allowedModelID = "muse-spark-1.3-contributor"
    static let defaultModelID = allowedModelID
    static let modelsURL = URL(string: "https://opencode.ai/zen/v1/models")!

    /// Serving-retired ids (do not default, do not show as recommended).
    static let retiredIDs: Set<String> = [
        "deepseek-v4-flash-free",
        "deepseek-v4-flash",
        "muse-spark-1.2-contributor-free",
        "muse-spark-1.2",
        "muse-spark-1.3-contributor-free"
    ]

    struct Entry: Identifiable, Equatable {
        let id: String
        let displayName: String
        let provider: String
        let free: Bool
        let favorite: Bool
        let recommended: Bool
    }

    @Published private(set) var entries: [Entry] = ZenModelCatalog.fallback
    @Published private(set) var lastFetchError: String?

    /// Offline floor matching live zen GET 2026-09-08 (free/contributor only,
    /// DeepSeek V4 Flash Free omitted — retired from serving).
    static let fallback: [Entry] = [
        Entry(id: defaultModelID,
              displayName: "Muse Spark 1.3 Free (Contributor)",
              provider: "OpenCode Zen", free: true, favorite: true, recommended: true),
        Entry(id: "nemotron-3.5-lightning-free",
              displayName: "Nemotron 3.5 Lightning Free",
              provider: "OpenCode Zen", free: true, favorite: false, recommended: false),
        Entry(id: "nemotron-3-ultra-free",
              displayName: "Nemotron 3 Ultra Free",
              provider: "OpenCode Zen", free: true, favorite: false, recommended: false),
        Entry(id: "mimo-v2.5-free",
              displayName: "MiMo V2.5 Free",
              provider: "OpenCode Zen", free: true, favorite: false, recommended: false),
        Entry(id: "ling-3.0-flash-fin-free",
              displayName: "Ling 3.0 Flash Fin Free",
              provider: "OpenCode Zen", free: true, favorite: false, recommended: false)
    ]

    func refresh() async {
        var req = URLRequest(url: Self.modelsURL)
        req.setValue("Bearer public", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        ZenClientIdentity.apply(to: &req)
        req.timeoutInterval = 12
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else {
                await MainActor.run { self.lastFetchError = "zen models HTTP \(code)" }
                return
            }
            let parsed = try JSONDecoder().decode(ModelsPage.self, from: data)
            let live = Self.entries(from: parsed.data.map(\.id))
            await MainActor.run {
                if !live.isEmpty {
                    self.entries = live
                    self.lastFetchError = nil
                }
            }
        } catch {
            let msg = error.localizedDescription
            await MainActor.run { self.lastFetchError = msg }
        }
    }

    static func isFreeID(_ id: String) -> Bool {
        let low = id.lowercased()
        return low.contains("free") || low.contains("contributor")
    }

    static func isRetired(_ id: String) -> Bool {
        retiredIDs.contains(id) || id.lowercased().hasPrefix("deepseek-v4-flash")
    }

    static func displayName(for id: String) -> String {
        switch id {
        case defaultModelID:
            return "Muse Spark 1.3 Free (Contributor)"
        case "muse-spark-1.2-contributor-free":
            return "Muse Spark 1.2 Free (Contributor)"
        default:
            return id
                .replacingOccurrences(of: "-contributor-free", with: " Free")
                .replacingOccurrences(of: "-free", with: " Free")
                .replacingOccurrences(of: "-", with: " ")
                .split(separator: " ")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
    }

    static func entries(from ids: [String]) -> [Entry] {
        let free = ids.filter { isFreeID($0) && !isRetired($0) }
        let ordered = free.sorted { a, b in
            if a == defaultModelID { return true }
            if b == defaultModelID { return false }
            return a < b
        }
        return ordered.map { id in
            Entry(
                id: id,
                displayName: displayName(for: id),
                provider: "OpenCode Zen",
                free: true,
                favorite: id == defaultModelID,
                recommended: id == defaultModelID
            )
        }
    }

    private struct ModelsPage: Decodable {
        let data: [ModelRow]
    }

    private struct ModelRow: Decodable {
        let id: String
    }
}

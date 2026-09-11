import Foundation
import UIKit
import WebKit

/// ForgeBridge
///
/// Per FORGE Engineering Specification §9, §10, §12, §13, §14.
///
/// Implements every native operation that the JavaScript agent can request.
/// Each method follows the same pattern:
///
///   1. Validate arguments; reject the callback if required args are missing.
///   2. Dispatch the heavy work to a background queue.
///   3. Perform the operation (FileManager, Git, URLSession, Keychain, …).
///   4. Resolve or reject the callback via `ForgeEngine`.
///
/// The bridge holds a weak-ish back-reference to its owning `ForgeEngine`
/// (set by the engine at init) so methods can resolve/reject without needing
/// the web view passed explicitly.
///
/// Stub / simulator safety (Wave 13 d2-mode1-fix-impl):
/// - Init is allocation-only (no I/O, no Keychain, no UI).
/// - All path ops jail under projectRoot; empty root → reject, never crash.
/// - Git stub tolerates empty projectRoot.
final class ForgeBridge {

    deinit {
        streamChunkTimer?.cancel()
        streamChunkTimer = nil
        streamTasks.removeAll()
        streamDelegates.removeAll()
        streamChunkBuffer.removeAll()
    }

    // MARK: - State

    /// The absolute path of the active project root. All relative file paths
    /// are resolved against this (§10.2).
    var projectRoot: String = ""

    /// Set by ForgeEngine at init time to break the circular reference.
    weak var engine: ForgeEngine?

    /// Curated command runner — owns the whitelisted shell-command handlers.
    private let commandRunner: ForgeCommandRunner

    /// libgit2 wrapper (phase-1 stub — no native git library).
    private let gitManager: ForgeGitManager

    /// Background queue for file and command operations.
    private let ioQueue = DispatchQueue(label: "forge.bridge.io", qos: .userInitiated)

    /// Marks whether safe-init completed (always true after designated inits).
    private(set) var isSafeInitialized: Bool = false

    // MARK: - Init (stub bridge safe-init)

    /// Designated safe-init: pure allocation, no filesystem/Keychain/UI side
    /// effects. Safe to construct on the main thread during Mode1 `onAppear`
    /// under XCUITest without racing fullScreenCover presentation.
    init() {
        self.commandRunner = ForgeCommandRunner()
        self.gitManager = ForgeGitManager()
        self.isSafeInitialized = true
    }

    /// Convenience constructor that injects custom runners (useful for
    /// testing).
    init(commandRunner: ForgeCommandRunner, gitManager: ForgeGitManager) {
        self.commandRunner = commandRunner
        self.gitManager = gitManager
        self.isSafeInitialized = true
    }

    // MARK: - Project management (§10.2)

    /// Sets the active project by name, creating the directory if needed,
    /// and updates the project root on the command runner and git manager.
    func setProject(_ name: String) {
        let safeName = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeName.isEmpty else { return }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let projectDir = docs
            .appendingPathComponent("projects")
            .appendingPathComponent(safeName)
        try? FileManager.default.createDirectory(
            at: projectDir, withIntermediateDirectories: true
        )
        projectRoot = projectDir.path
        commandRunner.projectRoot = projectRoot
    }

    /// Sets the project root to an explicit absolute path.
    func setProjectRoot(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        projectRoot = trimmed
        commandRunner.projectRoot = trimmed
    }

    /// Ensures a non-empty project root exists for Mode1 demo / stub path.
    /// Creates `Documents/projects/FORGE-Demo` if needed. Never throws.
    @discardableResult
    func ensureDemoProjectRoot() -> String {
        if !projectRoot.isEmpty {
            return projectRoot
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let demo = docs
            .appendingPathComponent("projects")
            .appendingPathComponent("FORGE-Demo")
        try? FileManager.default.createDirectory(
            at: demo, withIntermediateDirectories: true
        )
        projectRoot = demo.path
        commandRunner.projectRoot = projectRoot
        return projectRoot
    }

    /// Resolves a (possibly relative) path against the project root and jails
    /// the result under `projectRoot` (F-PATH-JAIL-ESCAPE).
    ///
    /// Empty paths resolve to the project root itself. Absolute paths and
    /// relative paths containing `..` are accepted only when the standardized
    /// result remains under `projectRoot`; otherwise returns `nil` so callers
    /// can reject the bridge callback.
    ///
    /// - Returns: Standardized absolute path under project root, or `nil` if
    ///   the path escapes the jail or `projectRoot` is unset.
    func resolveProjectPath(_ relativePath: String) -> String? {
        let rootRaw = projectRoot
        guard !rootRaw.isEmpty else {
            // No project root — refuse any path (cannot establish a jail).
            return nil
        }
        let root = (rootRaw as NSString).standardizingPath

        let joined: String
        if relativePath.isEmpty {
            joined = root
        } else if (relativePath as NSString).isAbsolutePath {
            // Absolute input only if already under root (after standardization).
            joined = (relativePath as NSString).standardizingPath
        } else {
            joined = ((root as NSString)
                .appendingPathComponent(relativePath) as NSString)
                .standardizingPath
        }

        // Jail: must equal root or be a strict descendant (root + "/…").
        if joined == root {
            return joined
        }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        if joined.hasPrefix(prefix) {
            return joined
        }
        return nil
    }

    // MARK: - File operations (§9.2)

    func readFile(_ args: [String: Any], callbackId: String?) {
        guard let path = args["path"] as? String, let cbId = callbackId else {
            if let cbId = callbackId {
                reject(cbId, "readFile: missing 'path' argument")
            }
            return
        }
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            guard let fullPath = self.resolveProjectPath(path) else {
                self.reject(cbId, "readFile: path escapes project root: \(path)")
                return
            }
            guard FileManager.default.fileExists(atPath: fullPath) else {
                self.reject(cbId, "readFile: file does not exist: \(path)")
                return
            }
            do {
                let content = try String(contentsOfFile: fullPath, encoding: .utf8)
                self.resolve(cbId, content)
            } catch {
                self.reject(cbId, "readFile: \(error.localizedDescription)")
            }
        }
    }

    func writeFile(_ args: [String: Any], callbackId: String?) {
        guard let path = args["path"] as? String,
              let content = args["content"] as? String,
              let cbId = callbackId else {
            if let cbId = callbackId {
                reject(cbId, "writeFile: missing 'path' or 'content'")
            }
            return
        }
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            guard let fullPath = self.resolveProjectPath(path) else {
                self.reject(cbId, "writeFile: path escapes project root: \(path)")
                return
            }
            let dir = (fullPath as NSString).deletingLastPathComponent
            do {
                // Ensure the parent directory exists (atomic write requires it).
                try FileManager.default.createDirectory(
                    atPath: dir, withIntermediateDirectories: true
                )
                try content.write(toFile: fullPath, atomically: true, encoding: .utf8)
                self.resolve(cbId, true)
            } catch {
                self.reject(cbId, "writeFile: \(error.localizedDescription)")
            }
        }
    }

    func listFiles(_ args: [String: Any], callbackId: String?) {
        guard let cbId = callbackId else { return }
        let path = args["path"] as? String ?? ""
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            guard let fullPath = self.resolveProjectPath(path) else {
                self.reject(cbId, "listFiles: path escapes project root: \(path)")
                return
            }
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: fullPath)
                let items: [[String: Any]] = contents.map { name in
                    let itemPath = (fullPath as NSString).appendingPathComponent(name)
                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir)
                    let attrs = try? FileManager.default.attributesOfItem(atPath: itemPath)
                    let size = (attrs?[.size] as? NSNumber)?.intValue ?? 0
                    let modified = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
                    return [
                        "name": name,
                        "isDirectory": isDir.boolValue,
                        "size": size,
                        "modified": modified,
                    ]
                }
                self.resolve(cbId, items)
            } catch {
                self.reject(cbId, "listFiles: \(error.localizedDescription)")
            }
        }
    }

    func deleteFile(_ args: [String: Any], callbackId: String?) {
        guard let path = args["path"] as? String, let cbId = callbackId else {
            if let cbId = callbackId {
                reject(cbId, "deleteFile: missing 'path'")
            }
            return
        }
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            guard let fullPath = self.resolveProjectPath(path) else {
                self.reject(cbId, "deleteFile: path escapes project root: \(path)")
                return
            }
            do {
                try FileManager.default.removeItem(atPath: fullPath)
                self.resolve(cbId, true)
            } catch {
                self.reject(cbId, "deleteFile: \(error.localizedDescription)")
            }
        }
    }

    func searchFiles(_ args: [String: Any], callbackId: String?) {
        guard let query = args["query"] as? String, let cbId = callbackId else {
            if let cbId = callbackId {
                reject(cbId, "searchFiles: missing 'query'")
            }
            return
        }
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.projectRoot.isEmpty else {
                self.reject(cbId, "searchFiles: project root not set")
                return
            }
            let basePath = self.projectRoot
            var results: [[String: Any]] = []
            guard let enumerator = FileManager.default.enumerator(atPath: basePath) else {
                self.resolve(cbId, results)
                return
            }
            let lowerQuery = query.lowercased()
            var scanned = 0
            while let file = enumerator.nextObject() as? String {
                scanned += 1
                // Cap work under simulator/XCUITest to avoid watchdog kills.
                if scanned > 5_000 || results.count >= 200 { break }
                let fullPath = (basePath as NSString).appendingPathComponent(file)
                guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else {
                    continue
                }
                let lines = content.components(separatedBy: "\n")
                for (i, line) in lines.enumerated() {
                    if line.lowercased().contains(lowerQuery) {
                        results.append([
                            "path": file,
                            "line": i + 1,
                            "content": line.trimmingCharacters(in: .whitespaces),
                        ])
                        if results.count >= 200 { break }
                    }
                }
            }
            self.resolve(cbId, results)
        }
    }

    // MARK: - Command runner (§9.3)

    func runCommand(_ args: [String: Any], callbackId: String?) {
        guard let command = args["command"] as? String, let cbId = callbackId else {
            if let cbId = callbackId {
                reject(cbId, "runCommand: missing 'command'")
            }
            return
        }
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            let result = self.commandRunner.executeCommand(command)
            self.resolve(cbId, [
                "stdout": result.stdout,
                "stderr": result.stderr,
                "exitCode": Int(result.exitCode),
            ])
        }
    }

    // MARK: - Git operations (§11)

    func gitOperation(_ args: [String: Any], callbackId: String?) {
        guard let operation = args["operation"] as? String, let cbId = callbackId else {
            if let cbId = callbackId {
                reject(cbId, "gitOperation: missing 'operation'")
            }
            return
        }
        // Stub-safe: empty project root must not touch "/" or crash.
        let root = projectRoot
        guard !root.isEmpty else {
            reject(cbId, "gitOperation: project root not set")
            return
        }
        gitManager.gitOperation(
            args,
            operation: operation,
            projectRoot: root,
            resolve: { [weak self] result in
                self?.resolve(cbId, result)
            },
            reject: { [weak self] error in
                self?.reject(cbId, error)
            }
        )
    }

    // MARK: - HTTP request (§9.4)

    func httpRequest(_ args: [String: Any], callbackId: String?) {
        guard let urlString = args["url"] as? String,
              let method = args["method"] as? String,
              let cbId = callbackId,
              let url = URL(string: urlString) else {
            if let cbId = callbackId {
                reject(cbId, "httpRequest: missing or invalid 'url'/'method'")
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        // 120s — LLM calls with large max_tokens can exceed the default 30s
        // (observed "LLM call failed: HTTP: The request timed out" on zen).
        request.timeoutInterval = 120
        if let headers = args["headers"] as? [String: String] {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        if let body = args["body"] as? String {
            request.httpBody = body.data(using: .utf8)
        }
        ZenClientIdentity.apply(to: &request)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                self?.reject(cbId, "HTTP: \(error.localizedDescription)")
                return
            }
            guard let resp = response as? HTTPURLResponse else {
                self?.reject(cbId, "HTTP: invalid response")
                return
            }
            let bodyStr: String
            if let data = data {
                bodyStr = String(data: data, encoding: .utf8) ?? ""
            } else {
                bodyStr = ""
            }
            var headers: [String: String] = [:]
            for (key, value) in resp.allHeaderFields {
                if let k = key as? String, let v = value as? String {
                    headers[k] = v
                }
            }
            self?.resolve(cbId, [
                "status": resp.statusCode,
                "headers": headers,
                "body": bodyStr,
            ])
        }.resume()
    }
    // MARK: - Streaming HTTP request (SSE for live LLM tokens)

    /// Same contract as `httpRequest` but forwards body chunks to JS as they
    /// arrive (`window.__forgeStreamChunk(id, text)`), then resolves with the
    /// full body. Used for SSE streaming LLM responses so the TUI shows live
    /// token output instead of a frozen screen during the call.
    func httpRequestStream(_ args: [String: Any], callbackId: String?) {
        guard let urlString = args["url"] as? String,
              let method = args["method"] as? String,
              let cbId = callbackId,
              let url = URL(string: urlString) else {
            if let cbId = callbackId { reject(cbId, "httpRequestStream: invalid args") }
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 300
        if let headers = args["headers"] as? [String: String] {
            for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        }
        if let body = args["body"] as? String {
            request.httpBody = body.data(using: .utf8)
        }
        ZenClientIdentity.apply(to: &request)
        // TRUE streaming: delegate-based dataTask forwards each chunk to JS
        // immediately (live tokens). The delegate is RETAINED in
        // streamDelegates (URLSession does not retain its delegate).
        // The JS side supplies a stable streamId so chunk routing matches.
        let streamId = args["streamId"] as? String ?? cbId
        let delegate = StreamDelegateBridge(
            streamId: streamId,
            onChunk: { [weak self] id, text in self?.pushStreamChunk(id, text: text) },
            onDone: { [weak self] id, ok, status in self?.pushStreamDone(id, ok: ok, status: status) }
        )
        // Store under streamId so pushStreamDone can remove it (was cbId —
        // mismatch meant delegates leaked per iteration: 12 leaked URLSessions
        // for a 12-iteration agent loop).
        streamDelegates[streamId] = delegate
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        streamTasks[streamId] = task
        task.resume()
    }

    /// Active streaming tasks keyed by callback id (kept alive).
    private var streamTasks: [String: URLSessionDataTask] = [:]
    /// Retained streaming delegates (URLSession does NOT retain its delegate).
    private var streamDelegates: [String: StreamDelegateBridge] = [:]

    /// Chunk-batching state: incoming SSE chunks accumulate in
    /// `streamChunkBuffer` and flush to JS every 250ms (~4fps). This prevents
    /// the WebKit suspend/resume churn — each evaluateJavaScript wakes the
    /// WebContent process, and at 66ms frequency the suspend/resume cycles
    /// (prepareToSuspend → releaseMemory → resume, dozens/sec) kill the
    /// WebContent process with SIGSEGV. 250ms is the sweet spot: the UI still
    /// feels fluid (text updates 4×/sec) but WebKit doesn't thrash.
    private var streamChunkBuffer: [String: String] = [:]
    private var streamChunkTimer: DispatchSourceTimer?

    private func pushStreamChunk(_ id: String, text: String) {
        // Accumulate on the background queue; the 250ms flush does the single
        // main-thread evaluateJavaScript with all accumulated text.
        streamChunkBuffer[id] = (streamChunkBuffer[id] ?? "") + text
        if streamChunkTimer == nil {
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + .milliseconds(250), repeating: .milliseconds(250))
            timer.setEventHandler { [weak self] in
                guard let self = self else { return }
                // Collect keys BEFORE mutating the dict (mutation during
                // iteration is a runtime trap).
                let ids = Array(self.streamChunkBuffer.keys)
                for sid in ids {
                    guard let accumulated = self.streamChunkBuffer[sid],
                          !accumulated.isEmpty else { continue }
                    self.streamChunkBuffer[sid] = ""
                    self.evalStreamChunk(sid, text: accumulated)
                }
            }
            timer.resume()
            streamChunkTimer = timer
        }
    }

    /// The actual main-thread JS evaluation for ONE accumulated chunk batch.
    private func evalStreamChunk(_ id: String, text: String) {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        let js = "window.__forgeStreamChunk && window.__forgeStreamChunk('\(id)', '\(escaped)');"
        DispatchQueue.main.async { [weak self] in
            self?.engine?.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private func pushStreamDone(_ id: String, ok: Bool, status: Int = 0) {
        // Flush any remaining buffered chunk before signaling done.
        if let remaining = streamChunkBuffer[id], !remaining.isEmpty {
            streamChunkBuffer[id] = ""
            evalStreamChunk(id, text: remaining)
        }
        // Cancel the shared flush timer when the last stream finishes — a
        // resumed DispatchSource that outlives its owner crashes
        // (SIGSEGV: "Dispatch source destroyed while still registered").
        streamChunkBuffer.removeValue(forKey: id)
        if streamChunkBuffer.isEmpty {
            streamChunkTimer?.cancel()
            streamChunkTimer = nil
        }
        let js = "window.__forgeStreamDone && window.__forgeStreamDone('\(id)', \(ok), \(status));"
        DispatchQueue.main.async { [weak self] in
            self?.engine?.webView?.evaluateJavaScript(js, completionHandler: nil)
        }
        streamTasks.removeValue(forKey: id)
        streamDelegates.removeValue(forKey: id)
    }

// MARK: - Keychain secrets (§9.5)

    func getSecret(_ args: [String: Any], callbackId: String?) {
        guard let key = args["key"] as? String, let cbId = callbackId else {
            if let cbId = callbackId {
                reject(cbId, "getSecret: missing 'key'")
            }
            return
        }
        let value = KeychainHelper.loadSync(for: key) ?? ""
        resolve(cbId, value)
    }

    func setSecret(_ args: [String: Any], callbackId: String?) {
        guard let key = args["key"] as? String,
              let value = args["value"] as? String,
              let cbId = callbackId else {
            if let cbId = callbackId {
                reject(cbId, "setSecret: missing 'key' or 'value'")
            }
            return
        }
        do {
            try KeychainHelper.save(value, for: key)
            resolve(cbId, true)
        } catch {
            reject(cbId, "Keychain: \(error.localizedDescription)")
        }
    }

    // MARK: - Secure entry + provider config (CONNECT_SPEC.md)

    /// Presents a native secure text field and resolves with the entered
    /// value. The secret never touches terminal pixels, logs, or files.
    func promptSecret(_ args: [String: Any], callbackId: String?) {
        guard let cbId = callbackId else { return }
        let rawTitle = args["title"] as? String ?? ""
        let title = rawTitle.isEmpty ? "API Key" : rawTitle
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let rootVC = self.topMostViewController() else {
                self?.reject(cbId, "promptSecret: no presenting view controller")
                return
            }
            let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            alert.addTextField { tf in
                tf.isSecureTextEntry = true
                tf.clearButtonMode = .whileEditing
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.reject(cbId, "promptSecret: cancelled")
            })
            alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
                let value = alert.textFields?.first?.text ?? ""
                if value.isEmpty {
                    self.reject(cbId, "promptSecret: empty value")
                } else {
                    self.resolve(cbId, value)
                }
            })
            if let pop = alert.popoverPresentationController {
                pop.sourceView = rootVC.view
                pop.sourceRect = CGRect(
                    x: rootVC.view.bounds.midX,
                    y: rootVC.view.bounds.midY,
                    width: 0, height: 0
                )
                pop.permittedArrowDirections = []
            }
            rootVC.present(alert, animated: true)
        }
    }

    /// Merges one provider-config patch into UserDefaults and hot-swaps the
    /// JS config via the engine. Refuses secret-like values, retired models,
    /// and anything but the single allowed model (operator lockdown).
    func saveProviderConfig(_ args: [String: Any], callbackId: String?) {
        guard let cbId = callbackId else { return }
        let defaults = UserDefaults.standard
        if let raw = args["provider"] as? String, !raw.trimmingCharacters(in: .whitespaces).isEmpty {
            let v = raw.lowercased()
            let norm: String
            switch v {
            case "anthropic": norm = "Anthropic"
            case "openai", "zen", "opencode zen": norm = "OpenAI"
            case "local", "local (ollama)": norm = "Local (Ollama)"
            case "custom": norm = "Custom"
            default: norm = raw
            }
            guard APIProvider(rawValue: norm) != nil else {
                reject(cbId, "saveProviderConfig: unknown provider"); return
            }
            defaults.set(norm, forKey: ForgeSettingsKeys.apiProvider)
        }
        if let model = args["model"] as? String, !model.trimmingCharacters(in: .whitespaces).isEmpty {
            if model.range(of: "sk-[A-Za-z0-9]{8,}", options: .regularExpression) != nil {
                reject(cbId, "saveProviderConfig: leak-risk value refused"); return
            }
            if ZenModelCatalog.isRetired(model) {
                reject(cbId, "saveProviderConfig: retired model"); return
            }
            if model.lowercased() != ZenModelCatalog.allowedModelID {
                reject(cbId, "saveProviderConfig: only model allowed: muse-spark-1.3-contributor"); return
            }
            defaults.set(model, forKey: ForgeSettingsKeys.modelName)
        }
        if let url = args["baseUrl"] as? String {
            let t = url.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty {
                defaults.removeObject(forKey: ForgeSettingsKeys.apiBaseUrl)
            } else {
                guard (t.hasPrefix("https://") || t.hasPrefix("http://")) && !t.contains(" ") else {
                    reject(cbId, "saveProviderConfig: bad url"); return
                }
                defaults.set(t, forKey: ForgeSettingsKeys.apiBaseUrl)
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.engine?.injectAPICredentials()
            self?.resolve(cbId, true)
        }
    }

    // MARK: - Share sheet (§9.6)

    func shareFile(_ args: [String: Any], callbackId: String?) {
        guard let path = args["path"] as? String, let cbId = callbackId else {
            if let cbId = callbackId {
                reject(cbId, "shareFile: missing 'path'")
            }
            return
        }
        guard let fullPath = resolveProjectPath(path) else {
            reject(cbId, "shareFile: path escapes project root: \(path)")
            return
        }
        let fileURL = URL(fileURLWithPath: fullPath)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let activityVC = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            // Find the key window's root view controller to present from.
            if let rootVC = self.topMostViewController() {
                activityVC.popoverPresentationController?.sourceView = rootVC.view
                activityVC.popoverPresentationController?.sourceRect = CGRect(
                    x: rootVC.view.bounds.midX,
                    y: rootVC.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                activityVC.popoverPresentationController?.permittedArrowDirections = []
                rootVC.present(activityVC, animated: true)
            }
            self.resolve(cbId, true)
        }
    }

    /// Finds the topmost presented view controller across all connected
    /// window scenes.
    private func topMostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        guard let keyWindow = scenes
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            return scenes.flatMap({ $0.windows }).first?.rootViewController
        }
        var topVC = keyWindow.rootViewController
        while let presented = topVC?.presentedViewController {
            topVC = presented
        }
        return topVC
    }

    // MARK: - Python via Pyodide (§14)

    /// Bundled `Resources/pyodide/` (folder-reference copy) or flattened
    /// `pyodide.js` next to the app bundle root.
    private func pyodideDirectoryURL() -> URL? {
        if let js = Bundle.main.url(
            forResource: "pyodide", withExtension: "js", subdirectory: "pyodide"
        ) {
            return js.deletingLastPathComponent()
        }
        if let js = Bundle.main.url(forResource: "pyodide", withExtension: "js") {
            return js.deletingLastPathComponent()
        }
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("pyodide", isDirectory: true),
            Bundle.main.bundleURL.appendingPathComponent("pyodide", isDirectory: true)
        ].compactMap { $0 }
        for folder in candidates {
            if FileManager.default.fileExists(
                atPath: folder.appendingPathComponent("pyodide.js").path
            ) {
                return folder
            }
        }
        return nil
    }

    /// JSON-encode a string as a JS string literal (quotes included).
    private func jsJSONString(_ value: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [value], options: [])
        guard let data,
              let wrapped = String(data: data, encoding: .utf8),
              wrapped.count >= 2 else {
            return "\"\""
        }
        return String(wrapped.dropFirst().dropLast())
    }

    func runPython(_ args: [String: Any], callbackId: String?) {
        guard let code = args["code"] as? String, let cbId = callbackId else {
            if let cbId = callbackId {
                reject(cbId, "runPython: missing 'code'")
            }
            return
        }

        guard pyodideDirectoryURL() != nil else {
            reject(
                cbId,
                "Pyodide runtime not found in app bundle (expected Resources/pyodide/pyodide.js)"
            )
            return
        }
        // file:// wasm fetch from loadHTMLString is blocked in WKWebView.
        // Sister desk serves Resources/pyodide/ via WKURLSchemeHandler.
        let indexURL = "forgepy://localhost/pyodide/"
        let indexURLJS = jsJSONString(indexURL)
        let cbIdJS = jsJSONString(cbId)

        // Escape the Python source for safe embedding in a JS template
        // literal.
        let escapedCode = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        // Hidden WKWebView is the main frame: load via <script src>, not a
        // Worker. indexURL is the forgepy scheme (not file://).
        let js = """
        (function() {
            (async function() {
                try {
                    const result = await Promise.race([
                        (async function() {
                            if (!window.__pyodide) {
                                window.__forgeNative.output('Loading Python runtime...\\n');
                                var indexURL = \(indexURLJS);
                                function loadScript(src) {
                                    return new Promise(function(resolve, reject) {
                                        var s = document.createElement('script');
                                        s.src = src;
                                        s.onload = function() { resolve(); };
                                        s.onerror = function() {
                                            reject(new Error('Failed to load ' + src));
                                        };
                                        (document.head || document.documentElement).appendChild(s);
                                    });
                                }
                                if (typeof loadPyodide !== 'function') {
                                    await loadScript(indexURL + 'pyodide.js');
                                }
                                var loader = (typeof loadPyodide === 'function')
                                    ? loadPyodide
                                    : (loadPyodide && loadPyodide.loadPyodide);
                                if (typeof loader !== 'function') {
                                    throw new Error('loadPyodide is not defined after loading pyodide.js from ' + indexURL);
                                }
                                // UMD asm build assigns _createPyodideModule; preload so
                                // loadPyodide does not dynamic-import a module URL.
                                if (typeof _createPyodideModule !== 'function') {
                                    await loadScript(indexURL + 'pyodide.asm.js');
                                }
                                window.__pyodide = await loader({ indexURL: indexURL });
                                window.__pyStdout = '';
                                if (window.__pyodide.setStdout) {
                                    window.__pyodide.setStdout({
                                        batched: function(text) {
                                            var t = String(text);
                                            if (t.length && t.charAt(t.length-1) !== '\\n') t += '\\n';
                                            window.__pyStdout = (window.__pyStdout || '') + t;
                                            try {
                                                window.webkit.messageHandlers.native.postMessage({
                                                    method: '__output',
                                                    args: { ansi: t }
                                                });
                                            } catch (e) {}
                                        }
                                    });
                                }
                                if (window.__pyodide.setStderr) {
                                    window.__pyodide.setStderr({
                                        batched: function(text) {
                                            try {
                                                window.webkit.messageHandlers.native.postMessage({
                                                    method: '__output',
                                                    args: { ansi: String(text) + '\\n' }
                                                });
                                            } catch (e) {}
                                        }
                                    });
                                }
                            }
                            window.__pyStdout = '';
                            var pyRet = await window.__pyodide.runPython(`\(escapedCode)`);
                            return pyRet;
                        })(),
                        new Promise((_, reject) =>
                            setTimeout(() => reject(new Error('Python execution timeout (90s)')), 90000))
                    ]);
                    var pyOut = String(window.__pyStdout || '');
                    var pyRet = result;
                    if (pyRet === undefined || pyRet === null) pyRet = '';
                    var delivered = pyOut !== '' ? pyOut : String(pyRet);
                    if (delivered === 'undefined' || delivered === 'None') delivered = pyOut;
                    window.webkit.messageHandlers.native.postMessage({
                        method: '__pythonResult',
                        args: { result: delivered, stdout: pyOut },
                        callbackId: \(cbIdJS)
                    });
                } catch (error) {
                    var msg = (error && error.message) ? error.message : String(error);
                    try {
                        window.webkit.messageHandlers.native.postMessage({
                            method: '__pythonError',
                            args: { message: msg },
                            callbackId: \(cbIdJS)
                        });
                    } catch (e2) {}
                }
            })();
        })();
        """
        DispatchQueue.main.async { [weak self] in
            guard let webView = self?.engine?.webView else {
                self?.reject(cbId, "ForgeEngine webView unavailable")
                return
            }
            webView.evaluateJavaScript(js) { [weak self] _, error in
                if let error {
                    self?.reject(cbId, error.localizedDescription)
                }
            }
        }
        // Native watchdog (t92): hidden-WebView JS timers can stall, leaving
        // the agent turn hanging with no error and no stdout. DispatchQueue
        // is never throttled — this turns silence into a named error.
        // Double-settle is safe: if __pythonResult already resolved, the JS
        // promise ignores the reject.
        let watchedCbId = cbId
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
            self?.reject(watchedCbId, "runPython: no result in 120s (JS loader/timers stalled)")
        }
    }

    // MARK: - Resolve / Reject helpers

    private func resolve(_ callbackId: String, _ result: Any) {
        engine?.resolveCallback(callbackId, result: result)
    }

    private func reject(_ callbackId: String, _ error: String) {
        engine?.rejectCallback(callbackId, error: error)
    }
}

// MARK: - StreamDelegateBridge

/// URLSessionDataDelegate that forwards each received data chunk to JS via the
/// `onChunk` closure (live SSE token streaming) and signals completion via
/// `onDone`. Retained by the URLSession's delegate reference.
private final class StreamDelegateBridge: NSObject, URLSessionDataDelegate {
    let streamId: String
    let onChunk: (String, String) -> Void
    let onDone: (String, Bool, Int) -> Void
    var statusCode = 0
    var body = ""

    init(streamId: String,
         onChunk: @escaping (String, String) -> Void,
         onDone: @escaping (String, Bool, Int) -> Void) {
        self.streamId = streamId
        self.onChunk = onChunk
        self.onDone = onDone
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse { statusCode = http.statusCode }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            body += text
            onChunk(streamId, text)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error == nil {
            // Resolve the JS promise with the full response (chunks already
            // streamed live). The bridge's resolve() needs the callback id —
            // this closure path uses the ForgeEngine callback store via
            // onDone; the actual resolve is handled by the JS wait loop.
            onDone(streamId, true, statusCode)
        } else {
            onDone(streamId, false, statusCode)
        }
        session.invalidateAndCancel()
    }
}

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
final class ForgeBridge {

    // MARK: - State

    /// The absolute path of the active project root. All relative file paths
    /// are resolved against this (§10.2).
    var projectRoot: String = ""

    /// Set by ForgeEngine at init time to break the circular reference.
    weak var engine: ForgeEngine?

    /// Curated command runner — owns the whitelisted shell-command handlers.
    private let commandRunner: ForgeCommandRunner

    /// libgit2 wrapper.
    private let gitManager: ForgeGitManager

    /// Background queue for file and command operations.
    private let ioQueue = DispatchQueue(label: "forge.bridge.io", qos: .userInitiated)

    // MARK: - Init

    init() {
        self.commandRunner = ForgeCommandRunner()
        self.gitManager = ForgeGitManager()
    }

    /// Convenience constructor that injects custom runners (useful for
    /// testing).
    init(commandRunner: ForgeCommandRunner, gitManager: ForgeGitManager) {
        self.commandRunner = commandRunner
        self.gitManager = gitManager
    }

    // MARK: - Project management (§10.2)

    /// Sets the active project by name, creating the directory if needed,
    /// and updates the project root on the command runner and git manager.
    func setProject(_ name: String) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let projectDir = docs.appendingPathComponent("projects").appendingPathComponent(name)
        try? FileManager.default.createDirectory(
            at: projectDir, withIntermediateDirectories: true
        )
        projectRoot = projectDir.path
        commandRunner.projectRoot = projectRoot
    }

    /// Sets the project root to an explicit absolute path.
    func setProjectRoot(_ path: String) {
        projectRoot = path
        commandRunner.projectRoot = path
    }

    /// Resolves a (possibly relative) path against the project root.
    /// Empty paths resolve to the project root itself; absolute paths are
    /// returned untouched (§9.2).
    func resolveProjectPath(_ relativePath: String) -> String {
        if relativePath.isEmpty { return projectRoot }
        if relativePath.hasPrefix("/") { return relativePath }
        return (projectRoot as NSString).appendingPathComponent(relativePath)
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
            let fullPath = self.resolveProjectPath(path)
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
            let fullPath = self.resolveProjectPath(path)
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
            let fullPath = self.resolveProjectPath(path)
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
            let fullPath = self.resolveProjectPath(path)
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
            let basePath = self.projectRoot.isEmpty
                ? FileManager.default.currentDirectoryPath
                : self.projectRoot
            var results: [[String: Any]] = []
            guard let enumerator = FileManager.default.enumerator(atPath: basePath) else {
                self.resolve(cbId, results)
                return
            }
            let lowerQuery = query.lowercased()
            while let file = enumerator.nextObject() as? String {
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
        let root = projectRoot
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
        request.timeoutInterval = 30
        if let headers = args["headers"] as? [String: String] {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        if let body = args["body"] as? String {
            request.httpBody = body.data(using: .utf8)
        }

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

    // MARK: - Share sheet (§9.6)

    func shareFile(_ args: [String: Any], callbackId: String?) {
        guard let path = args["path"] as? String, let cbId = callbackId else {
            if let cbId = callbackId {
                reject(cbId, "shareFile: missing 'path'")
            }
            return
        }
        let fileURL = URL(fileURLWithPath: resolveProjectPath(path))
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

    func runPython(_ args: [String: Any], callbackId: String?) {
        guard let code = args["code"] as? String, let cbId = callbackId else {
            if let cbId = callbackId {
                reject(cbId, "runPython: missing 'code'")
            }
            return
        }
        // Escape the Python source for safe embedding in a JS template
        // literal.
        let escapedCode = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let js = """
        (async function() {
            try {
                if (!window.__pyodide) {
                    window.__forgeNative.output('Loading Python runtime...\\n');
                    importScripts('pyodide.js');
                    window.__pyodide = await loadPyodide({ indexURL: './' });
                    window.__pyodide.setStdout({
                        batched: (text) => window.__forgeNative.output(text + '\\n')
                    });
                    window.__pyodide.setStderr({
                        batched: (text) => window.__forgeNative.output(text + '\\n')
                    });
                }
                const result = await Promise.race([
                    window.__pyodide.runPython(`\(escapedCode)`),
                    new Promise((_, reject) =>
                        setTimeout(() => reject(new Error('Python execution timeout (30s)')), 30000))
                ]);
                window.__forgeNative.resolve('\(cbId)', String(result));
            } catch (error) {
                window.__forgeNative.reject('\(cbId)', error.message);
            }
        })();
        """
        DispatchQueue.main.async { [weak self] in
            self?.engine?.webView?.evaluateJavaScript(js, completionHandler: nil)
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

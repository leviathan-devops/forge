import Foundation
import WebKit

/// Serves vendored Pyodide assets (js / wasm / zip / json) into the hidden
/// agent WKWebView over the custom `forgepy` scheme.
///
/// `loadPyodide({ indexURL: "forgepy://localhost/pyodide/" })` fetches
/// `pyodide.asm.wasm`, `python_stdlib.zip`, `pyodide-lock.json`, and
/// `pyodide.asm.js` relative to that prefix. A custom scheme is required:
/// `file://` XHR/fetch of those bytes is blocked, and
/// `WebAssembly.instantiateStreaming` requires `Content-Type: application/wasm`.
///
/// Sister desk registers this handler on `WKWebViewConfiguration` with
/// `setURLSchemeHandler(_:forURLScheme: "forgepy")` *before*
/// `WKWebView(frame:configuration:)`.
///
/// WKWebView cancels in-flight wasm loads via `stop`. After stop (or after
/// `didFinish` / `didFailWithError`), any further `WKURLSchemeTask` call
/// traps — cancelled tasks are tracked under a lock and ignored.
final class PyodideSchemeHandler: NSObject, WKURLSchemeHandler {

    /// Recursive: `didFinish` may re-enter `stop` on the same thread.
    private let lock = NSRecursiveLock()
    private var cancelledTasks = Set<ObjectIdentifier>()
    private var inFlightTasks = Set<ObjectIdentifier>()
    private let ioQueue = DispatchQueue(
        label: "forge.pyodide.scheme",
        qos: .userInitiated
    )

    // MARK: - WKURLSchemeHandler

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let id = taskID(urlSchemeTask)
        lock.lock()
        inFlightTasks.insert(id)
        lock.unlock()
        ioQueue.async { [weak self] in
            guard let self else { return }
            self.serve(urlSchemeTask)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        let id = taskID(urlSchemeTask)
        lock.lock()
        if inFlightTasks.contains(id) {
            cancelledTasks.insert(id)
        }
        lock.unlock()
    }

    // MARK: - Serve

    private func serve(_ task: WKURLSchemeTask) {
        defer {
            // Cancelled mid-read (or before first byte) never reaches
            // deliver/fail; drop bookkeeping so ObjectIdentifiers do not leak.
            lock.lock()
            let id = taskID(task)
            if cancelledTasks.contains(id) {
                forgetLocked(id)
            }
            lock.unlock()
        }

        if isCancelled(task) { return }

        guard let requestURL = task.request.url else {
            fail(task, error: SchemeError.invalidURL)
            return
        }

        guard let relative = relativeAssetPath(from: requestURL),
              let fileURL = bundleURL(forRelativePath: relative) else {
            fail(task, error: SchemeError.notFound)
            return
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            fail(task, error: error)
            return
        }

        let mime = mimeType(for: relative)
        guard let response = HTTPURLResponse(
            url: requestURL,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": mime,
                "Content-Length": String(data.count),
                // fetch() from the file:// agent document to forgepy:// is
                // cross-origin; wasm instantiate needs this plus application/wasm.
                "Access-Control-Allow-Origin": "*"
            ]
        ) else {
            fail(task, error: SchemeError.invalidURL)
            return
        }

        deliver(task, response: response, data: data)
    }

    // MARK: - URL → bundle file

    /// Maps `forgepy://localhost/pyodide/pyodide.asm.wasm` (path
    /// `/pyodide/<file>`) or `forgepy://localhost/pyodide.asm.wasm` (path
    /// `/<file>`) onto a relative asset name. Nested names under `pyodide/`
    /// are preserved. `..` is rejected.
    private func relativeAssetPath(from url: URL) -> String? {
        var path = url.path
        while path.hasPrefix("/") {
            path.removeFirst()
        }
        path = path.removingPercentEncoding ?? path
        guard !path.isEmpty else { return nil }

        let parts = path.split(separator: "/").map(String.init)
        guard !parts.isEmpty else { return nil }
        if parts.contains(where: { $0 == ".." || $0.isEmpty }) {
            return nil
        }

        let relative: String
        if parts[0] == "pyodide" {
            guard parts.count >= 2 else { return nil }
            relative = parts.dropFirst().joined(separator: "/")
        } else {
            relative = parts.last ?? ""
        }
        guard !relative.isEmpty, !relative.contains("..") else { return nil }
        return relative
    }

    /// `Bundle.main.url(forResource:withExtension:subdirectory: "pyodide")`,
    /// then `Bundle.main.resourceURL/pyodide/<filename>`. Nested remainder
    /// paths use subdirectory `pyodide/<dir>`.
    private func bundleURL(forRelativePath relativePath: String) -> URL? {
        let nsPath = relativePath as NSString
        let filename = nsPath.lastPathComponent
        let nested = nsPath.deletingLastPathComponent
        let ext = (filename as NSString).pathExtension
        let base = (filename as NSString).deletingPathExtension

        let subdirectory: String
        if nested.isEmpty {
            subdirectory = "pyodide"
        } else {
            subdirectory = "pyodide/" + nested
        }

        if !ext.isEmpty,
           let url = Bundle.main.url(
            forResource: base,
            withExtension: ext,
            subdirectory: subdirectory
           ) {
            return url
        }
        if ext.isEmpty,
           let url = Bundle.main.url(
            forResource: filename,
            withExtension: nil,
            subdirectory: subdirectory
           ) {
            return url
        }

        if let root = Bundle.main.resourceURL {
            let pyodideRoot = root
                .appendingPathComponent("pyodide", isDirectory: true)
                .standardizedFileURL
            let candidate = pyodideRoot
                .appendingPathComponent(relativePath)
                .standardizedFileURL
            let candidatePath = candidate.path
            let rootPath = pyodideRoot.path
            let inside = candidatePath == rootPath
                || candidatePath.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
            if inside, FileManager.default.fileExists(atPath: candidatePath) {
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: candidatePath, isDirectory: &isDir)
                if !isDir.boolValue {
                    return candidate
                }
            }
        }
        return nil
    }

    // MARK: - MIME

    private func mimeType(for relativePath: String) -> String {
        let ext = (relativePath as NSString).pathExtension.lowercased()
        switch ext {
        case "js":
            return "text/javascript"
        case "wasm":
            return "application/wasm"
        case "zip":
            return "application/zip"
        case "json":
            return "application/json"
        case "dat", "so":
            return "application/octet-stream"
        default:
            return "application/octet-stream"
        }
    }

    // MARK: - Task lifecycle (lock: never call into a stopped task)

    private func taskID(_ task: WKURLSchemeTask) -> ObjectIdentifier {
        ObjectIdentifier(task as AnyObject)
    }

    private func isCancelled(_ task: WKURLSchemeTask) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelledTasks.contains(taskID(task))
    }

    /// Drop in-flight / cancelled bookkeeping. Must be called under `lock`.
    private func forgetLocked(_ id: ObjectIdentifier) {
        inFlightTasks.remove(id)
        cancelledTasks.remove(id)
    }

    private func deliver(_ task: WKURLSchemeTask, response: URLResponse, data: Data) {
        lock.lock()
        defer { lock.unlock() }
        let id = taskID(task)
        if cancelledTasks.contains(id) {
            forgetLocked(id)
            return
        }
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
        forgetLocked(id)
    }

    private func fail(_ task: WKURLSchemeTask, error: Error) {
        lock.lock()
        defer { lock.unlock() }
        let id = taskID(task)
        if cancelledTasks.contains(id) {
            forgetLocked(id)
            return
        }
        task.didFailWithError(error)
        forgetLocked(id)
    }

    private enum SchemeError: Error, LocalizedError {
        case invalidURL
        case notFound

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "forgepy: invalid request URL"
            case .notFound:
                return "forgepy: asset not found"
            }
        }
    }
}

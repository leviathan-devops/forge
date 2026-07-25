import Foundation

/// ForgeGitManager (Stub — Phase 2 will add libgit2 via direct C bindings)
///
/// Per FORGE Engineering Specification §11.
/// Currently provides API-compatible stubs so the app builds without libgit2.
/// All methods return a "not configured" error. Real implementation will use
/// libgit2 compiled as a static library with a C bridging header.
final class ForgeGitManager {

    private let queue = DispatchQueue(label: "forge.git", qos: .userInitiated)

    struct GitError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    func gitOperation(
        _ args: [String: Any],
        callbackId: String?,
        webView: WKWebView?,
        projectRoot: String
    ) {
        guard let operation = args["operation"] as? String, let cbId = callbackId else {
            ForgeEngine.reject(webView, callbackId, "Missing operation")
            return
        }

        queue.async {
            // Phase 2: Real libgit2 implementation
            // For now, return a clear message so the agent knows Git isn't available
            let result: Any

            switch operation {
            case "init":
                // Create a .git directory placeholder
                let gitDir = (projectRoot as NSString).appendingPathComponent(".git")
                try? FileManager.default.createDirectory(
                    atPath: gitDir, withIntermediateDirectories: true
                )
                // Write a basic HEAD file
                try? "ref: refs/heads/main\n".write(
                    toFile: (gitDir as NSString).appendingPathComponent("HEAD"),
                    atomically: true, encoding: .utf8
                )
                result = true

            case "status":
                // Return empty status — no staged/modified/untracked files
                result = [
                    "staged": [[String: Any]](),
                    "modified": [[String: Any]](),
                    "untracked": [[String: Any]]()
                ] as [String: Any]

            case "log":
                // Return empty log
                result = [[String: Any]]()

            case "diff":
                result = ""

            case "add", "commit", "push", "pull", "fetch":
                // These require libgit2 — return informative error
                result = [
                    "success": false,
                    "message": "Git operations require libgit2 (Phase 2 feature). File was not modified."
                ] as [String: Any]

            default:
                result = ["success": false, "message": "Unknown git operation: \(operation)"]
            }

            ForgeEngine.resolve(webView, cbId, result)
        }
    }

    // MARK: - Utility

    /// Creates a basic .gitignore file in the project root
    func createDefaultGitignore(at projectRoot: String) {
        let gitignore = """
        # macOS
        .DS_Store

        # Xcode
        build/
        DerivedData/
        *.xcodeproj/
        *.xcworkspace/
        xcuserdata/

        # Swift Package Manager
        .build/
        .swiftpm/

        # Node
        node_modules/

        # Environment
        .env
        *.env.local
        """

        let path = (projectRoot as NSString).appendingPathComponent(".gitignore")
        try? gitignore.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

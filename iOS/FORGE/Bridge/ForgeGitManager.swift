import Foundation
import CLibgit2

/// ForgeGitManager
///
/// Per FORGE Engineering Specification §11.
///
/// A thin Swift wrapper around the libgit2 C library (provided by the
/// `swift-libgit2` SPM package). All Git operations requested by the
/// JavaScript agent are dispatched here on a dedicated serial queue so that
/// the libgit2 global state is never accessed concurrently.
///
/// Credentials (PAT, username) are read synchronously from `KeychainHelper`
/// inside the libgit2 credentials acquisition callback (§11.2).
final class ForgeGitManager {

    /// Serial queue ensuring libgit2 (which is not fully thread-safe for a
    /// single repository object) is never used concurrently.
    private let queue = DispatchQueue(label: "forge.git", qos: .userInitiated)

    // MARK: - GitError

    struct GitError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: - Dispatch

    /// Routes a Git operation requested by JavaScript. Each operation runs on
    /// the serial git queue and resolves or rejects the callback on the main
    /// thread.
    ///
    /// `resolve` / `reject` closures are injected by `ForgeBridge` so this
    /// class has no direct dependency on `WKWebView`.
    func gitOperation(
        _ args: [String: Any],
        operation: String,
        projectRoot: String,
        resolve: @escaping (Any) -> Void,
        reject: @escaping (String) -> Void
    ) {
        queue.async {
            do {
                let result: Any
                switch operation {
                case "init":
                    result = try self.gitInit(at: projectRoot)

                case "add":
                    let files = args["files"] as? [String] ?? ["."]
                    result = try self.gitAdd(files, at: projectRoot)

                case "commit":
                    let message = args["message"] as? String ?? "FORGE commit"
                    result = try self.gitCommit(message: message, at: projectRoot)

                case "push":
                    let remote = args["remote"] as? String ?? "origin"
                    let branch = args["branch"] as? String ?? "main"
                    result = try self.gitPush(remote: remote, branch: branch, at: projectRoot)

                case "diff":
                    result = try self.gitDiff(at: projectRoot)

                case "log":
                    let count = args["count"] as? Int ?? 20
                    result = try self.gitLog(count: count, at: projectRoot)

                case "status":
                    result = try self.gitStatus(at: projectRoot)

                default:
                    throw GitError(message: "Unknown git operation: \(operation)")
                }
                DispatchQueue.main.async { resolve(result) }
            } catch {
                let msg = error.localizedDescription
                DispatchQueue.main.async { reject("Git: \(msg)") }
            }
        }
    }

    // MARK: - Repository helpers

    /// Opens a repository, returning the opaque pointer and a `defer`-safe
    /// closure that frees it.
    private func openRepo(at path: String) throws -> OpaquePointer {
        var repo: OpaquePointer?
        let result = git_repository_open(&repo, path)
        guard result == 0, let opened = repo else {
            let error = gitErrorMessage(result)
            throw GitError(message: "Cannot open repository: \(error)")
        }
        return opened
    }

    /// Translates a libgit2 return code into a human-readable message.
    private func gitErrorMessage(_ code: Int32) -> String {
        if let lastError = git_error_last() {
            let msg = String(cString: lastError.pointee.message)
            return msg.isEmpty ? "git error \(code)" : msg
        }
        return "git error \(code)"
    }

    // MARK: - init

    func gitInit(at path: String) throws -> Bool {
        var repo: OpaquePointer?
        // 0 = bare=false (create a working-tree repository)
        let result = git_repository_init(&repo, path, 0)
        guard result == 0 else {
            throw GitError(message: "git init failed: \(gitErrorMessage(result))")
        }
        if let opened = repo {
            git_repository_free(opened)
        }
        return true
    }

    // MARK: - add

    /// Stages files. `["."]` stages the entire working tree (all changes,
    /// including untracked files within the project root).
    func gitAdd(_ files: [String], at path: String) throws -> Bool {
        let repo = try openRepo(at: path)
        defer { git_repository_free(repo) }

        var index: OpaquePointer?
        guard git_repository_index(&index, repo) == 0, let idx = index else {
            throw GitError(message: "Cannot open index")
        }
        defer { git_index_free(idx) }

        if files == ["."] {
            // Add all changes by enumerating the working tree and adding each
            // file by path. This avoids the fragile git_strarray C allocation
            // pattern while achieving the same "git add ." semantics.
            let enumerator = FileManager.default.enumerator(
                atPath: path,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            // Always include a .gitkeep / gitignore so the first commit has
            // content even when the project is empty.
            let fallback = path.hasSuffix("/") ? "\(path).gitignore" : "\(path)/.gitignore"
            var addedAny = false

            while let file = enumerator?.nextObject() as? String {
                // Compute the path relative to the repository root.
                let relativePath: String
                if file.hasPrefix("/") {
                    // Absolute — make relative to repo root.
                    if file.hasPrefix(path) {
                        relativePath = String(file.dropFirst(path.count).drop(while: { $0 == "/" }))
                    } else {
                        relativePath = file
                    }
                } else {
                    relativePath = file
                }

                // Skip the .git directory.
                if relativePath.hasPrefix(".git") { continue }

                let result = relativePath.withCString { ptr -> Int32 in
                    return git_index_add_bypath(idx, ptr)
                }
                if result == 0 {
                    addedAny = true
                }
            }

            // If nothing was added, create a placeholder so the commit can
            // proceed on a fresh repository.
            if !addedAny {
                let content = "# FORGE\n"
                try? content.write(toFile: fallback, atomically: true, encoding: .utf8)
                let rel = (fallback as NSString).lastPathComponent
                _ = rel.withCString { ptr -> Int32 in
                    git_index_add_bypath(idx, ptr)
                }
            }
        } else {
            for file in files {
                // Normalize the path to be relative to the repository root.
                let relativePath: String
                if file.hasPrefix("/") && file.hasPrefix(path) {
                    relativePath = String(file.dropFirst(path.count).drop(while: { $0 == "/" }))
                } else {
                    relativePath = file
                }
                let result = relativePath.withCString { ptr -> Int32 in
                    return git_index_add_bypath(idx, ptr)
                }
                guard result == 0 else {
                    throw GitError(message: "Cannot add \(file): \(gitErrorMessage(result))")
                }
            }
        }

        guard git_index_write(idx) == 0 else {
            throw GitError(message: "Cannot write index")
        }
        return true
    }

    // MARK: - commit

    func gitCommit(message: String, at path: String) throws -> String {
        let repo = try openRepo(at: path)
        defer { git_repository_free(repo) }

        // Gather the index and write it to a tree.
        var index: OpaquePointer?
        guard git_repository_index(&index, repo) == 0, let idx = index else {
            throw GitError(message: "Cannot open index")
        }
        defer { git_index_free(idx) }

        var treeId = git_oid()
        guard git_index_write_tree(&treeId, idx) == 0 else {
            throw GitError(message: "Cannot write tree")
        }

        var tree: OpaquePointer?
        guard git_tree_lookup(&tree, repo, &treeId) == 0, let treePtr = tree else {
            throw GitError(message: "Cannot look up tree")
        }
        defer { git_tree_free(treePtr) }

        // Create a signature from Keychain-configured identity (with sane
        // defaults).
        let signature = try makeSignature(repo: repo)
        defer { git_signature_free(signature) }

        // Determine the parent commit (HEAD if it exists).
        var parentCommit: OpaquePointer?
        var parentId = git_oid()
        let hasHead = git_reference_name_to_id(&parentId, repo, "HEAD") == 0
        if hasHead {
            git_commit_lookup(&parentCommit, repo, &parentId)
        }
        defer { if let pc = parentCommit { git_commit_free(pc) } }

        let parents: [OpaquePointer?] = parentCommit.map { [$0] } ?? []
        let newCommitId = try parents.withUnsafeBufferPointer { parentBuf -> git_oid in
            var commitId = git_oid()
            let parentPtr = parentBuf.baseAddress
            let result = git_commit_create(
                &commitId,
                repo,
                "HEAD",
                signature,
                signature,
                "UTF-8",
                message,
                treePtr,
                parentBuf.count,
                parentPtr
            )
            guard result == 0 else {
                throw GitError(message: "Cannot create commit: \(gitErrorMessage(result))")
            }
            return commitId
        }

        return git_oid_tostr_s(&newCommitId).map { String(cString: $0) } ?? ""
    }

    /// Builds a `git_signature` from Keychain git_username (or default) plus a
    /// fixed email, using the current time.
    private func makeSignature(repo: OpaquePointer) throws -> OpaquePointer {
        let name = KeychainHelper.loadSync(for: "git_username") ?? "FORGE"
        let email = "forge@local"
        var signature: OpaquePointer?
        let now = Int64(Date().timeIntervalSince1970)
        let result = name.withCString { nameC in
            email.withCString { emailC in
                git_signature_new(&signature, nameC, emailC, now, 0)
            }
        }
        guard result == 0, let sig = signature else {
            throw GitError(message: "Cannot create signature")
        }
        return sig
    }

    // MARK: - push

    func gitPush(remote: String, branch: String, at path: String) throws -> Bool {
        let repo = try openRepo(at: path)
        defer { git_repository_free(repo) }

        var gitRemote: OpaquePointer?
        let lookupResult = git_remote_lookup(&gitRemote, repo, remote)
        guard lookupResult == 0, let remotePtr = gitRemote else {
            throw GitError(message: "Remote not found: \(remote)")
        }
        defer { git_remote_free(remotePtr) }

        // Configure callbacks with a credentials acquisition closure that
        // reads the PAT from Keychain.
        var callbacks = git_remote_callbacks()
        git_remote_init_callbacks(&callbacks, UInt32(GIT_REMOTE_CALLBACKS_VERSION))

        // The credentials callback is a C function pointer. It captures no
        // context (the final `void *payload` is unused) and instead reads
        // directly from KeychainHelper — which is safe because KeychainHelper
        // is a synchronous, thread-safe static API.
        let credCallback: git_cred_acquire_cb = { cred, _, usernameFromURL, _, _ in
            let token = KeychainHelper.loadSync(for: "git_token") ?? ""
            let username = usernameFromURL.map { String(cString: $0) }
                ?? (KeychainHelper.loadSync(for: "git_username") ?? "git")
            return username.withCString { userC in
                token.withCString { tokenC in
                    git_cred_userpass_plaintext_new(cred, userC, tokenC)
                }
            }
        }
        callbacks.credentials = credCallback

        var pushOpts = git_push_options()
        git_push_init_options(&pushOpts, UInt32(GIT_PUSH_OPTIONS_VERSION))
        pushOpts.callbacks = callbacks

        let refspec = "refs/heads/\(branch):refs/heads/\(branch)"

        // Build the git_strarray safely: allocate C string copies, use them,
        // then free. This is the canonical safe Swift pattern for git_strarray.
        var refspecStrings: [UnsafeMutablePointer<CChar>?] = [strdup(refspec)]
        defer {
            for ptr in refspecStrings {
                if let p = ptr { free(p) }
            }
        }
        var refspecArray = git_strarray(count: 1, strings: &refspecStrings)

        let pushResult = git_remote_push(remotePtr, &refspecArray, &pushOpts)
        guard pushResult == 0 else {
            throw GitError(message: "Push failed: \(gitErrorMessage(pushResult))")
        }
        return true
    }

    // MARK: - diff

    /// Returns the working-tree diff as a unified-diff string.
    func gitDiff(at path: String) throws -> String {
        let repo = try openRepo(at: path)
        defer { git_repository_free(repo) }

        var diff: OpaquePointer?
        let diffOpts = git_diff_options()
        var opts = diffOpts
        git_diff_init_options(&opts, UInt32(GIT_DIFF_OPTIONS_VERSION))
        let diffResult = git_diff_index_to_workdir(&diff, repo, nil, &opts)
        guard diffResult == 0, let diffPtr = diff else {
            throw GitError(message: "Cannot compute diff: \(gitErrorMessage(diffResult))")
        }
        defer { git_diff_free(diffPtr) }

        var output = ""
        // We collect the diff text via the line callback. The callback is a C
        // function pointer (no captures), so we accumulate into a static
        // buffer that is safe because all git operations run on the serial
        // git queue.
        ForgeGitManager.sharedBuffer = ""
        git_diff_print(
            diffPtr,
            GIT_DIFF_FORMAT_PATCH,
            { _, _, line, _ in
                guard let line = line else { return 0 }
                let content = line.pointee.content
                let contentLen = Int(line.pointee.content_len)
                if let ptr = content {
                    // Safe conversion of the raw byte buffer to a Swift String.
                    let buffer = UnsafeBufferPointer(start: ptr, count: contentLen)
                    let text = String(decoding: buffer, as: UTF8.self)
                    ForgeGitManager.sharedBuffer.append(text)
                }
                return 0
            },
            nil
        )
        output = ForgeGitManager.sharedBuffer
        ForgeGitManager.sharedBuffer = ""
        return output
    }

    /// A transient buffer used by the diff line callback. libgit2 line
    /// callbacks are C function pointers with no capture, so we accumulate
    /// into this static and reset it after.
    private static var sharedBuffer = ""

    // MARK: - log

    /// Returns the last `count` commits as an array of dictionaries.
    func gitLog(count: Int, at path: String) throws -> [[String: Any]] {
        let repo = try openRepo(at: path)
        defer { git_repository_free(repo) }

        var revwalk: OpaquePointer?
        guard git_revwalk_new(&revwalk, repo) == 0, let walker = revwalk else {
            throw GitError(message: "Cannot create revwalk")
        }
        defer { git_revwalk_free(walker) }

        git_revwalk_sorting(walker, UInt32(GIT_SORT_TIME.rawValue))
        guard git_revwalk_push_head(walker) == 0 else {
            throw GitError(message: "Cannot push HEAD to revwalk")
        }

        var entries: [[String: Any]] = []
        var commitId = git_oid()
        var collected = 0
        while collected < count && git_revwalk_next(&commitId, walker) == 0 {
            var commit: OpaquePointer?
            guard git_commit_lookup(&commit, repo, &commitId) == 0,
                  let commitPtr = commit else {
                continue
            }
            defer { git_commit_free(commitPtr) }

            let hash = String(cString: git_oid_tostr_s(&commitId))
            let message = String(cString: git_commit_message(commitPtr))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let author = git_commit_author(commitPtr).pointee
            let authorName = author.name.map { String(cString: $0) } ?? "unknown"
            let date = Date(timeIntervalSince1970: TimeInterval(author.when.time))

            let formatter = ISO8601DateFormatter()
            entries.append([
                "hash": hash,
                "message": message,
                "author": authorName,
                "date": formatter.string(from: date),
            ])
            collected += 1
        }
        return entries
    }

    // MARK: - status

    /// Returns staged / modified / untracked file lists.
    func gitStatus(at path: String) throws -> [String: Any] {
        let repo = try openRepo(at: path)
        defer { git_repository_free(repo) }

        var opts = git_status_options()
        git_status_init_options(&opts, UInt32(GIT_STATUS_OPTIONS_VERSION))
        opts.show = GIT_STATUS_SHOW_INDEX_AND_WORKDIR
        opts.flags = UInt32(GIT_STATUS_OPT_INCLUDE_UNTRACKED.rawValue)
            | UInt32(GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX.rawValue)
            | UInt32(GIT_STATUS_OPT_SORT_CASE_SENSITIVELY.rawValue)

        var statusList: OpaquePointer?
        let listResult = git_status_list_new(&statusList, repo, &opts)
        guard listResult == 0, let list = statusList else {
            throw GitError(message: "Cannot create status list")
        }
        defer { git_status_list_free(list) }

        let entryCount = git_status_list_entrycount(list)
        var staged: [[String: Any]] = []
        var modified: [[String: Any]] = []
        var untracked: [[String: Any]] = []

        for i in 0..<entryCount {
            guard let entryPtr = git_status_byindex(list, i) else { continue }
            let entry = entryPtr.pointee
            let flags = entry.status.rawValue

            let stagedPath: String? = {
                if let file = entry.head_to_index {
                    return file.pointee.new_file.path.map { String(cString: $0) }
                }
                return nil
            }()

            let workdirPath: String? = {
                if let file = entry.index_to_workdir {
                    return file.pointee.new_file.path.map { String(cString: $0) }
                }
                return nil
            }()

            if flags & UInt32(GIT_STATUS_INDEX_NEW.rawValue) != 0
                || flags & UInt32(GIT_STATUS_INDEX_MODIFIED.rawValue) != 0
                || flags & UInt32(GIT_STATUS_INDEX_DELETED.rawValue) != 0 {
                if let p = stagedPath { staged.append(["path": p]) }
            }
            if flags & UInt32(GIT_STATUS_WT_MODIFIED.rawValue) != 0
                || flags & UInt32(GIT_STATUS_WT_DELETED.rawValue) != 0 {
                if let p = workdirPath { modified.append(["path": p]) }
            }
            if flags & UInt32(GIT_STATUS_WT_NEW.rawValue) != 0 {
                if let p = workdirPath { untracked.append(["path": p]) }
            }
        }

        return [
            "staged": staged,
            "modified": modified,
            "untracked": untracked,
        ]
    }

    // MARK: - C string helpers

    /// No custom C string helpers remain — strarray construction now uses
    /// `strdup` + `defer { free }` inline, which is the canonical safe
    /// Swift pattern for `git_strarray`.
}

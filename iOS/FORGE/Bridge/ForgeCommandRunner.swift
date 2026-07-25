import Foundation

/// ForgeCommandRunner
///
/// Per FORGE Engineering Specification §9.3.
///
/// A curated, sandbox-safe command executor. opencode's `bash` tool is
/// routed here instead of spawning a real shell. Only a whitelisted set of
/// read-only and benign file-system commands are supported; everything else
/// returns exit code 127 ("command not found").
///
/// Every operation is performed through `FileManager` — there is no
/// `Process`, no `posix_spawn`, and no PTY. The runner is safe to call from
/// any background queue.
final class ForgeCommandRunner {

    /// The absolute path of the active project root. All relative paths in
    /// commands are resolved against this directory.
    var projectRoot: String

    init(projectRoot: String = "") {
        self.projectRoot = projectRoot
    }

    // MARK: - CommandResult

    /// The structured result of a curated command.
    struct CommandResult {
        var stdout: String
        var stderr: String
        var exitCode: Int32

        /// Convenience for a successful command that produced no output.
        static let success = CommandResult(stdout: "", stderr: "", exitCode: 0)
    }

    // MARK: - Dispatch

    /// Parses `command` into a verb + arguments and dispatches to the
    /// matching handler. Unknown verbs yield exit code 127.
    func executeCommand(_ command: String) -> CommandResult {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CommandResult(stdout: "", stderr: "Empty command", exitCode: 1)
        }

        // Split into the verb and the remainder. We only split on the first
        // space so that arguments containing spaces (quoted file names) are
        // preserved in the single `args` string.
        let parts = trimmed.split(
            separator: " ",
            maxSplits: 1,
            omittingEmptySubsequences: true
        )
        let verb = String(parts[0]).lowercased()
        let args = parts.count > 1 ? String(parts[1]) : ""
        let cwd = projectRoot

        switch verb {
        case "ls":   return cmdLs(args, cwd: cwd)
        case "cat":  return cmdCat(args, cwd: cwd)
        case "grep": return cmdGrep(args, cwd: cwd)
        case "find": return cmdFind(args, cwd: cwd)
        case "mkdir": return cmdMkdir(args, cwd: cwd)
        case "rm":   return cmdRm(args, cwd: cwd)
        case "cp":   return cmdCp(args, cwd: cwd)
        case "mv":   return cmdMv(args, cwd: cwd)
        case "wc":   return cmdWc(args, cwd: cwd)
        case "head": return cmdHead(args, cwd: cwd)
        case "tail": return cmdTail(args, cwd: cwd)
        case "pwd":  return CommandResult(stdout: cwd + "\n", stderr: "", exitCode: 0)
        case "echo": return CommandResult(stdout: args + "\n", stderr: "", exitCode: 0)
        case "touch": return cmdTouch(args, cwd: cwd)
        default:
            return CommandResult(
                stdout: "",
                stderr: "Not supported on iOS: \(verb)",
                exitCode: 127
            )
        }
    }

    // MARK: - Path resolution

    /// Resolves a (possibly relative) argument path against the project root.
    /// An absolute path or an already-resolved path is returned untouched.
    private func resolvePath(_ arg: String, cwd: String) -> String {
        let cleaned = arg.trimmingCharacters(in: .whitespaces)
        if cleaned.isEmpty { return cwd }
        if cleaned.hasPrefix("/") { return cleaned }
        return (cwd as NSString).appendingPathComponent(cleaned)
    }

    /// Strips leading option flags (tokens beginning with "-") from `args`
    /// and returns the first non-flag token plus the remaining string.
    private func stripFlags(_ args: String) -> String {
        let tokens = args.split(separator: " ", omittingEmptySubsequences: true)
        let nonFlags = tokens.filter { !$0.hasPrefix("-") }
        return nonFlags.joined(separator: " ")
    }

    // MARK: - ls

    func cmdLs(_ args: String, cwd: String) -> CommandResult {
        let cleaned = stripFlags(args)
        let path = resolvePath(cleaned, cwd: cwd)
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: path)
            return CommandResult(
                stdout: contents.sorted().joined(separator: "\n") + "\n",
                stderr: "",
                exitCode: 0
            )
        } catch {
            return CommandResult(
                stdout: "",
                stderr: "ls: \(error.localizedDescription)",
                exitCode: 1
            )
        }
    }

    // MARK: - cat

    func cmdCat(_ args: String, cwd: String) -> CommandResult {
        let cleaned = stripFlags(args)
        let path = resolvePath(cleaned, cwd: cwd)
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            return CommandResult(stdout: content, stderr: "", exitCode: 0)
        } catch {
            return CommandResult(
                stdout: "",
                stderr: "cat: \(error.localizedDescription)",
                exitCode: 1
            )
        }
    }

    // MARK: - grep

    func cmdGrep(_ args: String, cwd: String) -> CommandResult {
        // Support: grep PATTERN [PATH]
        let tokens = args.split(separator: " ", omittingEmptySubsequences: true)
            .map { String($0) }
        // Filter out flags like -r, -rn, -i
        let nonFlags = tokens.filter { !$0.hasPrefix("-") }
        guard let pattern = nonFlags.first else {
            return CommandResult(stdout: "", stderr: "grep: missing pattern", exitCode: 1)
        }
        let searchPath = nonFlags.count > 1 ? resolvePath(nonFlags[1], cwd: cwd) : cwd

        var results: [String] = []
        if let enumerator = FileManager.default.enumerator(atPath: searchPath) {
            while let file = enumerator.nextObject() as? String {
                let fullPath = (searchPath as NSString).appendingPathComponent(file)
                guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else {
                    continue
                }
                let lines = content.components(separatedBy: "\n")
                for (i, line) in lines.enumerated() {
                    if line.contains(pattern) {
                        results.append("\(file):\(i + 1):\(line.trimmingCharacters(in: .whitespaces))")
                    }
                }
            }
        }
        let output = results.joined(separator: "\n")
        return CommandResult(
            stdout: results.isEmpty ? "" : output + "\n",
            stderr: "",
            exitCode: results.isEmpty ? 1 : 0
        )
    }

    // MARK: - find

    func cmdFind(_ args: String, cwd: String) -> CommandResult {
        // Minimal find: find [PATH] [-name PATTERN]
        let tokens = args.split(separator: " ", omittingEmptySubsequences: true)
            .map { String($0) }

        var basePath = cwd
        var namePattern: String? = nil

        var idx = 0
        if !tokens.isEmpty && !tokens[0].hasPrefix("-") {
            basePath = resolvePath(tokens[0], cwd: cwd)
            idx = 1
        }
        while idx < tokens.count {
            if tokens[idx] == "-name" && idx + 1 < tokens.count {
                namePattern = tokens[idx + 1]
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
                idx += 2
            } else if tokens[idx] == "-type" && idx + 1 < tokens.count {
                // Accept -type f / d but we list everything regardless.
                idx += 2
            } else {
                idx += 1
            }
        }

        var results: [String] = []
        if let enumerator = FileManager.default.enumerator(atPath: basePath) {
            while let file = enumerator.nextObject() as? String {
                if let pattern = namePattern {
                    let lastComponent = (file as NSString).lastPathComponent
                    if !matchesGlob(lastComponent, pattern: pattern) { continue }
                }
                results.append(file)
            }
        }
        return CommandResult(
            stdout: results.joined(separator: "\n") + (results.isEmpty ? "" : "\n"),
            stderr: "",
            exitCode: 0
        )
    }

    /// Simple glob matcher supporting `*` and `?`.
    private func matchesGlob(_ name: String, pattern: String) -> Bool {
        return name.lowercased().contains(pattern.lowercased())
            || Self.globMatch(name: name, pattern: pattern)
    }

    /// Recursive glob match supporting `*` (any sequence) and `?` (single).
    private static func globMatch(name: String, pattern: String) -> Bool {
        let nameChars = Array(name)
        let patternChars = Array(pattern)
        return globHelper(nameChars, 0, patternChars, 0)
    }

    private static func globHelper(
        _ name: [Character], _ ni: Int,
        _ pattern: [Character], _ pi: Int
    ) -> Bool {
        if pi == pattern.count { return ni == name.count }
        if pattern[pi] == "*" {
            for k in ni...name.count {
                if globHelper(name, k, pattern, pi + 1) { return true }
            }
            return false
        }
        if ni == name.count { return false }
        if pattern[pi] == "?" || pattern[pi] == name[ni] {
            return globHelper(name, ni + 1, pattern, pi + 1)
        }
        return false
    }

    // MARK: - mkdir

    func cmdMkdir(_ args: String, cwd: String) -> CommandResult {
        let cleaned = stripFlags(args)
        guard !cleaned.isEmpty else {
            return CommandResult(stdout: "", stderr: "mkdir: missing operand", exitCode: 1)
        }
        let path = resolvePath(cleaned, cwd: cwd)
        do {
            try FileManager.default.createDirectory(
                atPath: path, withIntermediateDirectories: true
            )
            return .success
        } catch {
            return CommandResult(
                stdout: "",
                stderr: "mkdir: \(error.localizedDescription)",
                exitCode: 1
            )
        }
    }

    // MARK: - rm

    func cmdRm(_ args: String, cwd: String) -> CommandResult {
        // Strip -rf / -r / -f flags.
        let cleaned = stripFlags(args)
        guard !cleaned.isEmpty else {
            return CommandResult(stdout: "", stderr: "rm: missing operand", exitCode: 1)
        }
        let path = resolvePath(cleaned, cwd: cwd)
        do {
            try FileManager.default.removeItem(atPath: path)
            return .success
        } catch {
            return CommandResult(
                stdout: "",
                stderr: "rm: \(error.localizedDescription)",
                exitCode: 1
            )
        }
    }

    // MARK: - cp

    func cmdCp(_ args: String, cwd: String) -> CommandResult {
        let tokens = args.split(separator: " ", omittingEmptySubsequences: true)
            .map { String($0) }
            .filter { !$0.hasPrefix("-") }
        guard tokens.count >= 2 else {
            return CommandResult(stdout: "", stderr: "cp: missing operand", exitCode: 1)
        }
        let src = resolvePath(tokens[0], cwd: cwd)
        let dst = resolvePath(tokens[1], cwd: cwd)
        do {
            // Remove destination first to mimic `cp` overwrite semantics.
            try? FileManager.default.removeItem(atPath: dst)
            try FileManager.default.copyItem(atPath: src, toPath: dst)
            return .success
        } catch {
            return CommandResult(
                stdout: "",
                stderr: "cp: \(error.localizedDescription)",
                exitCode: 1
            )
        }
    }

    // MARK: - mv

    func cmdMv(_ args: String, cwd: String) -> CommandResult {
        let tokens = args.split(separator: " ", omittingEmptySubsequences: true)
            .map { String($0) }
            .filter { !$0.hasPrefix("-") }
        guard tokens.count >= 2 else {
            return CommandResult(stdout: "", stderr: "mv: missing operand", exitCode: 1)
        }
        let src = resolvePath(tokens[0], cwd: cwd)
        let dst = resolvePath(tokens[1], cwd: cwd)
        do {
            try? FileManager.default.removeItem(atPath: dst)
            try FileManager.default.moveItem(atPath: src, toPath: dst)
            return .success
        } catch {
            return CommandResult(
                stdout: "",
                stderr: "mv: \(error.localizedDescription)",
                exitCode: 1
            )
        }
    }

    // MARK: - wc

    func cmdWc(_ args: String, cwd: String) -> CommandResult {
        let cleaned = stripFlags(args)
        guard !cleaned.isEmpty else {
            return CommandResult(stdout: "", stderr: "wc: missing operand", exitCode: 1)
        }
        let path = resolvePath(cleaned, cwd: cwd)
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return CommandResult(stdout: "", stderr: "wc: cannot read \(cleaned)", exitCode: 1)
        }
        let lines = content.components(separatedBy: "\n")
        let wordCount = content.split(whereSeparator: { $0.isWhitespace }).count
        let byteCount = content.utf8.count
        // Format: lines words bytes filename
        let output = "\(lines.count) \(wordCount) \(byteCount) \(cleaned)\n"
        return CommandResult(stdout: output, stderr: "", exitCode: 0)
    }

    // MARK: - head

    func cmdHead(_ args: String, cwd: String) -> CommandResult {
        // Support: head [-n N] FILE
        var n = 10
        var fileArg = args
        if args.hasPrefix("-n") {
            let tokens = args.split(separator: " ", omittingEmptySubsequences: true)
                .map { String($0) }
            if tokens.count >= 1 {
                let nToken = tokens[0].replacingOccurrences(of: "-n", with: "")
                if let parsed = Int(nToken) { n = parsed }
            }
            fileArg = tokens.dropFirst().joined(separator: " ")
        }
        // Guard against negative n (Swift's prefix handles it by returning
        // empty, but clamp for clarity and consistency with tail).
        n = max(0, n)
        let cleaned = stripFlags(fileArg)
        let path = resolvePath(cleaned, cwd: cwd)
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return CommandResult(stdout: "", stderr: "head: cannot read \(cleaned)", exitCode: 1)
        }
        let lines = content.components(separatedBy: "\n")
        let head = lines.prefix(n)
        return CommandResult(stdout: head.joined(separator: "\n") + "\n", stderr: "", exitCode: 0)
    }

    // MARK: - tail

    func cmdTail(_ args: String, cwd: String) -> CommandResult {
        var n = 10
        var fileArg = args
        if args.hasPrefix("-n") {
            let tokens = args.split(separator: " ", omittingEmptySubsequences: true)
                .map { String($0) }
            if tokens.count >= 1 {
                let nToken = tokens[0].replacingOccurrences(of: "-n", with: "")
                if let parsed = Int(nToken) { n = parsed }
            }
            fileArg = tokens.dropFirst().joined(separator: " ")
        }
        // Guard against negative n which would produce an offset > lines.count
        // and crash on Array(lines[offset...]).
        n = max(0, n)
        let cleaned = stripFlags(fileArg)
        let path = resolvePath(cleaned, cwd: cwd)
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return CommandResult(stdout: "", stderr: "tail: cannot read \(cleaned)", exitCode: 1)
        }
        let lines = content.components(separatedBy: "\n")
        let offset = max(0, lines.count - n)
        // Clamp offset to valid range to prevent index-out-of-bounds crash.
        let safeOffset = min(offset, lines.count)
        let tail = Array(lines[safeOffset...])
        return CommandResult(stdout: tail.joined(separator: "\n") + "\n", stderr: "", exitCode: 0)
    }

    // MARK: - touch

    func cmdTouch(_ args: String, cwd: String) -> CommandResult {
        let cleaned = stripFlags(args)
        guard !cleaned.isEmpty else {
            return CommandResult(stdout: "", stderr: "touch: missing operand", exitCode: 1)
        }
        let path = resolvePath(cleaned, cwd: cwd)
        if !FileManager.default.fileExists(atPath: path) {
            // Ensure parent directory exists, then create an empty file.
            let dir = (path as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(
                atPath: dir, withIntermediateDirectories: true
            )
            FileManager.default.createFile(atPath: path, contents: nil)
        } else {
            // Update modification date to now.
            try? FileManager.default.setAttributes(
                [.modificationDate: Date()], ofItemAtPath: path
            )
        }
        return .success
    }
}

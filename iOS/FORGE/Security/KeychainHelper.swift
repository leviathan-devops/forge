import Foundation
import Security

/// KeychainHelper
///
/// Per FORGE Engineering Specification §13.1.
///
/// Provides synchronous CRUD operations against the iOS Keychain for all
/// secret material used by the app: LLM API keys, Git PATs, and Mission
/// Control bearer tokens.
///
/// All entries use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — the value
/// is readable only while the device is unlocked and is NEVER synced to
/// iCloud Keychain, ensuring device-local credential isolation (§13.2, §23.2).
struct KeychainHelper {

    /// The Keychain service identifier. Groups every FORGE secret together
    /// and isolates them from other apps in the same keychain access group.
    static let service = "com.forge.app"

    // MARK: - KeychainError

    enum KeychainError: Error, LocalizedError {
        case unexpectedStatus(OSStatus)
        case dataConversionFailed

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                return "Keychain operation failed with status \(status)"
            case .dataConversionFailed:
                return "Keychain: failed to convert value to UTF-8 data"
            }
        }
    }

    // MARK: - Save

    /// Persists `value` under `key`, replacing any existing entry.
    ///
    /// The write is performed as a delete-then-add to guarantee idempotent
    /// updates (SecItemAdd returns errSecDuplicateItem otherwise).
    static func save(_ value: String, for key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        // Remove any pre-existing entry first (idempotent overwrite).
        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Load (synchronous)

    /// Synchronously reads the value stored under `key`.
    ///
    /// Designed for use inside synchronous contexts such as the libgit2
    /// credentials callback (§11.2) where an async API would be unusable.
    /// Returns `nil` if no entry exists or the value cannot be decoded.
    static func loadSync(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    // MARK: - Load (async bridge)

    /// Asynchronous wrapper that performs the read on a background queue and
    /// delivers the result on the main thread. Used by the bridge methods
    /// that want a clean async interface.
    static func load(for key: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let value = loadSync(for: key)
            DispatchQueue.main.async { completion(value) }
        }
    }

    // MARK: - Delete

    /// Removes the entry for `key`. Silently succeeds when no entry exists.
    static func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Exists

    /// Returns `true` when an entry exists for `key` (regardless of value).
    static func exists(for key: String) -> Bool {
        return loadSync(for: key) != nil
    }
}

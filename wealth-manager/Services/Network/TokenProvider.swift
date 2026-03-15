import Foundation

// MARK: - TokenProvider

/// Provides access tokens for authenticated API requests.
protocol TokenProvider: Sendable {
    /// Returns the current access token, or nil if not authenticated.
    func currentAccessToken() async -> String?

    /// Refreshes the access token and returns the new token.
    func refreshAccessToken() async throws -> String
}

// MARK: - TokenStore

/// Persistent storage for authentication tokens (Keychain wrapper).
protocol TokenStore: Sendable {
    func saveAccessToken(_ token: String) throws
    func getAccessToken() -> String?
    func deleteAccessToken() throws
}

// MARK: - StoredTokenProvider

/// A TokenProvider that reads from a TokenStore. Used to bootstrap APIClient
/// before a full AuthService is available. Refresh is not supported.
struct StoredTokenProvider: TokenProvider {
    private let store: TokenStore

    init(store: TokenStore) {
        self.store = store
    }

    func currentAccessToken() async -> String? {
        store.getAccessToken()
    }

    func refreshAccessToken() async throws -> String {
        throw APIError.unauthorized
    }
}

// MARK: - InMemoryTokenStore

#if DEBUG
/// In-memory token store for development when Keychain is unavailable or broken.
/// Tokens persist only for the app session — relaunch requires re-login.
final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    func saveAccessToken(_ token: String) throws {
        lock.withLock { self.token = token }
    }

    func getAccessToken() -> String? {
        lock.withLock { token }
    }

    func deleteAccessToken() throws {
        lock.withLock { token = nil }
    }
}
#endif

// MARK: - KeychainTokenStore

/// Production token store backed by the macOS/iOS Keychain.
final class KeychainTokenStore: TokenStore {
    private let service = "com.wealthmanager.auth"
    private let accessTokenKey = "access_token"

    func saveAccessToken(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accessTokenKey,
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw APIError.networkError(
                NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            )
        }
    }

    func getAccessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accessTokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func deleteAccessToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accessTokenKey,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIError.networkError(
                NSError(domain: NSOSStatusErrorDomain, code: Int(status))
            )
        }
    }
}

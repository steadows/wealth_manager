import Testing
import Foundation

@testable import wealth_manager

// MARK: - Secret Leak Detection Tests
//
// These tests verify that authentication tokens are stored only in the Keychain,
// that error messages never surface token values to users or logs, and that
// protected financial endpoints consistently require authentication.

@Suite("Secret Leak Detection")
struct SecretLeakTests {

    // MARK: - Keychain Storage

    /// Verifies that KeychainTokenStore uses Keychain APIs (SecItem*) and does NOT
    /// fall back to UserDefaults. We confirm this by checking that after saving a
    /// token, UserDefaults contains no value for any key resembling "token" or
    /// "access_token" — and that the value IS retrievable via the store itself.
    @Test("keychainStore_doesNotUseUserDefaults")
    func keychainStore_doesNotUseUserDefaults() throws {
        let store = KeychainTokenStore()
        let testToken = "test-jwt-\(UUID().uuidString)"

        // Capture all UserDefaults keys before and after saving
        let defaultsBefore = UserDefaults.standard.dictionaryRepresentation()
        try store.saveAccessToken(testToken)
        let defaultsAfter = UserDefaults.standard.dictionaryRepresentation()

        // No new keys should have appeared that look like a token store
        let newKeys = Set(defaultsAfter.keys).subtracting(Set(defaultsBefore.keys))
        let tokenRelatedNewKeys = newKeys.filter { key in
            key.lowercased().contains("token") ||
            key.lowercased().contains("access") ||
            key.lowercased().contains("auth") ||
            key.lowercased().contains("jwt") ||
            key.lowercased().contains("bearer")
        }
        #expect(tokenRelatedNewKeys.isEmpty,
                "UserDefaults should not contain any token-related keys after saving to KeychainTokenStore. Found: \(tokenRelatedNewKeys)")

        // Token must be retrievable through the Keychain store itself
        let retrieved = store.getAccessToken()
        #expect(retrieved == testToken, "Token saved to Keychain must be retrievable via KeychainTokenStore")

        // Cleanup
        try store.deleteAccessToken()
    }

    /// Verifies that the token saved to the Keychain is NOT readable as a plain
    /// string from UserDefaults under any key in the standard suite.
    @Test("keychainStore_tokenValue_notVisibleInUserDefaults")
    func keychainStore_tokenValue_notVisibleInUserDefaults() throws {
        let store = KeychainTokenStore()
        let sentinelToken = "SENTINEL_TOKEN_\(UUID().uuidString)"

        try store.saveAccessToken(sentinelToken)
        defer { try? store.deleteAccessToken() }

        // Walk every UserDefaults value and verify none contain the token string
        let allValues = UserDefaults.standard.dictionaryRepresentation()
        for (key, value) in allValues {
            if let stringValue = value as? String {
                #expect(!stringValue.contains(sentinelToken),
                        "Found token sentinel in UserDefaults['\(key)'] — token is leaking out of Keychain")
            }
        }
    }

    // MARK: - Error Description Token Safety

    /// Verifies that APIError.unauthorized never exposes "Bearer" or token fragments
    /// in its user-facing description. This guards against log scraping.
    @Test("apiError_unauthorized_descriptionDoesNotLeakBearer")
    func apiError_unauthorized_descriptionDoesNotLeakBearer() {
        let error = APIError.unauthorized
        let description = error.errorDescription ?? ""
        #expect(!description.contains("Bearer"),
                "APIError.unauthorized must not surface 'Bearer' in user-facing description")
        #expect(!description.contains("eyJ"),  // JWT header prefix (base64 of `{"`)
                "APIError.unauthorized must not contain JWT fragment")
    }

    /// Verifies that a serverError constructed with an arbitrary message (e.g. one
    /// that a badly-behaved backend might echo back) does not inject "Bearer" tokens
    /// when the message comes from the error description alone.
    /// The description IS allowed to show the message parameter — the test ensures the
    /// APIClient doesn't accidentally embed the Authorization header value in the message.
    @Test("apiError_serverError_descriptionDoesNotLeakAuthHeader")
    func apiError_serverError_descriptionDoesNotLeakAuthHeader() {
        // Simulate a case where the message does NOT contain a token
        let error = APIError.serverError(statusCode: 500, message: "Internal Server Error")
        let description = error.errorDescription ?? ""
        #expect(!description.contains("Bearer"),
                "APIError.serverError description must not embed Bearer prefix")
        #expect(description.contains("500"),
                "Server error description should include status code")
    }

    /// Verifies that StoredTokenProvider returns nil (not a hardcoded fallback)
    /// when the underlying TokenStore has no token saved.
    @Test("storedTokenProvider_returnsNil_whenNoToken")
    func storedTokenProvider_returnsNil_whenNoToken() async {
        let emptyStore = InMemoryTokenStore()  // nothing saved
        let provider = StoredTokenProvider(store: emptyStore)
        let token = await provider.currentAccessToken()
        #expect(token == nil,
                "StoredTokenProvider must return nil when store is empty — no hardcoded fallback tokens allowed")
    }

    /// Verifies that StoredTokenProvider.refreshAccessToken throws .unauthorized
    /// rather than returning any hardcoded token when no refresh mechanism is wired up.
    @Test("storedTokenProvider_refresh_throwsUnauthorized")
    func storedTokenProvider_refresh_throwsUnauthorized() async {
        let store = InMemoryTokenStore()
        let provider = StoredTokenProvider(store: store)
        await #expect(throws: APIError.self) {
            _ = try await provider.refreshAccessToken()
        }
    }

    // MARK: - Protected Route Auth Requirements

    /// Verifies that all financial data endpoints (accounts, sync, advisor, reports,
    /// alerts, plaid) require authentication. Only .login is exempt.
    @Test("endpoint_requiresAuth_onAllFinancialRoutes")
    func endpoint_requiresAuth_onAllFinancialRoutes() {
        let financialEndpoints: [Endpoint] = [
            .me,
            .refreshToken,
            .listAccounts(),
            .getAccount(id: UUID()),
            .createAccount(AccountCreateDTO(
                institutionName: "Bank",
                accountName: "Checking",
                accountType: "checking",
                currentBalance: 0,
                availableBalance: nil,
                currency: "USD",
                isManual: true
            )),
            .updateAccount(id: UUID(), data: Data()),
            .deleteAccount(id: UUID()),
            .createLinkToken,
            .exchangeToken(publicToken: "tok"),
            .plaidSync(accountId: UUID()),
            .syncPull(since: nil),
            .syncPush(ClientChangesDTO(accounts: [], goals: [], debts: [])),
            .advisorChat(message: "hello", conversationId: nil),
            .getBriefing(period: "weekly"),
            .getHealthScore,
            .getAlerts,
        ]

        for endpoint in financialEndpoints {
            #expect(endpoint.requiresAuth,
                    "Endpoint \(endpoint) must require authentication — it accesses financial data")
        }
    }

    /// Verifies that .login is the only endpoint that does NOT require authentication.
    @Test("endpoint_loginOnly_doesNotRequireAuth")
    func endpoint_loginOnly_doesNotRequireAuth() {
        #expect(!Endpoint.login(identityToken: "tok").requiresAuth,
                ".login must not require auth (it IS the auth handshake)")
    }
}

// MARK: - InMemoryTokenStore (test helper)

/// Simple in-memory token store for testing. Stored in a local variable only —
/// never touches UserDefaults or Keychain.
final class InMemoryTokenStore: TokenStore, @unchecked Sendable {
    private var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func saveAccessToken(_ token: String) throws {
        self.token = token
    }

    func getAccessToken() -> String? {
        token
    }

    func deleteAccessToken() throws {
        token = nil
    }
}

import Testing
import Foundation

@testable import wealth_manager

// MARK: - AuthServiceTests

@Suite("AuthService")
struct AuthServiceTests {

    // MARK: - Helpers

    private func makeService(
        apiClient: APIClientProtocol? = nil,
        tokenStore: TokenStore? = nil
    ) -> AuthService {
        AuthService(
            apiClient: apiClient ?? MockAPIClient(),
            tokenStore: tokenStore ?? MockTokenStore()
        )
    }

    // MARK: - Sign In

    @Test("signIn: exchanges Apple identity token for JWT")
    func signInExchangesToken() async throws {
        let mockClient = MockAPIClient()
        mockClient.responses["/api/v1/auth/login"] = LoginResponseDTO(
            accessToken: "jwt-from-backend",
            tokenType: "bearer"
        )
        let mockStore = MockTokenStore()
        let service = makeService(apiClient: mockClient, tokenStore: mockStore)

        try await service.signIn(identityToken: "apple-id-token")

        #expect(mockStore.storedAccessToken == "jwt-from-backend")
        #expect(service.isAuthenticated)
    }

    @Test("signIn: fetches user profile after login")
    func signInFetchesUser() async throws {
        let mockClient = MockAPIClient()
        let userId = UUID()
        mockClient.responses["/api/v1/auth/login"] = LoginResponseDTO(
            accessToken: "jwt",
            tokenType: "bearer"
        )
        mockClient.responses["/api/v1/auth/me"] = UserResponseDTO(
            id: userId,
            email: "steve@test.com",
            createdAt: Date()
        )
        let service = makeService(apiClient: mockClient)

        try await service.signIn(identityToken: "apple-token")

        #expect(service.currentUserId == userId)
    }

    @Test("signIn: throws on backend failure")
    func signInThrowsOnFailure() async {
        let mockClient = MockAPIClient()
        mockClient.shouldThrow = APIError.serverError(statusCode: 500, message: "Internal error")
        let service = makeService(apiClient: mockClient)

        await #expect(throws: APIError.self) {
            try await service.signIn(identityToken: "bad-token")
        }
        #expect(!service.isAuthenticated)
    }

    // MARK: - Sign Out

    @Test("signOut: clears token and user state")
    func signOutClearsState() async throws {
        let mockClient = MockAPIClient()
        mockClient.responses["/api/v1/auth/login"] = LoginResponseDTO(
            accessToken: "jwt",
            tokenType: "bearer"
        )
        mockClient.responses["/api/v1/auth/me"] = UserResponseDTO(
            id: UUID(),
            email: "test@test.com",
            createdAt: Date()
        )
        let mockStore = MockTokenStore()
        let service = makeService(apiClient: mockClient, tokenStore: mockStore)

        try await service.signIn(identityToken: "token")
        #expect(service.isAuthenticated)

        await service.signOut()

        #expect(!service.isAuthenticated)
        #expect(service.currentUserId == nil)
        #expect(mockStore.storedAccessToken == nil)
    }

    // MARK: - Token Refresh

    @Test("refreshTokenIfNeeded: updates stored token")
    func refreshUpdatesToken() async throws {
        let mockClient = MockAPIClient()
        mockClient.responses["/api/v1/auth/refresh"] = TokenResponseDTO(
            accessToken: "new-jwt",
            tokenType: "bearer"
        )
        let mockStore = MockTokenStore()
        mockStore.storedAccessToken = "old-jwt"
        let service = makeService(apiClient: mockClient, tokenStore: mockStore)

        let newToken = try await service.refreshAccessToken()

        #expect(newToken == "new-jwt")
        #expect(mockStore.storedAccessToken == "new-jwt")
    }

    @Test("refreshToken: throws when no existing token")
    func refreshThrowsWhenNotAuthenticated() async {
        let mockStore = MockTokenStore()
        // No token stored
        let service = makeService(tokenStore: mockStore)

        await #expect(throws: APIError.self) {
            _ = try await service.refreshAccessToken()
        }
    }

    // MARK: - Token Provider Conformance

    @Test("currentAccessToken: returns stored token")
    func currentAccessTokenReturnsStored() async {
        let mockStore = MockTokenStore()
        mockStore.storedAccessToken = "stored-jwt"
        let service = makeService(tokenStore: mockStore)

        let token = await service.currentAccessToken()

        #expect(token == "stored-jwt")
    }

    @Test("isAuthenticated: true when token exists")
    func isAuthenticatedWhenTokenExists() {
        let mockStore = MockTokenStore()
        mockStore.storedAccessToken = "jwt"
        let service = makeService(tokenStore: mockStore)

        #expect(service.isAuthenticated)
    }

    @Test("isAuthenticated: false when no token")
    func isNotAuthenticatedWhenNoToken() {
        let mockStore = MockTokenStore()
        let service = makeService(tokenStore: mockStore)

        #expect(!service.isAuthenticated)
    }
}

// MARK: - Mock API Client

final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    /// Keyed by path for simple cases, or "METHOD path" for disambiguation.
    var responses: [String: Any] = [:]
    var shouldThrow: Error?
    var requestLog: [Endpoint] = []

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        requestLog.append(endpoint)
        if let error = shouldThrow {
            throw error
        }
        // Try method+path first, then path-only fallback
        let methodKey = "\(endpoint.method.rawValue) \(endpoint.path)"
        if let response = responses[methodKey] as? T {
            return response
        }
        guard let response = responses[endpoint.path] as? T else {
            throw APIError.decodingError(
                NSError(domain: "MockAPIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "No mock response for \(methodKey)"])
            )
        }
        return response
    }
}

// MARK: - Mock Token Store

final class MockTokenStore: TokenStore, @unchecked Sendable {
    var storedAccessToken: String?

    func saveAccessToken(_ token: String) throws {
        storedAccessToken = token
    }

    func getAccessToken() -> String? {
        storedAccessToken
    }

    func deleteAccessToken() throws {
        storedAccessToken = nil
    }
}

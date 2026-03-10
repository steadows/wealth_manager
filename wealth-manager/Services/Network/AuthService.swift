import Foundation

// MARK: - AuthService

/// Manages authentication state: sign in with Apple, token storage, refresh.
/// Conforms to TokenProvider so APIClient can use it for token injection/refresh.
final class AuthService: TokenProvider, @unchecked Sendable {
    private let apiClient: APIClientProtocol
    private let tokenStore: TokenStore

    private(set) var currentUserId: UUID?

    init(apiClient: APIClientProtocol, tokenStore: TokenStore) {
        self.apiClient = apiClient
        self.tokenStore = tokenStore
    }

    // MARK: - Authentication State

    var isAuthenticated: Bool {
        tokenStore.getAccessToken() != nil
    }

    // MARK: - Sign In

    /// Exchanges an Apple identity token for a JWT and stores it.
    func signIn(identityToken: String) async throws {
        let loginResponse: LoginResponseDTO = try await apiClient.request(
            .login(identityToken: identityToken)
        )
        try tokenStore.saveAccessToken(loginResponse.accessToken)

        // Fetch user profile
        await fetchCurrentUser()
    }

    // MARK: - Sign Out

    /// Clears all authentication state.
    func signOut() async {
        try? tokenStore.deleteAccessToken()
        currentUserId = nil
    }

    // MARK: - TokenProvider

    func currentAccessToken() async -> String? {
        tokenStore.getAccessToken()
    }

    func refreshAccessToken() async throws -> String {
        guard tokenStore.getAccessToken() != nil else {
            throw APIError.unauthorized
        }

        let response: TokenResponseDTO = try await apiClient.request(.refreshToken)
        try tokenStore.saveAccessToken(response.accessToken)
        return response.accessToken
    }

    // MARK: - Private

    private func fetchCurrentUser() async {
        do {
            let user: UserResponseDTO = try await apiClient.request(.me)
            currentUserId = user.id
        } catch {
            // Non-fatal: we have the token, user info is supplementary
        }
    }
}

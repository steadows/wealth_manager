import Foundation

// MARK: - Auth Notifications

extension Notification.Name {
    /// Posted when authentication is irrecoverably lost (token expired and refresh failed).
    /// Observers should reset UI to the sign-in screen.
    static let authSessionExpired = Notification.Name("WMAuthSessionExpired")
}

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

        do {
            let response: TokenResponseDTO = try await apiClient.request(.refreshToken)
            try tokenStore.saveAccessToken(response.accessToken)
            return response.accessToken
        } catch {
            // Refresh failed (likely expired token) — clear stale token
            // so isAuthenticated becomes false and app redirects to sign-in.
            try? tokenStore.deleteAccessToken()
            currentUserId = nil
            NotificationCenter.default.post(name: .authSessionExpired, object: nil)
            throw APIError.unauthorized
        }
    }

    // MARK: - Dev Sign In

    #if DEBUG
    /// Signs in with a fake JWT containing `sub=dev-local-user`.
    /// Used for local development when the backend is in sandbox mode
    /// and does not verify token signatures.
    func devSignIn() async throws {
        let header = Data(#"{"alg":"none","typ":"JWT"}"#.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let now = Int(Date().timeIntervalSince1970)
        let payload = Data(#"{"sub":"dev-local-user","email":"dev@local.test","iat":\#(now)}"#.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let fakeJWT = "\(header).\(payload)."

        try await signIn(identityToken: fakeJWT)
    }
    #endif

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

#if DEBUG
import Foundation
import Observation

// MARK: - DevAuthProvider

/// Protocol for dev sign-in, enabling mock injection in tests.
protocol DevAuthProvider: Sendable {
    var isAuthenticated: Bool { get }
    func devSignIn() async throws
}

// MARK: - AuthService + DevAuthProvider

extension AuthService: DevAuthProvider {}

// MARK: - DevLoginViewModel

/// ViewModel for the developer sign-in screen.
/// Uses AuthService.devSignIn() to authenticate with a fake JWT
/// and checks backend health via the /health endpoint.
@Observable
final class DevLoginViewModel: @unchecked Sendable {
    private let authProvider: DevAuthProvider
    private let healthAPIClient: APIClientProtocol?

    var isSignedIn: Bool = false
    var isLoading: Bool = false
    var isBackendReachable: Bool?
    var error: String?

    /// Initializes with any DevAuthProvider (AuthService or mock).
    init(authService: DevAuthProvider, healthAPIClient: APIClientProtocol? = nil) {
        self.authProvider = authService
        self.healthAPIClient = healthAPIClient
    }

    /// Attempts dev sign-in via a fake JWT.
    func signIn() async {
        isLoading = true
        error = nil
        do {
            try await authProvider.devSignIn()
            isSignedIn = true
        } catch {
            self.error = error.localizedDescription
            isSignedIn = false
        }
        isLoading = false
    }

    /// Checks if the backend is reachable via GET /health.
    func checkBackendHealth() async {
        guard let client = healthAPIClient else {
            isBackendReachable = nil
            return
        }
        do {
            let _: HealthResponseDTO = try await client.request(.health)
            isBackendReachable = true
        } catch {
            isBackendReachable = false
        }
    }
}
#endif

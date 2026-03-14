import Testing
import Foundation

@testable import wealth_manager

// MARK: - DevSignInTests

@Suite("DevSignIn")
struct DevSignInTests {

    // MARK: - Helpers

    private func makeService(
        apiClient: MockAPIClient = MockAPIClient(),
        tokenStore: MockTokenStore = MockTokenStore()
    ) -> (AuthService, MockAPIClient, MockTokenStore) {
        let service = AuthService(apiClient: apiClient, tokenStore: tokenStore)
        return (service, apiClient, tokenStore)
    }

    // MARK: - devSignIn

    @Test("devSignIn calls login endpoint and stores returned token")
    func devSignInCallsLoginAndStoresToken() async throws {
        let mockClient = MockAPIClient()
        mockClient.responses["/api/v1/auth/login"] = LoginResponseDTO(
            accessToken: "backend-dev-token",
            tokenType: "bearer"
        )
        let mockStore = MockTokenStore()
        let service = AuthService(apiClient: mockClient, tokenStore: mockStore)

        try await service.devSignIn()

        #expect(mockStore.storedAccessToken == "backend-dev-token")
        #expect(service.isAuthenticated)
    }

    @Test("devSignIn sends a JWT with sub=dev-local-user")
    func devSignInSendsDevJWT() async throws {
        let mockClient = MockAPIClient()
        mockClient.responses["/api/v1/auth/login"] = LoginResponseDTO(
            accessToken: "dev-token",
            tokenType: "bearer"
        )
        let mockStore = MockTokenStore()
        let service = AuthService(apiClient: mockClient, tokenStore: mockStore)

        try await service.devSignIn()

        // The login endpoint should have been called
        #expect(mockClient.requestLog.count >= 1)
        let loginEndpoint = mockClient.requestLog.first
        if case .login(let identityToken) = loginEndpoint {
            // JWT format: header.payload. (empty signature for alg:none)
            #expect(identityToken.hasSuffix("."))
            // Split keeping empty subsequences to handle trailing dot
            let parts = identityToken.components(separatedBy: ".")
            #expect(parts.count == 3) // header, payload, empty signature
            // Base64 decode the payload (second part)
            var payloadBase64 = parts[1]
            // Add padding if needed
            while payloadBase64.count % 4 != 0 {
                payloadBase64 += "="
            }
            if let payloadData = Data(base64Encoded: payloadBase64),
               let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                #expect(json["sub"] as? String == "dev-local-user")
                #expect(json["email"] as? String == "dev@local.test")
            } else {
                Issue.record("Could not decode JWT payload")
            }
        } else {
            Issue.record("Expected login endpoint call, got: \(String(describing: loginEndpoint))")
        }
    }

    @Test("devSignIn throws when backend returns error")
    func devSignInThrowsOnFailure() async {
        let mockClient = MockAPIClient()
        mockClient.shouldThrow = APIError.serverError(statusCode: 500, message: "Server error")
        let mockStore = MockTokenStore()
        let service = AuthService(apiClient: mockClient, tokenStore: mockStore)

        await #expect(throws: APIError.self) {
            try await service.devSignIn()
        }
        #expect(!service.isAuthenticated)
    }
}

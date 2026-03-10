import Foundation

// MARK: - PlaidLinkServiceProtocol

/// Protocol for Plaid Link operations, enabling mock injection in tests.
protocol PlaidLinkServiceProtocol: Sendable {
    /// Requests a link token from the backend for initializing Plaid Link.
    func createLinkToken() async throws -> String

    /// Exchanges a Plaid public token for permanent access and returns linked accounts.
    func exchangeToken(publicToken: String) async throws -> [Account]

    /// Constructs the Plaid Link URL for the given link token.
    func linkURL(for linkToken: String) -> URL
}

// MARK: - PlaidLinkService

/// Production implementation that communicates with the backend's Plaid endpoints.
final class PlaidLinkService: PlaidLinkServiceProtocol, @unchecked Sendable {

    private let apiClient: APIClientProtocol

    private static let plaidLinkBaseURL = "https://cdn.plaid.com/link/v2/stable/link.html"

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    /// Calls `POST /api/v1/plaid/link-token` to obtain a Plaid Link token.
    func createLinkToken() async throws -> String {
        let response: PlaidLinkResponseDTO = try await apiClient.request(.createLinkToken)
        return response.linkToken
    }

    /// Calls `POST /api/v1/plaid/exchange-token` with the public token
    /// and converts the returned DTOs to local Account models.
    func exchangeToken(publicToken: String) async throws -> [Account] {
        let response: PlaidExchangeResponseDTO = try await apiClient.request(
            .exchangeToken(publicToken: publicToken)
        )
        return response.accounts.map { $0.toModel() }
    }

    /// Constructs the Plaid Link web URL with the given token.
    func linkURL(for linkToken: String) -> URL {
        guard var components = URLComponents(string: Self.plaidLinkBaseURL) else {
            preconditionFailure("Invalid Plaid Link base URL: \(Self.plaidLinkBaseURL)")
        }
        components.queryItems = [
            URLQueryItem(name: "isWebview", value: "true"),
            URLQueryItem(name: "token", value: linkToken),
        ]
        guard let url = components.url else {
            preconditionFailure("Failed to construct Plaid Link URL from components")
        }
        return url
    }
}

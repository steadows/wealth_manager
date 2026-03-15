import Foundation
import os

private let logger = Logger(subsystem: "com.wealthmanager", category: "PlaidLinkService")

// MARK: - PlaidLinkServiceProtocol

/// Protocol for Plaid Link operations, enabling mock injection in tests.
protocol PlaidLinkServiceProtocol: Sendable {
    /// Requests a link token from the backend for initializing Plaid Link.
    func createLinkToken() async throws -> String

    /// Exchanges a Plaid public token for permanent access and returns linked accounts.
    func exchangeToken(publicToken: String) async throws -> [Account]

    /// Requests a hosted link token and URL from the backend for macOS Hosted Link flow.
    func createHostedLinkToken() async throws -> (linkToken: String, hostedLinkURL: URL)

    /// Resolves a completed Hosted Link session by asking the backend
    /// to retrieve accounts via the stored link token.
    func resolveSession(linkToken: String) async throws -> [Account]
}

// MARK: - PlaidLinkService

/// Production implementation that communicates with the backend's Plaid endpoints.
final class PlaidLinkService: PlaidLinkServiceProtocol, @unchecked Sendable {

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
        logger.info("PlaidLinkService initialized")
    }

    /// Calls `POST /api/v1/plaid/link-token` to obtain a Plaid Link token.
    func createLinkToken() async throws -> String {
        logger.info("Requesting link token from backend...")
        let response: PlaidLinkResponseDTO = try await apiClient.request(.createLinkToken)
        logger.info("Received link token: \(response.linkToken.prefix(30), privacy: .private)...")
        return response.linkToken
    }

    /// Calls `POST /api/v1/plaid/exchange-token` with the public token
    /// and converts the returned DTOs to local Account models.
    func exchangeToken(publicToken: String) async throws -> [Account] {
        logger.info("Exchanging public token: \(publicToken.prefix(20), privacy: .private)...")
        let response: PlaidExchangeResponseDTO = try await apiClient.request(
            .exchangeToken(publicToken: publicToken)
        )
        logger.info("Exchange returned \(response.accounts.count) accounts")
        return response.accounts.map { $0.toModel() }
    }

    /// Calls `POST /api/v1/plaid/hosted-link-token` to obtain a hosted link token and URL.
    func createHostedLinkToken() async throws -> (linkToken: String, hostedLinkURL: URL) {
        logger.info("Requesting hosted link token from backend...")
        let response: PlaidHostedLinkResponseDTO = try await apiClient.request(.createHostedLinkToken)
        guard let url = URL(string: response.hostedLinkUrl) else {
            logger.error("Backend returned invalid hosted link URL: \(response.hostedLinkUrl, privacy: .private)")
            throw APIError.invalidURL
        }
        logger.info("Received hosted link token: \(response.linkToken.prefix(30), privacy: .private)...")
        return (linkToken: response.linkToken, hostedLinkURL: url)
    }

    /// Calls `POST /api/v1/plaid/resolve-session` with the link token to resolve
    /// a completed Hosted Link session and retrieve linked accounts.
    func resolveSession(linkToken: String) async throws -> [Account] {
        logger.info("Resolving hosted link session: \(linkToken.prefix(20), privacy: .private)...")
        let response: PlaidResolveSessionResponseDTO = try await apiClient.request(
            .resolveSession(linkToken: linkToken)
        )
        guard response.status == "complete" else {
            logger.warning("Session not complete, status: \(response.status)")
            throw PlaidSessionError.sessionNotComplete(status: response.status)
        }
        let accounts = (response.accounts ?? []).map { $0.toModel() }
        logger.info("Session resolved: \(accounts.count) accounts linked")
        return accounts
    }

}

// MARK: - PlaidSessionError

/// Errors specific to Hosted Link session resolution.
enum PlaidSessionError: Error, LocalizedError {
    /// The session has not completed yet (status is "pending", "exited", etc.).
    case sessionNotComplete(status: String)

    var errorDescription: String? {
        switch self {
        case .sessionNotComplete(let status):
            return "Plaid session is not complete (status: \(status))."
        }
    }
}

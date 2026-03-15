import Testing
import Foundation

@testable import wealth_manager

// MARK: - PlaidLinkServiceTests

@Suite("PlaidLinkService")
struct PlaidLinkServiceTests {

    // MARK: - Helpers

    private func makeService(apiClient: MockAPIClient = MockAPIClient()) -> PlaidLinkService {
        PlaidLinkService(apiClient: apiClient)
    }

    private func makeSampleAccountDTO(
        id: UUID = UUID(),
        institutionName: String = "Chase",
        accountName: String = "Checking"
    ) -> AccountResponseDTO {
        AccountResponseDTO(
            id: id,
            plaidAccountId: "plaid-acc-123",
            institutionName: institutionName,
            accountName: accountName,
            accountType: "checking",
            currentBalance: Decimal(5000),
            availableBalance: Decimal(4800),
            currency: "USD",
            isManual: false,
            isHidden: false,
            lastSyncedAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Create Link Token

    @Test("createLinkToken: returns link token from backend")
    func createLinkTokenSuccess() async throws {
        let mockClient = MockAPIClient()
        mockClient.responses["/api/v1/plaid/link-token"] = PlaidLinkResponseDTO(
            linkToken: "link-sandbox-abc123"
        )
        let service = makeService(apiClient: mockClient)

        let token = try await service.createLinkToken()

        #expect(token == "link-sandbox-abc123")
        #expect(mockClient.requestLog.count == 1)
        #expect(mockClient.requestLog[0].path == "/api/v1/plaid/link-token")
        #expect(mockClient.requestLog[0].method == .post)
    }

    @Test("createLinkToken: throws on network error")
    func createLinkTokenNetworkError() async {
        let mockClient = MockAPIClient()
        mockClient.shouldThrow = APIError.networkError(
            NSError(domain: "test", code: -1)
        )
        let service = makeService(apiClient: mockClient)

        await #expect(throws: APIError.self) {
            _ = try await service.createLinkToken()
        }
    }

    @Test("createLinkToken: throws on server error")
    func createLinkTokenServerError() async {
        let mockClient = MockAPIClient()
        mockClient.shouldThrow = APIError.serverError(statusCode: 500, message: "Internal error")
        let service = makeService(apiClient: mockClient)

        await #expect(throws: APIError.self) {
            _ = try await service.createLinkToken()
        }
    }

    // MARK: - Exchange Token

    @Test("exchangeToken: returns accounts from backend")
    func exchangeTokenSuccess() async throws {
        let mockClient = MockAPIClient()
        let accountId = UUID()
        let dto = makeSampleAccountDTO(id: accountId)
        mockClient.responses["/api/v1/plaid/exchange-token"] = PlaidExchangeResponseDTO(
            accounts: [dto]
        )
        let service = makeService(apiClient: mockClient)

        let accounts = try await service.exchangeToken(publicToken: "public-sandbox-xyz")

        #expect(accounts.count == 1)
        #expect(accounts[0].id == accountId)
        #expect(accounts[0].institutionName == "Chase")
        #expect(accounts[0].isManual == false)
        #expect(accounts[0].plaidAccountId == "plaid-acc-123")
        #expect(mockClient.requestLog.count == 1)
        #expect(mockClient.requestLog[0].path == "/api/v1/plaid/exchange-token")
        #expect(mockClient.requestLog[0].method == .post)
    }

    @Test("exchangeToken: returns multiple accounts")
    func exchangeTokenMultipleAccounts() async throws {
        let mockClient = MockAPIClient()
        let dto1 = makeSampleAccountDTO(institutionName: "Chase", accountName: "Checking")
        let dto2 = makeSampleAccountDTO(institutionName: "Chase", accountName: "Savings")
        mockClient.responses["/api/v1/plaid/exchange-token"] = PlaidExchangeResponseDTO(
            accounts: [dto1, dto2]
        )
        let service = makeService(apiClient: mockClient)

        let accounts = try await service.exchangeToken(publicToken: "public-token")

        #expect(accounts.count == 2)
        #expect(accounts[0].accountName == "Checking")
        #expect(accounts[1].accountName == "Savings")
    }

    @Test("exchangeToken: throws on network error")
    func exchangeTokenNetworkError() async {
        let mockClient = MockAPIClient()
        mockClient.shouldThrow = APIError.networkError(
            NSError(domain: "test", code: -1)
        )
        let service = makeService(apiClient: mockClient)

        await #expect(throws: APIError.self) {
            _ = try await service.exchangeToken(publicToken: "token")
        }
    }

    @Test("exchangeToken: throws on unauthorized")
    func exchangeTokenUnauthorized() async {
        let mockClient = MockAPIClient()
        mockClient.shouldThrow = APIError.unauthorized
        let service = makeService(apiClient: mockClient)

        await #expect(throws: APIError.self) {
            _ = try await service.exchangeToken(publicToken: "token")
        }
    }

    // MARK: - Create Hosted Link Token

    @Test("createHostedLinkToken: returns link token and URL from backend")
    func createHostedLinkTokenSuccess() async throws {
        let mockClient = MockAPIClient()
        mockClient.responses["/api/v1/plaid/hosted-link-token"] = PlaidHostedLinkResponseDTO(
            linkToken: "link-hosted-abc123",
            hostedLinkUrl: "https://hosted.plaid.com/link/session-xyz"
        )
        let service = makeService(apiClient: mockClient)

        let (token, url) = try await service.createHostedLinkToken()

        #expect(token == "link-hosted-abc123")
        #expect(url == URL(string: "https://hosted.plaid.com/link/session-xyz")!)
        #expect(mockClient.requestLog.count == 1)
        #expect(mockClient.requestLog[0].path == "/api/v1/plaid/hosted-link-token")
        #expect(mockClient.requestLog[0].method == .post)
    }

    @Test("createHostedLinkToken: throws invalidURL when backend returns bad URL")
    func createHostedLinkTokenInvalidURL() async {
        let mockClient = MockAPIClient()
        mockClient.responses["/api/v1/plaid/hosted-link-token"] = PlaidHostedLinkResponseDTO(
            linkToken: "link-hosted-abc",
            hostedLinkUrl: ""
        )
        let service = makeService(apiClient: mockClient)

        await #expect(throws: APIError.self) {
            _ = try await service.createHostedLinkToken()
        }
    }

    @Test("createHostedLinkToken: throws on network error")
    func createHostedLinkTokenNetworkError() async {
        let mockClient = MockAPIClient()
        mockClient.shouldThrow = APIError.networkError(NSError(domain: "test", code: -1))
        let service = makeService(apiClient: mockClient)

        await #expect(throws: APIError.self) {
            _ = try await service.createHostedLinkToken()
        }
    }

    // MARK: - Resolve Session

    @Test("resolveSession: returns accounts when status is complete")
    func resolveSessionSuccess() async throws {
        let mockClient = MockAPIClient()
        let accountId = UUID()
        let dto = makeSampleAccountDTO(id: accountId, institutionName: "Wells Fargo", accountName: "Savings")
        mockClient.responses["/api/v1/plaid/resolve-session"] = PlaidResolveSessionResponseDTO(
            status: "complete",
            accounts: [dto]
        )
        let service = makeService(apiClient: mockClient)

        let accounts = try await service.resolveSession(linkToken: "link-hosted-token")

        #expect(accounts.count == 1)
        #expect(accounts[0].id == accountId)
        #expect(accounts[0].institutionName == "Wells Fargo")
        #expect(accounts[0].accountName == "Savings")
        #expect(mockClient.requestLog.count == 1)
        #expect(mockClient.requestLog[0].path == "/api/v1/plaid/resolve-session")
        #expect(mockClient.requestLog[0].method == .post)
    }

    @Test("resolveSession: returns empty array when complete with nil accounts")
    func resolveSessionCompleteNoAccounts() async throws {
        let mockClient = MockAPIClient()
        mockClient.responses["/api/v1/plaid/resolve-session"] = PlaidResolveSessionResponseDTO(
            status: "complete",
            accounts: nil
        )
        let service = makeService(apiClient: mockClient)

        let accounts = try await service.resolveSession(linkToken: "link-hosted-token")

        #expect(accounts.isEmpty)
    }

    @Test("resolveSession: throws sessionNotComplete when status is pending")
    func resolveSessionPending() async {
        let mockClient = MockAPIClient()
        mockClient.responses["/api/v1/plaid/resolve-session"] = PlaidResolveSessionResponseDTO(
            status: "pending",
            accounts: nil
        )
        let service = makeService(apiClient: mockClient)

        await #expect(throws: PlaidSessionError.self) {
            _ = try await service.resolveSession(linkToken: "link-hosted-token")
        }
    }

    @Test("resolveSession: throws sessionNotComplete when status is exited")
    func resolveSessionExited() async {
        let mockClient = MockAPIClient()
        mockClient.responses["/api/v1/plaid/resolve-session"] = PlaidResolveSessionResponseDTO(
            status: "exited",
            accounts: nil
        )
        let service = makeService(apiClient: mockClient)

        await #expect(throws: PlaidSessionError.self) {
            _ = try await service.resolveSession(linkToken: "link-hosted-token")
        }
    }

    @Test("resolveSession: throws on network error")
    func resolveSessionNetworkError() async {
        let mockClient = MockAPIClient()
        mockClient.shouldThrow = APIError.networkError(NSError(domain: "test", code: -1))
        let service = makeService(apiClient: mockClient)

        await #expect(throws: APIError.self) {
            _ = try await service.resolveSession(linkToken: "link-hosted-token")
        }
    }

    // MARK: - Protocol Conformance

    @Test("conforms to PlaidLinkServiceProtocol")
    func protocolConformance() {
        let service = makeService()
        let _: any PlaidLinkServiceProtocol = service
    }
}

import Testing
import Foundation

@testable import wealth_manager

// MARK: - EndpointTests

@Suite("Endpoint")
struct EndpointTests {

    // MARK: - Path

    @Test("auth login: correct path")
    func authLoginPath() {
        let endpoint = Endpoint.login(identityToken: "test-token")
        #expect(endpoint.path == "/api/v1/auth/login")
    }

    @Test("auth refresh: correct path")
    func authRefreshPath() {
        let endpoint = Endpoint.refreshToken
        #expect(endpoint.path == "/api/v1/auth/refresh")
    }

    @Test("auth me: correct path")
    func authMePath() {
        let endpoint = Endpoint.me
        #expect(endpoint.path == "/api/v1/auth/me")
    }

    @Test("accounts list: correct path")
    func accountsListPath() {
        let endpoint = Endpoint.listAccounts()
        #expect(endpoint.path == "/api/v1/accounts")
    }

    @Test("account detail: correct path")
    func accountDetailPath() {
        let id = UUID()
        let endpoint = Endpoint.getAccount(id: id)
        #expect(endpoint.path == "/api/v1/accounts/\(id.uuidString)")
    }

    @Test("sync pull: correct path")
    func syncPullPath() {
        let endpoint = Endpoint.syncPull(since: nil)
        #expect(endpoint.path == "/api/v1/sync")
    }

    @Test("sync push: correct path")
    func syncPushPath() {
        let endpoint = Endpoint.syncPush(ClientChangesDTO(accounts: [], goals: [], debts: []))
        #expect(endpoint.path == "/api/v1/sync")
    }

    @Test("plaid link token: correct path")
    func plaidLinkTokenPath() {
        let endpoint = Endpoint.createLinkToken
        #expect(endpoint.path == "/api/v1/plaid/link-token")
    }

    @Test("plaid exchange token: correct path")
    func plaidExchangeTokenPath() {
        let endpoint = Endpoint.exchangeToken(publicToken: "public-sandbox-xxx")
        #expect(endpoint.path == "/api/v1/plaid/exchange-token")
    }

    // MARK: - HTTP Method

    @Test("login: POST method")
    func loginIsPost() {
        let endpoint = Endpoint.login(identityToken: "t")
        #expect(endpoint.method == .post)
    }

    @Test("refresh: POST method")
    func refreshIsPost() {
        let endpoint = Endpoint.refreshToken
        #expect(endpoint.method == .post)
    }

    @Test("me: GET method")
    func meIsGet() {
        let endpoint = Endpoint.me
        #expect(endpoint.method == .get)
    }

    @Test("list accounts: GET method")
    func listAccountsIsGet() {
        let endpoint = Endpoint.listAccounts()
        #expect(endpoint.method == .get)
    }

    @Test("sync pull: GET method")
    func syncPullIsGet() {
        let endpoint = Endpoint.syncPull(since: nil)
        #expect(endpoint.method == .get)
    }

    @Test("sync push: POST method")
    func syncPushIsPost() {
        let endpoint = Endpoint.syncPush(ClientChangesDTO(accounts: [], goals: [], debts: []))
        #expect(endpoint.method == .post)
    }

    // MARK: - Query Parameters

    @Test("sync pull with since: includes query parameter")
    func syncPullWithSince() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let endpoint = Endpoint.syncPull(since: date)
        let queryItems = endpoint.queryItems
        #expect(queryItems?.count == 1)
        #expect(queryItems?.first?.name == "since")
        #expect(queryItems?.first?.value != nil)
    }

    @Test("sync pull without since: no query parameters")
    func syncPullWithoutSince() {
        let endpoint = Endpoint.syncPull(since: nil)
        let queryItems = endpoint.queryItems
        #expect(queryItems == nil || queryItems?.isEmpty == true)
    }

    @Test("list accounts with pagination: includes offset and limit")
    func listAccountsWithPagination() {
        let endpoint = Endpoint.listAccounts(offset: 10, limit: 50)
        let queryItems = endpoint.queryItems
        #expect(queryItems?.contains { $0.name == "offset" && $0.value == "10" } == true)
        #expect(queryItems?.contains { $0.name == "limit" && $0.value == "50" } == true)
    }

    // MARK: - Request Body

    @Test("login: body contains identity_token")
    func loginBody() throws {
        let endpoint = Endpoint.login(identityToken: "apple-id-token-123")
        let body = try #require(endpoint.body)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(json?["identity_token"] as? String == "apple-id-token-123")
    }

    @Test("exchange token: body contains public_token")
    func exchangeTokenBody() throws {
        let endpoint = Endpoint.exchangeToken(publicToken: "public-sandbox-abc")
        let body = try #require(endpoint.body)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(json?["public_token"] as? String == "public-sandbox-abc")
    }

    @Test("GET endpoints: no body")
    func getEndpointsHaveNoBody() {
        #expect(Endpoint.me.body == nil)
        #expect(Endpoint.listAccounts().body == nil)
        #expect(Endpoint.syncPull(since: nil).body == nil)
    }

    // MARK: - URL Construction

    @Test("makeURLRequest: constructs valid URL")
    func makeURLRequest() throws {
        let baseURL = URL(string: "https://api.example.com")!
        let endpoint = Endpoint.me
        let request = try endpoint.makeURLRequest(baseURL: baseURL)
        #expect(request.url?.absoluteString == "https://api.example.com/api/v1/auth/me")
        #expect(request.httpMethod == "GET")
    }

    @Test("makeURLRequest: POST includes Content-Type header")
    func postIncludesContentType() throws {
        let baseURL = URL(string: "https://api.example.com")!
        let endpoint = Endpoint.login(identityToken: "t")
        let request = try endpoint.makeURLRequest(baseURL: baseURL)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.httpBody != nil)
    }

    @Test("makeURLRequest: includes query items in URL")
    func queryItemsInURL() throws {
        let baseURL = URL(string: "https://api.example.com")!
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let endpoint = Endpoint.syncPull(since: date)
        let request = try endpoint.makeURLRequest(baseURL: baseURL)
        let urlString = try #require(request.url?.absoluteString)
        #expect(urlString.contains("since="))
    }

    // MARK: - Authentication Requirement

    @Test("login: does not require auth")
    func loginNoAuth() {
        let endpoint = Endpoint.login(identityToken: "t")
        #expect(!endpoint.requiresAuth)
    }

    @Test("me: requires auth")
    func meRequiresAuth() {
        let endpoint = Endpoint.me
        #expect(endpoint.requiresAuth)
    }

    @Test("sync pull: requires auth")
    func syncPullRequiresAuth() {
        let endpoint = Endpoint.syncPull(since: nil)
        #expect(endpoint.requiresAuth)
    }

    @Test("list accounts: requires auth")
    func listAccountsRequiresAuth() {
        let endpoint = Endpoint.listAccounts()
        #expect(endpoint.requiresAuth)
    }
}

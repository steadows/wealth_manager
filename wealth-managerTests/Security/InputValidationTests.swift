import Testing
import Foundation

@testable import wealth_manager

// MARK: - Input Validation Security Tests
//
// These tests verify that user-supplied or externally-sourced input cannot
// cause path traversal, URL injection, crash-on-decode, or resource exhaustion
// when processed by the networking layer.

@Suite("Input Validation Security")
struct InputValidationTests {

    // MARK: - Path Traversal Prevention

    /// Verifies that a UUID-based path (getAccount, deleteAccount, plaidSync) cannot
    /// be manipulated to produce a path traversal segment. UUIDs are used as path
    /// components; their string representation is fixed and safe.
    @Test("endpoint_pathTraversal_prevented_byUUIDPaths")
    func endpoint_pathTraversal_prevented_byUUIDPaths() throws {
        let id = UUID()
        let baseURL = URL(string: "https://api.example.com")!

        for endpoint: Endpoint in [
            .getAccount(id: id),
            .deleteAccount(id: id),
            .plaidSync(accountId: id),
        ] {
            let request = try endpoint.makeURLRequest(baseURL: baseURL)
            let urlString = request.url?.absoluteString ?? ""
            #expect(!urlString.contains("../"),
                    "Path must not contain '../' — endpoint: \(endpoint), url: \(urlString)")
            #expect(!urlString.contains("..%2F"),
                    "Path must not contain percent-encoded traversal — endpoint: \(endpoint)")
            #expect(urlString.contains(id.uuidString),
                    "Path must contain the UUID as-is — endpoint: \(endpoint)")
        }
    }

    /// Verifies that the path returned for every endpoint is rooted under /api/v1
    /// and does not escape the expected path prefix.
    @Test("endpoint_paths_allRootedUnderAPIV1")
    func endpoint_paths_allRootedUnderAPIV1() {
        let allEndpoints: [Endpoint] = [
            .login(identityToken: "tok"),
            .refreshToken,
            .me,
            .listAccounts(),
            .getAccount(id: UUID()),
            .createAccount(AccountCreateDTO(
                institutionName: "B", accountName: "C", accountType: "checking",
                currentBalance: 0, availableBalance: nil, currency: "USD", isManual: true
            )),
            .updateAccount(id: UUID(), data: Data()),
            .deleteAccount(id: UUID()),
            .createLinkToken,
            .exchangeToken(publicToken: "tok"),
            .plaidSync(accountId: UUID()),
            .syncPull(since: nil),
            .syncPush(ClientChangesDTO(accounts: [], goals: [], debts: [])),
            .advisorChat(message: "msg", conversationId: nil),
            .getBriefing(period: "weekly"),
            .getHealthScore,
            .getAlerts,
        ]

        for endpoint in allEndpoints {
            #expect(
                endpoint.path.hasPrefix("/api/v1/"),
                "All endpoint paths must start with /api/v1/ — got '\(endpoint.path)' for \(endpoint)"
            )
        }
    }

    // MARK: - Query Parameter Encoding

    /// Verifies that a period parameter containing special characters (ampersand,
    /// equals, angle brackets) is properly URL-encoded and does not break out of
    /// the query string to inject additional parameters.
    @Test("endpoint_specialCharsInPeriod_areURLEncoded")
    func endpoint_specialCharsInPeriod_areURLEncoded() throws {
        let maliciousPeriod = "weekly&injected=true"
        let baseURL = URL(string: "https://api.example.com")!
        let request = try Endpoint.getBriefing(period: maliciousPeriod).makeURLRequest(baseURL: baseURL)

        let urlString = request.url?.absoluteString ?? ""
        // If properly encoded, the raw `&injected=true` should not appear as a distinct key-value pair
        let queryItems = URLComponents(string: urlString)?.queryItems ?? []
        let periodItem = queryItems.first { $0.name == "period" }
        #expect(periodItem != nil, "Query should contain a 'period' key")
        #expect(periodItem?.value == maliciousPeriod,
                "The full period string (including special chars) must survive as a single value")
        // There must be exactly one query item — no injection of additional params
        #expect(queryItems.count == 1,
                "Injected '&' in period value must not produce extra query items, got: \(queryItems)")
    }

    /// Verifies that offset/limit query parameters in listAccounts are integer strings,
    /// not injectable arbitrary values.
    @Test("endpoint_listAccounts_queryParams_areIntegers")
    func endpoint_listAccounts_queryParams_areIntegers() throws {
        let baseURL = URL(string: "https://api.example.com")!
        let request = try Endpoint.listAccounts(offset: 0, limit: 100).makeURLRequest(baseURL: baseURL)
        let queryItems = URLComponents(string: request.url?.absoluteString ?? "")?.queryItems ?? []

        let offsetItem = queryItems.first { $0.name == "offset" }
        let limitItem = queryItems.first { $0.name == "limit" }

        #expect(offsetItem?.value == "0", "offset must be '0'")
        #expect(limitItem?.value == "100", "limit must be '100'")
        // Verify values are parseable integers (not injected strings)
        #expect(Int(offsetItem?.value ?? "") != nil, "offset query value must be an integer")
        #expect(Int(limitItem?.value ?? "") != nil, "limit query value must be an integer")
    }

    // MARK: - JSON Decoding Safety

    /// Verifies that providing invalid JSON as a raw Data body to updateAccount does
    /// not crash — the endpoint accepts raw Data and passes it through, so encoding
    /// can never fail at the client layer.
    @Test("endpoint_updateAccount_acceptsArbitraryData_noEncodingCrash")
    func endpoint_updateAccount_acceptsArbitraryData_noEncodingCrash() throws {
        let garbageData = Data([0xFF, 0xFE, 0x00, 0x01])
        let endpoint = Endpoint.updateAccount(id: UUID(), data: garbageData)
        // makeURLRequest must not throw or crash for arbitrary body data
        let baseURL = URL(string: "https://api.example.com")!
        let request = try endpoint.makeURLRequest(baseURL: baseURL)
        #expect(request.httpBody == garbageData,
                "updateAccount must pass through raw Data without modification")
    }

    /// Verifies that decoding invalid JSON (not wrapped in an envelope) produces an
    /// APIError.decodingError rather than crashing or returning a partial result.
    @Test("decodingError_invalidJSON_throwsCleanError")
    func decodingError_invalidJSON_throwsCleanError() async {
        let client = makeClient()

        SecurityMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data("not valid json at all {{{".utf8))
        }

        await #expect(throws: APIError.self) {
            let _: LoginResponseDTO = try await client.request(.login(identityToken: "t"))
        }
    }

    /// Verifies that a 204 No Content response with an empty body is handled
    /// gracefully for EmptyResponse-typed requests rather than crashing.
    @Test("emptyResponse_204_handledGracefully")
    func emptyResponse_204_handledGracefully() async throws {
        let client = makeClient()

        SecurityMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        // EmptyResponse is the type used for 204 No-Content endpoints.
        // This must not crash or throw for an empty body.
        let _: EmptyResponse = try await client.request(.deleteAccount(id: UUID()))
    }

    /// Verifies that a very large (but reasonable) JSON response body does not cause
    /// a crash or silent truncation — the client must either decode fully or throw.
    @Test("oversizePayload_decodedOrThrowsCleanly")
    func oversizePayload_decodedOrThrowsCleanly() async {
        let client = makeClient()

        SecurityMockURLProtocol.requestHandler = { request in
            // Build a 512KB response — large but not gigabyte-scale
            let item: [String: Any] = [
                "id": UUID().uuidString,
                "account_id": UUID().uuidString,
                "amount": 99.99,
                "description": String(repeating: "X", count: 500),
                "category": "test",
                "date": "2025-01-01T00:00:00Z",
                "created_at": "2025-01-01T00:00:00Z"
            ]
            let manyItems = Array(repeating: item, count: 200)
            let envelope: [String: Any] = ["success": true, "data": manyItems, "error": NSNull()]
            let data = try! JSONSerialization.data(withJSONObject: envelope)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }

        // Should either succeed or throw — never crash
        do {
            let results: [TransactionResponseDTO] = try await client.request(.syncPull(since: nil))
            #expect(results.count == 200, "All 200 items should decode successfully")
        } catch {
            // Any thrown error is acceptable — the client handled the large payload cleanly
            // without crashing or OOM-ing. Just verify the error is an APIError.
            #expect(error is APIError, "Large payload error must be a typed APIError, got: \(error)")
        }
        // Reaching here without crashing is the primary assertion
    }

    // MARK: - Date Parsing Safety

    /// Verifies that a malformed ISO8601 date string in a JSON response causes a
    /// clean DecodingError (wrapped as APIError.decodingError) rather than a crash
    /// or a silently-wrong Date value.
    @Test("malformedDate_doesNotCrash")
    func malformedDate_doesNotCrash() async {
        let client = makeClient()

        SecurityMockURLProtocol.requestHandler = { request in
            // The created_at field has a malformed date — not a valid ISO8601 string
            let badJSON: [String: Any] = [
                "success": true,
                "data": [
                    "id": UUID().uuidString,
                    "email": "user@example.com",
                    "created_at": "NOT-A-DATE-AT-ALL"  // invalid
                ],
                "error": NSNull()
            ]
            let data = try! JSONSerialization.data(withJSONObject: badJSON)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }

        // Must throw a decodingError, not crash
        await #expect(throws: APIError.self) {
            let _: UserResponseDTO = try await client.request(.me)
        }
    }

    /// Verifies that a missing required date field (nil/absent in JSON) causes a
    /// clean decoding error rather than silently defaulting.
    @Test("missingDateField_throwsDecodingError")
    func missingDateField_throwsDecodingError() async {
        let client = makeClient()

        SecurityMockURLProtocol.requestHandler = { request in
            // created_at is required in UserResponseDTO — omit it entirely
            let badJSON: [String: Any] = [
                "success": true,
                "data": [
                    "id": UUID().uuidString,
                    "email": "user@example.com"
                    // "created_at" intentionally absent
                ],
                "error": NSNull()
            ]
            let data = try! JSONSerialization.data(withJSONObject: badJSON)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }

        await #expect(throws: APIError.self) {
            let _: UserResponseDTO = try await client.request(.me)
        }
    }

    // MARK: - HTTPS Enforcement

    /// Verifies that all Endpoint paths are relative (no scheme override) so the
    /// base URL supplied by the app configuration — which must be HTTPS — is always
    /// authoritative. No endpoint should embed an absolute http:// URL.
    @Test("endpoint_paths_areRelative_noHTTPSchemeOverride")
    func endpoint_paths_areRelative_noHTTPSchemeOverride() throws {
        let allEndpoints: [Endpoint] = [
            .login(identityToken: "tok"),
            .refreshToken,
            .me,
            .listAccounts(),
            .getAccount(id: UUID()),
            .createAccount(AccountCreateDTO(
                institutionName: "B", accountName: "C", accountType: "checking",
                currentBalance: 0, availableBalance: nil, currency: "USD", isManual: true
            )),
            .updateAccount(id: UUID(), data: Data()),
            .deleteAccount(id: UUID()),
            .createLinkToken,
            .exchangeToken(publicToken: "tok"),
            .plaidSync(accountId: UUID()),
            .syncPull(since: nil),
            .syncPush(ClientChangesDTO(accounts: [], goals: [], debts: [])),
            .advisorChat(message: "msg", conversationId: nil),
            .getBriefing(period: "weekly"),
            .getHealthScore,
            .getAlerts,
        ]

        // With an HTTPS base URL, all constructed requests must also use HTTPS
        let httpsBase = URL(string: "https://api.example.com")!
        for endpoint in allEndpoints {
            let request = try endpoint.makeURLRequest(baseURL: httpsBase)
            let scheme = request.url?.scheme
            #expect(scheme == "https",
                    "Request constructed with HTTPS base must use HTTPS scheme — got '\(scheme ?? "nil")' for \(endpoint)")
        }
    }
}

// MARK: - MockURLProtocol (local copy to avoid cross-file dependency)
// Declared in APIClientTests.swift in the Network group; redeclared here as a
// separate type so the Security suite has no implicit coupling to Network tests.

private final class SecurityMockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Helpers

private func makeClient() -> APIClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [SecurityMockURLProtocol.self]
    let session = URLSession(configuration: config)
    return APIClient(
        baseURL: URL(string: "https://api.test.com")!,
        session: session,
        tokenProvider: MockTokenProvider()
    )
}

import Testing
import Foundation

@testable import wealth_manager

// MARK: - APIClientTests

@Suite("APIClient", .serialized)
struct APIClientTests {

    // MARK: - Helpers

    /// A mock URLProtocol that returns predefined responses.
    final class MockURLProtocol: URLProtocol, @unchecked Sendable {
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

    private func makeClient(
        tokenProvider: TokenProvider? = nil
    ) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        return APIClient(
            baseURL: URL(string: "https://api.test.com")!,
            session: session,
            tokenProvider: tokenProvider ?? MockTokenProvider()
        )
    }

    private func makeSuccessResponse(
        url: URL,
        json: [String: Any],
        statusCode: Int = 200
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let wrapped: [String: Any] = ["success": true, "data": json, "error": NSNull()]
        let data = try! JSONSerialization.data(withJSONObject: wrapped)
        return (response, data)
    }

    private func makeErrorResponse(
        url: URL,
        message: String,
        statusCode: Int
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let wrapped: [String: Any] = ["success": false, "data": NSNull(), "error": message]
        let data = try! JSONSerialization.data(withJSONObject: wrapped)
        return (response, data)
    }

    // MARK: - Successful Requests

    @Test("request: decodes successful response")
    func requestDecodesSuccess() async throws {
        let client = makeClient()

        MockURLProtocol.requestHandler = { request in
            self.makeSuccessResponse(
                url: request.url!,
                json: ["access_token": "jwt-123", "token_type": "bearer"]
            )
        }

        let response: LoginResponseDTO = try await client.request(
            .login(identityToken: "apple-token")
        )
        #expect(response.accessToken == "jwt-123")
        #expect(response.tokenType == "bearer")
    }

    @Test("request: GET includes auth header when token available")
    func requestIncludesAuthHeader() async throws {
        let tokenProvider = MockTokenProvider(accessToken: "my-jwt")
        let client = makeClient(tokenProvider: tokenProvider)

        MockURLProtocol.requestHandler = { request in
            let authHeader = request.value(forHTTPHeaderField: "Authorization")
            #expect(authHeader == "Bearer my-jwt")
            return self.makeSuccessResponse(
                url: request.url!,
                json: ["id": UUID().uuidString, "email": "test@test.com", "created_at": "2025-01-01T00:00:00Z"]
            )
        }

        let _: UserResponseDTO = try await client.request(.me)
    }

    @Test("request: unauthenticated endpoint skips auth header")
    func unauthEndpointNoAuthHeader() async throws {
        let client = makeClient()

        MockURLProtocol.requestHandler = { request in
            let authHeader = request.value(forHTTPHeaderField: "Authorization")
            #expect(authHeader == nil)
            return self.makeSuccessResponse(
                url: request.url!,
                json: ["access_token": "jwt", "token_type": "bearer"]
            )
        }

        let _: LoginResponseDTO = try await client.request(
            .login(identityToken: "token")
        )
    }

    // MARK: - Error Handling

    @Test("request: throws networkError on non-200 status")
    func requestThrowsOnServerError() async {
        let client = makeClient()

        MockURLProtocol.requestHandler = { request in
            self.makeErrorResponse(url: request.url!, message: "Internal error", statusCode: 500)
        }

        await #expect(throws: APIError.self) {
            let _: LoginResponseDTO = try await client.request(
                .login(identityToken: "t")
            )
        }
    }

    @Test("request: throws unauthorized on 401")
    func requestThrowsUnauthorized() async {
        let tokenProvider = MockTokenProvider(accessToken: "expired-jwt")
        // Disable auto-refresh for this test
        tokenProvider.refreshShouldFail = true
        let client = makeClient(tokenProvider: tokenProvider)

        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://api.test.com/api/v1/auth/me")!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            let body: [String: Any] = ["success": false, "data": NSNull(), "error": "Token expired"]
            let data = try! JSONSerialization.data(withJSONObject: body)
            return (response, data)
        }

        await #expect(throws: APIError.self) {
            let _: UserResponseDTO = try await client.request(.me)
        }
    }

    @Test("request: throws decodingError on malformed JSON")
    func requestThrowsDecodingError() async {
        let client = makeClient()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("not json".utf8))
        }

        await #expect(throws: APIError.self) {
            let _: LoginResponseDTO = try await client.request(
                .login(identityToken: "t")
            )
        }
    }

    @Test("request: throws apiError when success is false")
    func requestThrowsAPIErrorOnFailure() async {
        let client = makeClient()

        MockURLProtocol.requestHandler = { request in
            self.makeErrorResponse(url: request.url!, message: "Bad request", statusCode: 400)
        }

        await #expect(throws: APIError.self) {
            let _: LoginResponseDTO = try await client.request(
                .login(identityToken: "t")
            )
        }
    }

    // MARK: - Token Refresh on 401

    @Test("request: retries with refreshed token on 401")
    func requestRetriesAfterTokenRefresh() async throws {
        let tokenProvider = MockTokenProvider(accessToken: "expired-jwt")
        tokenProvider.refreshedToken = "fresh-jwt"
        let client = makeClient(tokenProvider: tokenProvider)

        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            if requestCount == 1 {
                // First request: 401
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )!
                let body: [String: Any] = ["success": false, "data": NSNull(), "error": "Expired"]
                let data = try! JSONSerialization.data(withJSONObject: body)
                return (response, data)
            } else {
                // Second request after refresh: should have new token
                let authHeader = request.value(forHTTPHeaderField: "Authorization")
                #expect(authHeader == "Bearer fresh-jwt")
                return self.makeSuccessResponse(
                    url: request.url!,
                    json: ["id": UUID().uuidString, "email": "test@test.com", "created_at": "2025-01-01T00:00:00Z"]
                )
            }
        }

        let _: UserResponseDTO = try await client.request(.me)
        #expect(requestCount == 2)
        #expect(tokenProvider.refreshCallCount == 1)
    }

    // MARK: - Response Envelope Unwrapping

    @Test("request: unwraps data from APIResponse envelope")
    func requestUnwrapsEnvelope() async throws {
        let client = makeClient()

        MockURLProtocol.requestHandler = { request in
            let accountJSON: [String: Any] = [
                "id": UUID().uuidString,
                "institution_name": "Chase",
                "account_name": "Checking",
                "account_type": "checking",
                "current_balance": 15000.00,
                "currency": "USD",
                "is_manual": true,
                "is_hidden": false,
                "created_at": "2025-01-01T00:00:00Z",
                "updated_at": "2025-01-01T00:00:00Z"
            ]
            let wrapped: [String: Any] = ["success": true, "data": [accountJSON], "error": NSNull()]
            let data = try! JSONSerialization.data(withJSONObject: wrapped)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }

        let accounts: [AccountResponseDTO] = try await client.request(.listAccounts())
        #expect(accounts.count == 1)
        #expect(accounts.first?.institutionName == "Chase")
    }
}

// MARK: - Mock Token Provider

final class MockTokenProvider: TokenProvider, @unchecked Sendable {
    var accessToken: String?
    var refreshedToken: String?
    var refreshShouldFail = false
    var refreshCallCount = 0

    init(accessToken: String? = nil) {
        self.accessToken = accessToken
    }

    func currentAccessToken() async -> String? {
        accessToken
    }

    func refreshAccessToken() async throws -> String {
        refreshCallCount += 1
        if refreshShouldFail {
            throw APIError.unauthorized
        }
        let token = refreshedToken ?? "refreshed-token"
        accessToken = token
        return token
    }
}

import Foundation

// MARK: - APIClientProtocol

/// Protocol for making API requests, enabling mock injection in tests.
protocol APIClientProtocol: Sendable {
    /// Sends a request to the given endpoint and decodes the response.
    /// The response envelope is automatically unwrapped.
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}

// MARK: - APIClient

/// Production API client using URLSession.
/// Handles JWT injection, response envelope unwrapping, and 401 auto-refresh.
final class APIClient: APIClientProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: TokenProvider
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        session: URLSession = CertificatePinningDelegate.shared.pinnedSession(),
        tokenProvider: TokenProvider
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = ISO8601DateFormatter().date(from: string) {
                return date
            }
            // Try with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions.insert(.withFractionalSeconds)
            if let date = formatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(string)"
            )
        }
        self.decoder = decoder
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        var urlRequest = try endpoint.makeURLRequest(baseURL: baseURL)

        // Inject auth header for protected endpoints
        if endpoint.requiresAuth, let token = await tokenProvider.currentAccessToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await performRequest(urlRequest)

        // Handle 401: try refresh then retry once
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            return try await retryAfterRefresh(endpoint: endpoint)
        }

        return try decodeResponse(data: data, response: response)
    }

    // MARK: - Private

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }
    }

    private func retryAfterRefresh<T: Decodable>(endpoint: Endpoint) async throws -> T {
        let newToken: String
        do {
            newToken = try await tokenProvider.refreshAccessToken()
        } catch {
            throw APIError.unauthorized
        }

        var urlRequest = try endpoint.makeURLRequest(baseURL: baseURL)
        urlRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(urlRequest)
        return try decodeResponse(data: data, response: response)
    }

    private func decodeResponse<T: Decodable>(data: Data, response: URLResponse) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(
                NSError(domain: "APIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            )
        }

        // 204 No Content
        if httpResponse.statusCode == 204 {
            // For Void-like responses, try to decode empty
            if let empty = EmptyResponse() as? T {
                return empty
            }
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to extract error message from body
            let message: String
            if let envelope = try? decoder.decode(APIResponseEnvelope<EmptyResponse>.self, from: data) {
                message = envelope.error ?? "Unknown error"
            } else {
                message = String(data: data, encoding: .utf8) ?? "Unknown error"
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        // Try unwrapping from APIResponse envelope first
        do {
            let envelope = try decoder.decode(APIResponseEnvelope<T>.self, from: data)
            guard envelope.success else {
                throw APIError.apiError(message: envelope.error ?? "Request failed")
            }
            guard let payload = envelope.data else {
                throw APIError.noData
            }
            return payload
        } catch let apiError as APIError {
            throw apiError
        } catch {
            // If envelope decoding fails, try direct decode (some endpoints might not use envelope)
            do {
                return try decoder.decode(T.self, from: data)
            } catch let directError {
                throw APIError.decodingError(directError)
            }
        }
    }
}

// MARK: - EmptyResponse

/// Used for endpoints that return no data (e.g., DELETE 204).
struct EmptyResponse: Codable {}

import Foundation

// MARK: - AdvisorService

/// Production implementation of AdvisoryServiceProtocol.
/// Uses APIClient for JSON endpoints and URLSession for SSE streaming.
final class AdvisorService: AdvisoryServiceProtocol {
    private let apiClient: APIClientProtocol
    private let baseURL: URL
    private let tokenProvider: TokenProvider

    /// Cached pinned URLSession for SSE streaming, avoiding per-request allocation.
    private let pinnedSession: URLSession

    init(apiClient: APIClientProtocol, baseURL: URL, tokenProvider: TokenProvider) {
        self.apiClient = apiClient
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.pinnedSession = CertificatePinningDelegate.shared.pinnedSession(
            timeoutForRequest: 30,
            timeoutForResource: 90
        )
    }

    // MARK: - Streaming Chat

    /// Streams chat response chunks via Server-Sent Events.
    /// Handles 401 by refreshing the token and retrying once.
    func streamChat(message: String, conversationId: UUID?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.executeStream(
                        message: message,
                        conversationId: conversationId,
                        continuation: continuation,
                        isRetry: false
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // Cancel the inner Task when the stream consumer stops iterating.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Executes the SSE stream, retrying once on 401 after refreshing the token.
    private func executeStream(
        message: String,
        conversationId: UUID?,
        continuation: AsyncThrowingStream<String, Error>.Continuation,
        isRetry: Bool
    ) async throws {
        let urlRequest = try await makeChatRequest(
            message: message,
            conversationId: conversationId
        )
        let (bytes, response) = try await pinnedSession.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError(statusCode: 500, message: "Stream failed")
        }

        // Handle 401: refresh token and retry once
        if httpResponse.statusCode == 401, !isRetry {
            _ = try await tokenProvider.refreshAccessToken()
            try await executeStream(
                message: message,
                conversationId: conversationId,
                continuation: continuation,
                isRetry: true
            )
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(
                statusCode: httpResponse.statusCode,
                message: "Stream failed with status \(httpResponse.statusCode)"
            )
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }

            // Backend JSON-encodes chunks so newlines survive SSE transport.
            // Decode the JSON string to restore them; fall back to raw payload.
            if let data = payload.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(String.self, from: data) {
                continuation.yield(decoded)
            } else {
                continuation.yield(payload)
            }
        }
        continuation.finish()
    }

    // MARK: - JSON Endpoints

    func fetchBriefing(period: String) async throws -> CFOBriefingDTO {
        try await apiClient.request(.getBriefing(period: period))
    }

    func fetchHealthScore() async throws -> HealthScoreResponseDTO {
        try await apiClient.request(.getHealthScore)
    }

    func fetchAlerts() async throws -> [ProactiveAlertDTO] {
        try await apiClient.request(.getAlerts)
    }

    func fetchAnnualReview(year: Int) async throws -> AnnualReviewDTO {
        try await apiClient.request(.annualReview(year: year))
    }

    // MARK: - Private

    private func makeChatRequest(message: String, conversationId: UUID?) async throws -> URLRequest {
        let endpoint = Endpoint.advisorChat(message: message, conversationId: conversationId)
        var request = try endpoint.makeURLRequest(baseURL: baseURL)

        // SSE streams MUST be authenticated — fail fast if no token
        guard let token = await tokenProvider.currentAccessToken() else {
            throw APIError.unauthorized
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        return request
    }
}

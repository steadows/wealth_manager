import Foundation

// MARK: - AdvisorService

/// Production implementation of AdvisoryServiceProtocol.
/// Uses APIClient for JSON endpoints and URLSession for SSE streaming.
final class AdvisorService: AdvisoryServiceProtocol {
    private let apiClient: APIClientProtocol
    private let baseURL: URL
    private let tokenProvider: TokenProvider

    /// Dedicated URLSession for SSE streams with a bounded resource timeout.
    private let streamSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        return URLSession(configuration: config)
    }()

    init(apiClient: APIClientProtocol, baseURL: URL, tokenProvider: TokenProvider) {
        self.apiClient = apiClient
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
    }

    // MARK: - Streaming Chat

    /// Streams chat response chunks via Server-Sent Events.
    func streamChat(message: String, conversationId: UUID?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try await self.makeChatRequest(
                        message: message,
                        conversationId: conversationId
                    )
                    let (bytes, response) = try await self.streamSession.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw APIError.serverError(statusCode: 500, message: "Stream failed")
                    }
                    guard (200...299).contains(httpResponse.statusCode) else {
                        throw APIError.serverError(
                            statusCode: httpResponse.statusCode,
                            message: "Stream failed with status \(httpResponse.statusCode)"
                        )
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        if let chunk = self.parseSSELine(line) {
                            continuation.yield(chunk)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // Cancel the inner Task when the stream consumer stops iterating.
            continuation.onTermination = { _ in task.cancel() }
        }
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

    // MARK: - Private

    private func makeChatRequest(message: String, conversationId: UUID?) async throws -> URLRequest {
        let endpoint = Endpoint.advisorChat(message: message, conversationId: conversationId)
        var request = try endpoint.makeURLRequest(baseURL: baseURL)

        if let token = await tokenProvider.currentAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        return request
    }

    /// Parses a `data: <text>` SSE line, returning the text payload.
    /// Backend emits plain-text chunks (not JSON-encoded).
    private func parseSSELine(_ line: String) -> String? {
        guard line.hasPrefix("data: ") else { return nil }
        let payload = String(line.dropFirst(6))
        guard payload != "[DONE]" else { return nil }
        return payload
    }
}

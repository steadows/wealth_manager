import Foundation

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Endpoint

/// Describes every API route the iOS client can call.
enum Endpoint {
    // Auth
    case login(identityToken: String)
    case refreshToken
    case me

    // Accounts
    case listAccounts(offset: Int = 0, limit: Int = 100)
    case getAccount(id: UUID)
    case createAccount(AccountCreateDTO)
    case updateAccount(id: UUID, data: Data)
    case deleteAccount(id: UUID)

    // Plaid
    case createLinkToken
    case exchangeToken(publicToken: String)
    case plaidSync(accountId: UUID)

    // Sync
    case syncPull(since: Date?)
    case syncPush(ClientChangesDTO)

    // Advisory
    case advisorChat(message: String, conversationId: UUID?)
    case getBriefing(period: String)
    case getHealthScore
    case getAlerts
}

// MARK: - Endpoint Properties

extension Endpoint {

    var path: String {
        switch self {
        case .login:
            return "/api/v1/auth/login"
        case .refreshToken:
            return "/api/v1/auth/refresh"
        case .me:
            return "/api/v1/auth/me"
        case .listAccounts:
            return "/api/v1/accounts"
        case .getAccount(let id):
            return "/api/v1/accounts/\(id.uuidString)"
        case .createAccount:
            return "/api/v1/accounts"
        case .updateAccount(let id, _):
            return "/api/v1/accounts/\(id.uuidString)"
        case .deleteAccount(let id):
            return "/api/v1/accounts/\(id.uuidString)"
        case .createLinkToken:
            return "/api/v1/plaid/link-token"
        case .exchangeToken:
            return "/api/v1/plaid/exchange-token"
        case .plaidSync(let accountId):
            return "/api/v1/plaid/sync/\(accountId.uuidString)"
        case .syncPull:
            return "/api/v1/sync"
        case .syncPush:
            return "/api/v1/sync"
        case .advisorChat:
            return "/api/v1/advisor/chat"
        case .getBriefing:
            return "/api/v1/reports/briefing"
        case .getHealthScore:
            return "/api/v1/reports/health-score"
        case .getAlerts:
            return "/api/v1/alerts"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login, .refreshToken, .createAccount, .createLinkToken,
             .exchangeToken, .plaidSync, .syncPush, .advisorChat:
            return .post
        case .me, .listAccounts, .getAccount, .syncPull,
             .getBriefing, .getHealthScore, .getAlerts:
            return .get
        case .updateAccount:
            return .patch
        case .deleteAccount:
            return .delete
        }
    }

    var requiresAuth: Bool {
        switch self {
        case .login:
            return false
        default:
            return true
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .syncPull(let since):
            guard let since else { return nil }
            return [URLQueryItem(name: "since", value: ISO8601DateFormatter().string(from: since))]
        case .listAccounts(let offset, let limit):
            return [
                URLQueryItem(name: "offset", value: "\(offset)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
        case .getBriefing(let period):
            return [URLQueryItem(name: "period", value: period)]
        default:
            return nil
        }
    }

    var body: Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        switch self {
        case .login(let identityToken):
            return try? JSONSerialization.data(
                withJSONObject: ["identity_token": identityToken]
            )
        case .exchangeToken(let publicToken):
            return try? JSONSerialization.data(
                withJSONObject: ["public_token": publicToken]
            )
        case .createAccount(let dto):
            return try? encoder.encode(dto)
        case .updateAccount(_, let data):
            return data
        case .syncPush(let changes):
            return try? encoder.encode(changes)
        case .advisorChat(let message, let conversationId):
            var body: [String: Any] = ["message": message]
            if let cid = conversationId {
                body["conversation_id"] = cid.uuidString
            }
            return try? JSONSerialization.data(withJSONObject: body)
        default:
            return nil
        }
    }

    /// Constructs a URLRequest from this endpoint.
    func makeURLRequest(baseURL: URL) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)

        if let queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }
}

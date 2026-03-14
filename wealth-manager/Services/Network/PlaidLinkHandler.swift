import Foundation

// MARK: - PlaidLinkResult

/// The result of a Plaid Link session.
enum PlaidLinkResult: Equatable {
    /// User completed Link successfully with a public token and metadata.
    case success(publicToken: String, institutionName: String?)

    /// User exited Link without completing.
    case exit(errorMessage: String?)

    /// An internal error occurred before or during Link.
    case failure(Error)

    static func == (lhs: PlaidLinkResult, rhs: PlaidLinkResult) -> Bool {
        switch (lhs, rhs) {
        case let (.success(lToken, lInst), .success(rToken, rInst)):
            return lToken == rToken && lInst == rInst
        case let (.exit(lErr), .exit(rErr)):
            return lErr == rErr
        case let (.failure(lErr), .failure(rErr)):
            return lErr.localizedDescription == rErr.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - PlaidLinkHandlerProtocol

/// Abstracts the platform-specific Plaid Link presentation.
///
/// On macOS, the existing WKWebView flow is used.
/// On iOS, the native Plaid Link SDK (LinkKit) is used.
protocol PlaidLinkHandlerProtocol: Sendable {
    /// Prepares the handler with a link token obtained from the backend.
    /// Must be called before `open()`.
    func prepare(linkToken: String) async throws

    /// Opens the Plaid Link flow and returns the result.
    /// The handler is responsible for presenting platform-appropriate UI.
    func open() async -> PlaidLinkResult

    /// Whether the handler is ready to open (i.e., `prepare` succeeded).
    var isReady: Bool { get }
}

// MARK: - PlaidLinkError

/// Errors specific to Plaid Link handling.
enum PlaidLinkError: Error, Equatable, LocalizedError {
    /// The handler was not prepared with a link token before opening.
    case notPrepared

    /// The link token was empty or invalid.
    case invalidLinkToken

    /// The native SDK failed to initialize.
    case sdkInitializationFailed(String)

    /// The native SDK is not available on this platform.
    case sdkUnavailable

    var errorDescription: String? {
        switch self {
        case .notPrepared:
            return "Plaid Link handler has not been prepared with a link token."
        case .invalidLinkToken:
            return "The Plaid Link token is empty or invalid."
        case .sdkInitializationFailed(let reason):
            return "Plaid Link SDK failed to initialize: \(reason)"
        case .sdkUnavailable:
            return "Plaid Link native SDK is not available on this platform."
        }
    }
}

import AuthenticationServices
import Foundation
import os

private let logger = Logger(subsystem: "com.wealthmanager", category: "PlaidHostedLink")

// MARK: - HostedLinkOpening Protocol

/// Abstraction for opening a hosted link URL, enabling mock injection in tests.
protocol HostedLinkOpening: Sendable {
    /// Opens a hosted link URL and returns the result.
    func open(hostedLinkURL: URL) async -> PlaidLinkResult
}

// MARK: - PlaidHostedLinkHandler

/// Handles Plaid Hosted Link via ASWebAuthenticationSession on macOS (and iOS 16+).
///
/// Opens the hosted link URL in a system browser and captures the completion redirect.
/// The redirect callback is a **completion signal only** -- no `public_token` is extracted
/// from the URL. Token resolution happens server-side via `/link/token/get`.
///
/// Conforms to `PlaidLinkHandlerProtocol` for use with the existing ViewModel.
/// On success, returns `.success(publicToken: "", institutionName: nil)` as a signal
/// that the session completed. The ViewModel (task 2.1) will detect the empty token
/// and call the backend's session resolution endpoint instead of the exchange endpoint.
final class PlaidHostedLinkHandler: NSObject, PlaidLinkHandlerProtocol,
    HostedLinkOpening, ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {

    // MARK: - Constants

    /// The custom URL scheme registered in the Xcode project for Plaid callbacks.
    static let callbackURLScheme = "wealthmanager"

    /// The full redirect URI that Plaid redirects to on completion.
    static let completionRedirectURI = "wealthmanager://plaid-link-complete"

    // MARK: - State

    /// The hosted link URL provided by the backend (includes the link token).
    private var hostedLinkURL: URL?

    private(set) var isReady: Bool = false

    // MARK: - PlaidLinkHandlerProtocol

    /// Prepares the handler with a hosted link URL string.
    ///
    /// For hosted link, the `linkToken` parameter is expected to be the full
    /// hosted link URL string (e.g., `https://hosted.plaid.com/link/...`).
    /// This overloads the protocol semantics to carry the hosted URL.
    ///
    /// - Parameter linkToken: The hosted link URL string from the backend.
    /// - Throws: `PlaidLinkError.invalidLinkToken` if the string is empty or not a valid URL.
    func prepare(linkToken: String) async throws {
        guard !linkToken.isEmpty else {
            logger.error("Hosted link URL is empty")
            throw PlaidLinkError.invalidLinkToken
        }

        guard let url = URL(string: linkToken) else {
            logger.error("Invalid hosted link URL: \(linkToken, privacy: .private)")
            throw PlaidLinkError.invalidLinkToken
        }

        hostedLinkURL = url
        isReady = true
        logger.info("Prepared with hosted link URL: \(url.host() ?? "unknown", privacy: .private)")
    }

    /// Opens the Plaid Hosted Link flow via ASWebAuthenticationSession.
    ///
    /// Returns `.success(publicToken: "", institutionName: nil)` when the user completes
    /// bank authentication and Plaid redirects back. The empty `publicToken` signals
    /// that this is a hosted link completion -- the ViewModel should resolve the session
    /// server-side rather than calling the exchange endpoint.
    ///
    /// - Returns: A `PlaidLinkResult` indicating completion, exit, or failure.
    func open() async -> PlaidLinkResult {
        guard let hostedLinkURL, isReady else {
            logger.error("open() called before prepare() -- handler not ready")
            return .failure(PlaidLinkError.notPrepared)
        }

        return await openHostedLink(url: hostedLinkURL)
    }

    // MARK: - Direct URL Open

    /// Opens a hosted link URL directly without going through `prepare()`.
    ///
    /// Convenience method for callers that already have the URL object.
    ///
    /// - Parameter hostedLinkURL: The hosted link URL from the backend.
    /// - Returns: A `PlaidLinkResult` indicating completion, exit, or failure.
    func open(hostedLinkURL: URL) async -> PlaidLinkResult {
        logger.info("Opening hosted link URL directly: \(hostedLinkURL.host() ?? "unknown", privacy: .private)")
        return await openHostedLink(url: hostedLinkURL)
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(macOS)
        guard let window = NSApplication.shared.keyWindow else {
            logger.warning("No key window found -- using first window")
            return NSApplication.shared.windows.first ?? ASPresentationAnchor()
        }
        return window
        #else
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            logger.warning("No key window found -- using fallback")
            return ASPresentationAnchor()
        }
        return window
        #endif
    }

    // MARK: - Private

    /// Core implementation: creates and starts an ASWebAuthenticationSession.
    private func openHostedLink(url: URL) async -> PlaidLinkResult {
        logger.info("Opening ASWebAuthenticationSession for Plaid Hosted Link")

        return await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.callbackURLScheme
            ) { callbackURL, error in

                if let error {
                    let nsError = error as NSError

                    // ASWebAuthenticationSessionError.canceledLogin (code 1)
                    if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
                       nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        logger.info("User cancelled Plaid Hosted Link session")
                        continuation.resume(returning: .exit(errorMessage: nil))
                        return
                    }

                    logger.error("ASWebAuthenticationSession error: domain=\(nsError.domain) code=\(nsError.code) desc=\(nsError.localizedDescription)")
                    continuation.resume(returning: .failure(error))
                    return
                }

                if let callbackURL {
                    logger.info("Received redirect callback: \(callbackURL.scheme ?? "nil", privacy: .public)://\(callbackURL.host() ?? "nil", privacy: .public)")
                    // The redirect is a completion signal only -- no public_token to extract.
                    // Return success with empty publicToken to signal hosted link completion.
                    continuation.resume(returning: .success(publicToken: "", institutionName: nil))
                    return
                }

                // Should not happen, but handle defensively
                logger.warning("ASWebAuthenticationSession completed with no callback URL and no error")
                continuation.resume(returning: .exit(errorMessage: "No callback received"))
            }

            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = self

            let started = session.start()
            if !started {
                logger.error("ASWebAuthenticationSession failed to start")
                continuation.resume(returning: .failure(
                    PlaidLinkError.sdkInitializationFailed("ASWebAuthenticationSession failed to start")
                ))
            }
        }
    }
}

import Foundation
import os

private let logger = Logger(subsystem: "com.wealthmanager", category: "PlaidLinkViewModel")

// MARK: - PlaidLinkViewModel

/// Manages the Plaid Link flow: obtaining a link token, presenting the link UI,
/// and exchanging the public token for linked accounts.
///
/// Supports two flows:
/// - **iOS (LinkKit):** `startLinking()` → inline public_token → exchange
/// - **macOS (Hosted Link):** `startHostedLinking()` → ASWebAuthenticationSession →
///   completion signal → backend session resolution
@Observable
final class PlaidLinkViewModel {

    // MARK: - State

    enum LinkState: Equatable {
        case idle
        case loading
        case linkReady
        case hostedLinkReady
        case exchanging
        case resolving
        case linked
        case error
    }

    private(set) var state: LinkState = .idle {
        didSet { logger.info("State: \(String(describing: oldValue)) → \(String(describing: self.state))") }
    }
    private(set) var linkToken: String?
    private(set) var linkedAccounts: [Account] = []
    var error: String?
    var showWebView: Bool = false

    var isLoading: Bool {
        state == .loading || state == .exchanging || state == .resolving
    }

    // MARK: - Hosted Link State

    /// The hosted link URL for ASWebAuthenticationSession (macOS flow).
    private(set) var hostedLinkURL: URL?

    /// The handler used to open the hosted link session.
    private let hostedLinkHandler: any HostedLinkOpening

    /// Maximum number of retry attempts for pending session resolution.
    private static let maxResolveRetries = 5

    /// Delay between retry attempts in seconds.
    private static let resolveRetryDelay: UInt64 = 3_000_000_000  // 3 seconds in nanoseconds

    // MARK: - Dependencies

    private let plaidService: PlaidLinkServiceProtocol

    init(plaidService: PlaidLinkServiceProtocol, hostedLinkHandler: any HostedLinkOpening = PlaidHostedLinkHandler()) {
        self.plaidService = plaidService
        self.hostedLinkHandler = hostedLinkHandler
        logger.info("PlaidLinkViewModel initialized")
    }

    // MARK: - iOS Flow (unchanged)

    /// Requests a link token and transitions to the link-ready state.
    /// Used by the iOS LinkKit flow.
    func startLinking() async {
        state = .loading
        error = nil

        do {
            logger.info("Requesting link token from backend...")
            let token = try await plaidService.createLinkToken()
            logger.info("Received link token: \(token.prefix(20), privacy: .private)...")
            linkToken = token
            showWebView = true
            state = .linkReady
        } catch {
            logger.error("Failed to create link token: \(error.localizedDescription)")
            self.error = error.localizedDescription
            state = .error
        }
    }

    /// Exchanges the public token received from Plaid Link for permanent access.
    func handlePublicToken(_ publicToken: String) async {
        logger.info("Exchanging public token: \(publicToken.prefix(20), privacy: .private)...")
        state = .exchanging
        error = nil
        showWebView = false

        do {
            let accounts = try await plaidService.exchangeToken(publicToken: publicToken)
            logger.info("Exchange successful: \(accounts.count) accounts linked")
            linkedAccounts = accounts
            state = .linked
        } catch {
            logger.error("Token exchange failed: \(error.localizedDescription)")
            self.error = error.localizedDescription
            state = .error
        }
    }

    // MARK: - macOS Hosted Link Flow

    /// Starts the Hosted Link flow for macOS:
    /// 1. Requests hosted link token + URL from backend
    /// 2. Opens ASWebAuthenticationSession via `PlaidHostedLinkHandler`
    /// 3. On completion signal, resolves the session server-side
    /// 4. Returns linked accounts on success
    func startHostedLinking() async {
        state = .loading
        error = nil

        do {
            // Step 1: Get hosted link token + URL from backend
            logger.info("Requesting hosted link token from backend...")
            let (token, url) = try await plaidService.createHostedLinkToken()
            logger.info("Received hosted link token: \(token.prefix(20), privacy: .private)...")
            linkToken = token
            hostedLinkURL = url
            state = .hostedLinkReady

            // Step 2: Open ASWebAuthenticationSession
            logger.info("Opening hosted link in system browser...")
            let result = await hostedLinkHandler.open(hostedLinkURL: url)

            // Step 3: Handle the result
            switch result {
            case .success:
                // Completion signal received — resolve session server-side
                logger.info("Hosted link completed — resolving session...")
                await resolveHostedSession()

            case .exit(let errorMessage):
                logger.info("User exited hosted link: \(errorMessage ?? "no message")")
                state = .idle

            case .failure(let linkError):
                logger.error("Hosted link failed: \(linkError.localizedDescription)")
                self.error = linkError.localizedDescription
                state = .error
            }
        } catch {
            logger.error("Failed to start hosted linking: \(error.localizedDescription)")
            self.error = error.localizedDescription
            state = .error
        }
    }

    /// Resolves a completed Hosted Link session by calling the backend's
    /// `/resolve-session` endpoint with the stored link token.
    ///
    /// Retries up to 3 times with 2-second intervals if the session is still pending.
    private func resolveHostedSession() async {
        guard let token = linkToken else {
            logger.error("resolveHostedSession called but linkToken is nil")
            self.error = "Missing link token for session resolution."
            state = .error
            return
        }

        state = .resolving

        for attempt in 1...Self.maxResolveRetries {
            logger.info("Resolve attempt \(attempt)/\(Self.maxResolveRetries) for token: \(token.prefix(20), privacy: .private)...")

            do {
                let accounts = try await plaidService.resolveSession(linkToken: token)
                logger.info("Session resolved: \(accounts.count) accounts linked")
                linkedAccounts = accounts
                state = .linked
                return
            } catch let sessionError as PlaidSessionError {
                // Session not yet complete — retry if attempts remain
                logger.warning("Session not complete on attempt \(attempt): \(sessionError.localizedDescription)")
                if attempt < Self.maxResolveRetries {
                    try? await Task.sleep(nanoseconds: Self.resolveRetryDelay)
                } else {
                    logger.error("Session resolution exhausted all retries")
                    self.error = "Bank connection is still processing. Please try again in a moment."
                    state = .error
                }
            } catch {
                logger.error("Session resolution failed: \(error.localizedDescription)")
                self.error = error.localizedDescription
                state = .error
                return
            }
        }
    }

    // MARK: - Common Handlers

    /// Called when the user exits Plaid Link without completing.
    func handleExit() {
        logger.info("User exited Plaid Link")
        showWebView = false
        state = .idle
    }

    /// Called when a Plaid Link handler encounters an error.
    func handleLinkError(_ error: Error) {
        logger.error("Plaid Link handler error: \(error.localizedDescription)")
        showWebView = false
        self.error = error.localizedDescription
        state = .error
    }

    /// Handles a `PlaidLinkResult` from a `PlaidLinkHandlerProtocol`.
    /// Dispatches to the appropriate handler method based on the result type.
    func handleLinkResult(_ result: PlaidLinkResult) async {
        switch result {
        case .success(let publicToken, _):
            await handlePublicToken(publicToken)
        case .exit:
            handleExit()
        case .failure(let error):
            handleLinkError(error)
        }
    }

    /// Resets all state back to idle.
    func reset() {
        logger.info("Resetting PlaidLinkViewModel")
        state = .idle
        linkToken = nil
        hostedLinkURL = nil
        linkedAccounts = []
        error = nil
        showWebView = false
    }
}

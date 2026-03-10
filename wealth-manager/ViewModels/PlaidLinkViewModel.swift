import Foundation

// MARK: - PlaidLinkViewModel

/// Manages the Plaid Link flow: obtaining a link token, presenting the web view,
/// and exchanging the public token for linked accounts.
@Observable
final class PlaidLinkViewModel {

    // MARK: - State

    enum LinkState: Equatable {
        case idle
        case loading
        case linkReady
        case exchanging
        case linked
        case error
    }

    private(set) var state: LinkState = .idle
    private(set) var linkToken: String?
    private(set) var linkedAccounts: [Account] = []
    var error: String?
    var showWebView: Bool = false

    var isLoading: Bool {
        state == .loading || state == .exchanging
    }

    /// The URL to load in the Plaid Link WKWebView.
    var currentLinkURL: URL? {
        guard let linkToken else { return nil }
        return plaidService.linkURL(for: linkToken)
    }

    // MARK: - Dependencies

    private let plaidService: PlaidLinkServiceProtocol

    init(plaidService: PlaidLinkServiceProtocol) {
        self.plaidService = plaidService
    }

    // MARK: - Actions

    /// Requests a link token and transitions to the link-ready state.
    func startLinking() async {
        state = .loading
        error = nil

        do {
            let token = try await plaidService.createLinkToken()
            linkToken = token
            showWebView = true
            state = .linkReady
        } catch {
            self.error = error.localizedDescription
            state = .error
        }
    }

    /// Exchanges the public token received from Plaid Link for permanent access.
    func handlePublicToken(_ publicToken: String) async {
        state = .exchanging
        error = nil
        showWebView = false

        do {
            let accounts = try await plaidService.exchangeToken(publicToken: publicToken)
            linkedAccounts = accounts
            state = .linked
        } catch {
            self.error = error.localizedDescription
            state = .error
        }
    }

    /// Called when the user exits Plaid Link without completing.
    func handleExit() {
        showWebView = false
        state = .idle
    }

    /// Resets all state back to idle.
    func reset() {
        state = .idle
        linkToken = nil
        linkedAccounts = []
        error = nil
        showWebView = false
    }
}

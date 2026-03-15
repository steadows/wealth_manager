import Testing
import Foundation

@testable import wealth_manager

// MARK: - MockHostedLinkOpener

final class MockHostedLinkOpener: HostedLinkOpening, @unchecked Sendable {
    var resultToReturn: PlaidLinkResult = .success(publicToken: "", institutionName: nil)
    var openCallCount = 0
    var lastOpenedURL: URL?

    func open(hostedLinkURL: URL) async -> PlaidLinkResult {
        openCallCount += 1
        lastOpenedURL = hostedLinkURL
        return resultToReturn
    }
}

// MARK: - MockPlaidLinkService

final class MockPlaidLinkService: PlaidLinkServiceProtocol, @unchecked Sendable {
    var linkTokenToReturn: String = "link-sandbox-test"
    var accountsToReturn: [Account] = []
    var shouldThrow: Error?
    var createLinkTokenCallCount = 0
    var exchangeTokenCallCount = 0
    var lastExchangedPublicToken: String?

    // Hosted link properties
    var hostedLinkTokenToReturn: String = "link-hosted-test"
    var hostedLinkURLToReturn: URL = URL(string: "https://hosted.plaid.com/link/test")!
    var hostedLinkAccountsToReturn: [Account] = []
    var hostedLinkError: Error?
    var createHostedLinkTokenCallCount = 0
    var resolveSessionCallCount = 0
    var lastResolvedLinkToken: String?

    func createLinkToken() async throws -> String {
        createLinkTokenCallCount += 1
        if let error = shouldThrow { throw error }
        return linkTokenToReturn
    }

    func exchangeToken(publicToken: String) async throws -> [Account] {
        exchangeTokenCallCount += 1
        lastExchangedPublicToken = publicToken
        if let error = shouldThrow { throw error }
        return accountsToReturn
    }

    func createHostedLinkToken() async throws -> (linkToken: String, hostedLinkURL: URL) {
        createHostedLinkTokenCallCount += 1
        if let error = hostedLinkError ?? shouldThrow { throw error }
        return (linkToken: hostedLinkTokenToReturn, hostedLinkURL: hostedLinkURLToReturn)
    }

    func resolveSession(linkToken: String) async throws -> [Account] {
        resolveSessionCallCount += 1
        lastResolvedLinkToken = linkToken
        if let error = hostedLinkError ?? shouldThrow { throw error }
        return hostedLinkAccountsToReturn
    }
}

// MARK: - PlaidLinkViewModelTests

@Suite("PlaidLinkViewModel")
struct PlaidLinkViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(
        plaidService: MockPlaidLinkService = MockPlaidLinkService(),
        hostedLinkHandler: MockHostedLinkOpener = MockHostedLinkOpener()
    ) -> (PlaidLinkViewModel, MockPlaidLinkService, MockHostedLinkOpener) {
        let vm = PlaidLinkViewModel(plaidService: plaidService, hostedLinkHandler: hostedLinkHandler)
        return (vm, plaidService, hostedLinkHandler)
    }

    private func makeSampleAccount(name: String = "Checking") -> Account {
        Account(
            institutionName: "Chase",
            accountName: name,
            accountType: .checking,
            currentBalance: 5000,
            isManual: false
        )
    }

    // MARK: - Initial State

    @Test("initial state is idle")
    func initialState() {
        let (vm, _, _) = makeViewModel()

        #expect(vm.state == .idle)
        #expect(!vm.isLoading)
        #expect(vm.error == nil)
        #expect(vm.linkedAccounts.isEmpty)
        #expect(!vm.showWebView)
    }

    // MARK: - Start Linking

    @Test("startLinking: sets loading, fetches token, shows web view")
    func startLinkingSuccess() async {
        let mockService = MockPlaidLinkService()
        mockService.linkTokenToReturn = "link-sandbox-abc"
        let (vm, _, _) = makeViewModel(plaidService: mockService)

        await vm.startLinking()

        #expect(vm.state == .linkReady)
        #expect(!vm.isLoading)
        #expect(vm.linkToken == "link-sandbox-abc")
        #expect(vm.showWebView)
        #expect(vm.error == nil)
        #expect(mockService.createLinkTokenCallCount == 1)
    }

    @Test("startLinking: sets error on failure")
    func startLinkingFailure() async {
        let mockService = MockPlaidLinkService()
        mockService.shouldThrow = APIError.serverError(statusCode: 500, message: "Failed")
        let (vm, _, _) = makeViewModel(plaidService: mockService)

        await vm.startLinking()

        #expect(vm.state == .error)
        #expect(!vm.isLoading)
        #expect(vm.error != nil)
        #expect(!vm.showWebView)
    }

    // MARK: - Handle Public Token

    @Test("handlePublicToken: exchanges token and returns accounts")
    func handlePublicTokenSuccess() async {
        let mockService = MockPlaidLinkService()
        let account = makeSampleAccount()
        mockService.accountsToReturn = [account]
        let (vm, _, _) = makeViewModel(plaidService: mockService)

        await vm.handlePublicToken("public-sandbox-xyz")

        #expect(vm.state == .linked)
        #expect(!vm.isLoading)
        #expect(vm.linkedAccounts.count == 1)
        #expect(vm.linkedAccounts[0].institutionName == "Chase")
        #expect(!vm.showWebView)
        #expect(vm.error == nil)
        #expect(mockService.exchangeTokenCallCount == 1)
        #expect(mockService.lastExchangedPublicToken == "public-sandbox-xyz")
    }

    @Test("handlePublicToken: sets error on exchange failure")
    func handlePublicTokenFailure() async {
        let mockService = MockPlaidLinkService()
        mockService.shouldThrow = APIError.networkError(
            NSError(domain: "test", code: -1)
        )
        let (vm, _, _) = makeViewModel(plaidService: mockService)

        await vm.handlePublicToken("public-token")

        #expect(vm.state == .error)
        #expect(!vm.isLoading)
        #expect(vm.error != nil)
        #expect(vm.linkedAccounts.isEmpty)
    }

    // MARK: - Handle Exit

    @Test("handleExit: dismisses web view and resets to idle")
    func handleExit() async {
        let mockService = MockPlaidLinkService()
        let (vm, _, _) = makeViewModel(plaidService: mockService)

        // First start linking to get into linkReady state
        await vm.startLinking()
        #expect(vm.showWebView)

        vm.handleExit()

        #expect(!vm.showWebView)
        #expect(vm.state == .idle)
    }

    // MARK: - Reset

    @Test("reset: clears all state")
    func resetClearsState() async {
        let mockService = MockPlaidLinkService()
        let account = makeSampleAccount()
        mockService.accountsToReturn = [account]
        let (vm, _, _) = makeViewModel(plaidService: mockService)

        // Get into linked state
        await vm.handlePublicToken("token")
        #expect(!vm.linkedAccounts.isEmpty)

        vm.reset()

        #expect(vm.state == .idle)
        #expect(vm.linkedAccounts.isEmpty)
        #expect(vm.linkToken == nil)
        #expect(vm.error == nil)
        #expect(!vm.showWebView)
    }

    // MARK: - Hosted Link: Happy Path

    @Test("startHostedLinking: full flow — fetches token, opens handler, resolves session, returns accounts")
    func startHostedLinkingSuccess() async {
        let mockService = MockPlaidLinkService()
        let mockHandler = MockHostedLinkOpener()
        let account = makeSampleAccount()
        mockService.hostedLinkAccountsToReturn = [account]
        mockHandler.resultToReturn = .success(publicToken: "", institutionName: nil)
        let (vm, _, _) = makeViewModel(plaidService: mockService, hostedLinkHandler: mockHandler)

        await vm.startHostedLinking()

        #expect(vm.state == .linked)
        #expect(vm.linkedAccounts.count == 1)
        #expect(vm.linkedAccounts[0].institutionName == "Chase")
        #expect(vm.linkToken == "link-hosted-test")
        #expect(vm.hostedLinkURL == URL(string: "https://hosted.plaid.com/link/test")!)
        #expect(vm.error == nil)
        #expect(mockService.createHostedLinkTokenCallCount == 1)
        #expect(mockService.resolveSessionCallCount == 1)
        #expect(mockService.lastResolvedLinkToken == "link-hosted-test")
        #expect(mockHandler.openCallCount == 1)
        #expect(mockHandler.lastOpenedURL == URL(string: "https://hosted.plaid.com/link/test")!)
    }

    // MARK: - Hosted Link: Create Token Failure

    @Test("startHostedLinking: error when createHostedLinkToken fails")
    func startHostedLinkingCreateTokenFailure() async {
        let mockService = MockPlaidLinkService()
        mockService.hostedLinkError = APIError.serverError(statusCode: 500, message: "Backend down")
        let mockHandler = MockHostedLinkOpener()
        let (vm, _, _) = makeViewModel(plaidService: mockService, hostedLinkHandler: mockHandler)

        await vm.startHostedLinking()

        #expect(vm.state == .error)
        #expect(vm.error != nil)
        #expect(!vm.isLoading)
        #expect(mockService.createHostedLinkTokenCallCount == 1)
        #expect(mockHandler.openCallCount == 0)
        #expect(mockService.resolveSessionCallCount == 0)
    }

    // MARK: - Hosted Link: Session Resolution Failure

    @Test("startHostedLinking: error when resolveSession fails with non-session error")
    func startHostedLinkingResolveFailure() async {
        let service = DifferentiatingMockPlaidService()
        service.resolveError = APIError.networkError(NSError(domain: "test", code: -1))
        let handler = MockHostedLinkOpener()
        handler.resultToReturn = .success(publicToken: "", institutionName: nil)
        let vm = PlaidLinkViewModel(plaidService: service, hostedLinkHandler: handler)

        await vm.startHostedLinking()

        #expect(vm.state == .error)
        #expect(vm.error != nil)
        #expect(service.resolveSessionCallCount == 1)
    }

    // MARK: - Hosted Link: User Cancels ASWebAuth

    @Test("startHostedLinking: user exits ASWebAuth — returns to idle")
    func startHostedLinkingUserExit() async {
        let mockService = MockPlaidLinkService()
        let mockHandler = MockHostedLinkOpener()
        mockHandler.resultToReturn = .exit(errorMessage: nil)
        let (vm, _, _) = makeViewModel(plaidService: mockService, hostedLinkHandler: mockHandler)

        await vm.startHostedLinking()

        #expect(vm.state == .idle)
        #expect(vm.error == nil)
        #expect(mockService.resolveSessionCallCount == 0)
        #expect(mockHandler.openCallCount == 1)
    }

    @Test("startHostedLinking: user exits with error message — returns to idle")
    func startHostedLinkingUserExitWithMessage() async {
        let mockService = MockPlaidLinkService()
        let mockHandler = MockHostedLinkOpener()
        mockHandler.resultToReturn = .exit(errorMessage: "USER_CANCELLED")
        let (vm, _, _) = makeViewModel(plaidService: mockService, hostedLinkHandler: mockHandler)

        await vm.startHostedLinking()

        #expect(vm.state == .idle)
        #expect(vm.error == nil)
    }

    // MARK: - Hosted Link: ASWebAuth Failure

    @Test("startHostedLinking: ASWebAuth handler returns failure — sets error")
    func startHostedLinkingHandlerFailure() async {
        let mockService = MockPlaidLinkService()
        let mockHandler = MockHostedLinkOpener()
        mockHandler.resultToReturn = .failure(PlaidLinkError.sdkInitializationFailed("session failed"))
        let (vm, _, _) = makeViewModel(plaidService: mockService, hostedLinkHandler: mockHandler)

        await vm.startHostedLinking()

        #expect(vm.state == .error)
        #expect(vm.error != nil)
        #expect(mockService.resolveSessionCallCount == 0)
    }

    // MARK: - Hosted Link: Session Pending Retries Exhausted

    @Test("startHostedLinking: session pending exhausts retries — sets user-friendly error")
    func startHostedLinkingPendingRetriesExhausted() async {
        let service = DifferentiatingMockPlaidService()
        service.resolveError = PlaidSessionError.sessionNotComplete(status: "pending")
        let handler = MockHostedLinkOpener()
        handler.resultToReturn = .success(publicToken: "", institutionName: nil)
        let vm = PlaidLinkViewModel(plaidService: service, hostedLinkHandler: handler)

        await vm.startHostedLinking()

        #expect(vm.state == .error)
        #expect(vm.error?.contains("still processing") == true)
        // Should retry maxResolveRetries (3) times
        #expect(service.resolveSessionCallCount == 3)
    }

    // MARK: - Reset clears hosted link state

    @Test("reset: clears hostedLinkURL")
    func resetClearsHostedLinkState() async {
        let mockService = MockPlaidLinkService()
        let mockHandler = MockHostedLinkOpener()
        mockHandler.resultToReturn = .exit(errorMessage: nil)
        let (vm, _, _) = makeViewModel(plaidService: mockService, hostedLinkHandler: mockHandler)

        // Start hosted linking to populate hostedLinkURL
        await vm.startHostedLinking()
        #expect(vm.hostedLinkURL != nil)

        vm.reset()

        #expect(vm.hostedLinkURL == nil)
        #expect(vm.state == .idle)
        #expect(vm.linkToken == nil)
    }
}

// MARK: - DifferentiatingMockPlaidService

/// A mock that allows different error behavior for createHostedLinkToken vs resolveSession.
final class DifferentiatingMockPlaidService: PlaidLinkServiceProtocol, @unchecked Sendable {
    var linkToken: String = "link-hosted-diff-test"
    var hostedLinkURL: URL = URL(string: "https://hosted.plaid.com/link/diff-test")!
    var resolveError: Error?
    var resolveAccounts: [Account] = []
    var resolveSessionCallCount = 0

    func createLinkToken() async throws -> String { "link-sandbox-test" }
    func exchangeToken(publicToken: String) async throws -> [Account] { [] }

    func createHostedLinkToken() async throws -> (linkToken: String, hostedLinkURL: URL) {
        (linkToken: linkToken, hostedLinkURL: hostedLinkURL)
    }

    func resolveSession(linkToken: String) async throws -> [Account] {
        resolveSessionCallCount += 1
        if let error = resolveError { throw error }
        return resolveAccounts
    }
}

import Testing
import Foundation

@testable import wealth_manager

// MARK: - MockPlaidLinkService

final class MockPlaidLinkService: PlaidLinkServiceProtocol, @unchecked Sendable {
    var linkTokenToReturn: String = "link-sandbox-test"
    var accountsToReturn: [Account] = []
    var shouldThrow: Error?
    var createLinkTokenCallCount = 0
    var exchangeTokenCallCount = 0
    var lastExchangedPublicToken: String?

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

    func linkURL(for linkToken: String) -> URL {
        URL(string: "https://cdn.plaid.com/link/v2/stable/link.html?isWebview=true&token=\(linkToken)")!
    }
}

// MARK: - PlaidLinkViewModelTests

@Suite("PlaidLinkViewModel")
struct PlaidLinkViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(
        plaidService: MockPlaidLinkService = MockPlaidLinkService()
    ) -> (PlaidLinkViewModel, MockPlaidLinkService) {
        let vm = PlaidLinkViewModel(plaidService: plaidService)
        return (vm, plaidService)
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
        let (vm, _) = makeViewModel()

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
        let (vm, _) = makeViewModel(plaidService: mockService)

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
        let (vm, _) = makeViewModel(plaidService: mockService)

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
        let (vm, _) = makeViewModel(plaidService: mockService)

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
        let (vm, _) = makeViewModel(plaidService: mockService)

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
        let (vm, _) = makeViewModel(plaidService: mockService)

        // First start linking to get into linkReady state
        await vm.startLinking()
        #expect(vm.showWebView)

        vm.handleExit()

        #expect(!vm.showWebView)
        #expect(vm.state == .idle)
    }

    // MARK: - Link URL

    @Test("linkURL: delegates to service")
    func linkURLDelegatesToService() async {
        let mockService = MockPlaidLinkService()
        mockService.linkTokenToReturn = "link-token-abc"
        let (vm, _) = makeViewModel(plaidService: mockService)

        await vm.startLinking()
        let url = vm.currentLinkURL

        #expect(url?.absoluteString.contains("link-token-abc") == true)
    }

    // MARK: - Reset

    @Test("reset: clears all state")
    func resetClearsState() async {
        let mockService = MockPlaidLinkService()
        let account = makeSampleAccount()
        mockService.accountsToReturn = [account]
        let (vm, _) = makeViewModel(plaidService: mockService)

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
}

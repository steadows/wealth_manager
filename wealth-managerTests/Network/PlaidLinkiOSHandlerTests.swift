import Testing
import Foundation

@testable import wealth_manager

// MARK: - PlaidLinkiOSHandler Tests

/// Tests for the iOS-specific Plaid Link handler.
/// Since LinkKit is only available on iOS, these tests validate
/// the handler's state machine and error handling using protocol-based
/// testing that works on all platforms.
@Suite("PlaidLinkiOSHandler")
struct PlaidLinkiOSHandlerTests {

    // MARK: - State Machine via Protocol

    @Test("handler starts in not-ready state")
    func initialState() {
        let handler = MockPlaidLinkHandler()

        #expect(!handler.isReady)
        #expect(handler.preparedLinkToken == nil)
    }

    @Test("handler transitions to ready after prepare")
    func prepareTransitionsToReady() async throws {
        let handler = MockPlaidLinkHandler()

        try await handler.prepare(linkToken: "link-sandbox-abc")

        #expect(handler.isReady)
    }

    @Test("prepare can be called multiple times with different tokens")
    func prepareMultipleTimes() async throws {
        let handler = MockPlaidLinkHandler()

        try await handler.prepare(linkToken: "token-1")
        #expect(handler.preparedLinkToken == "token-1")

        try await handler.prepare(linkToken: "token-2")
        #expect(handler.preparedLinkToken == "token-2")
        #expect(handler.prepareCallCount == 2)
    }

    // MARK: - ViewModel Integration with Handler

    @Test("viewModel uses handler for iOS link flow: success path")
    func viewModelHandlerSuccessFlow() async {
        let mockService = MockPlaidLinkService()
        mockService.linkTokenToReturn = "link-sandbox-abc"
        let account = Account(
            institutionName: "Chase",
            accountName: "Checking",
            accountType: .checking,
            currentBalance: 5000,
            isManual: false
        )
        mockService.accountsToReturn = [account]

        let mockHandler = MockPlaidLinkHandler()
        mockHandler.resultToReturn = .success(
            publicToken: "public-sandbox-xyz",
            institutionName: "Chase"
        )

        let vm = PlaidLinkViewModel(plaidService: mockService)

        // Simulate the iOS flow: get link token, prepare handler, open
        await vm.startLinking()
        #expect(vm.state == .linkReady)
        #expect(vm.linkToken == "link-sandbox-abc")

        // Simulate handler interaction
        try? await mockHandler.prepare(linkToken: vm.linkToken!)
        let result = await mockHandler.open()

        // Extract public token from result and pass to VM
        if case .success(let publicToken, _) = result {
            await vm.handlePublicToken(publicToken)
        }

        #expect(vm.state == .linked)
        #expect(vm.linkedAccounts.count == 1)
        #expect(mockService.exchangeTokenCallCount == 1)
        #expect(mockService.lastExchangedPublicToken == "public-sandbox-xyz")
    }

    @Test("viewModel uses handler for iOS link flow: user exit path")
    func viewModelHandlerExitFlow() async {
        let mockService = MockPlaidLinkService()
        mockService.linkTokenToReturn = "link-sandbox-abc"

        let mockHandler = MockPlaidLinkHandler()
        mockHandler.resultToReturn = .exit(errorMessage: nil)

        let vm = PlaidLinkViewModel(plaidService: mockService)

        await vm.startLinking()
        #expect(vm.state == .linkReady)

        // Simulate handler returning exit
        try? await mockHandler.prepare(linkToken: vm.linkToken!)
        let result = await mockHandler.open()

        if case .exit = result {
            vm.handleExit()
        }

        #expect(vm.state == .idle)
        #expect(!vm.showWebView)
    }

    @Test("viewModel uses handler for iOS link flow: failure path")
    func viewModelHandlerFailurePath() async {
        let mockService = MockPlaidLinkService()
        mockService.linkTokenToReturn = "link-sandbox-abc"

        let mockHandler = MockPlaidLinkHandler()
        mockHandler.resultToReturn = .failure(PlaidLinkError.sdkInitializationFailed("crash"))

        let vm = PlaidLinkViewModel(plaidService: mockService)

        await vm.startLinking()
        #expect(vm.state == .linkReady)

        // Simulate handler returning failure
        try? await mockHandler.prepare(linkToken: vm.linkToken!)
        let result = await mockHandler.open()

        if case .failure(let error) = result {
            vm.handleLinkError(error)
        }

        #expect(vm.state == .error)
        #expect(vm.error != nil)
    }

    @Test("viewModel handleLinkResult dispatches correctly for all result types")
    func handleLinkResultDispatches() async {
        let mockService = MockPlaidLinkService()
        let account = Account(
            institutionName: "Chase",
            accountName: "Savings",
            accountType: .savings,
            currentBalance: 10000,
            isManual: false
        )
        mockService.accountsToReturn = [account]
        let vm = PlaidLinkViewModel(plaidService: mockService)

        // Test success
        await vm.handleLinkResult(.success(publicToken: "pub-token", institutionName: "Chase"))
        #expect(vm.state == .linked)

        // Reset and test exit
        vm.reset()
        await vm.handleLinkResult(.exit(errorMessage: nil))
        #expect(vm.state == .idle)

        // Reset and test exit with error
        vm.reset()
        await vm.handleLinkResult(.exit(errorMessage: "INSTITUTION_NOT_FOUND"))
        #expect(vm.state == .idle)

        // Reset and test failure
        vm.reset()
        await vm.handleLinkResult(.failure(PlaidLinkError.sdkInitializationFailed("test")))
        #expect(vm.state == .error)
        #expect(vm.error != nil)
    }
}

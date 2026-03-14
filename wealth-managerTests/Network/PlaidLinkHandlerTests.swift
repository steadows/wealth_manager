import Testing
import Foundation

@testable import wealth_manager

// MARK: - MockPlaidLinkHandler

final class MockPlaidLinkHandler: PlaidLinkHandlerProtocol, @unchecked Sendable {
    var preparedLinkToken: String?
    var prepareCallCount = 0
    var openCallCount = 0
    var shouldThrowOnPrepare: Error?
    var resultToReturn: PlaidLinkResult = .exit(errorMessage: nil)

    private(set) var _isReady = false
    var isReady: Bool { _isReady }

    func prepare(linkToken: String) async throws {
        prepareCallCount += 1
        if let error = shouldThrowOnPrepare { throw error }
        preparedLinkToken = linkToken
        _isReady = true
    }

    func open() async -> PlaidLinkResult {
        openCallCount += 1
        return resultToReturn
    }
}

// MARK: - PlaidLinkHandlerProtocol Contract Tests

@Suite("PlaidLinkHandlerProtocol Contract")
struct PlaidLinkHandlerContractTests {

    // MARK: - Prepare

    @Test("prepare stores the link token and marks handler as ready")
    func prepareSuccess() async throws {
        let handler = MockPlaidLinkHandler()

        #expect(!handler.isReady)

        try await handler.prepare(linkToken: "link-sandbox-abc123")

        #expect(handler.isReady)
        #expect(handler.preparedLinkToken == "link-sandbox-abc123")
        #expect(handler.prepareCallCount == 1)
    }

    @Test("prepare throws on invalid link token")
    func prepareThrowsOnInvalid() async {
        let handler = MockPlaidLinkHandler()
        handler.shouldThrowOnPrepare = PlaidLinkError.invalidLinkToken

        await #expect(throws: PlaidLinkError.self) {
            try await handler.prepare(linkToken: "")
        }
        #expect(!handler.isReady)
    }

    @Test("prepare throws on SDK initialization failure")
    func prepareThrowsOnSDKFailure() async {
        let handler = MockPlaidLinkHandler()
        handler.shouldThrowOnPrepare = PlaidLinkError.sdkInitializationFailed("timeout")

        await #expect(throws: PlaidLinkError.self) {
            try await handler.prepare(linkToken: "link-sandbox-abc")
        }
        #expect(!handler.isReady)
    }

    // MARK: - Open

    @Test("open returns success result with public token")
    func openReturnsSuccess() async throws {
        let handler = MockPlaidLinkHandler()
        handler.resultToReturn = .success(
            publicToken: "public-sandbox-xyz",
            institutionName: "Chase"
        )
        try await handler.prepare(linkToken: "link-sandbox-abc")

        let result = await handler.open()

        #expect(result == .success(publicToken: "public-sandbox-xyz", institutionName: "Chase"))
        #expect(handler.openCallCount == 1)
    }

    @Test("open returns exit result when user cancels")
    func openReturnsExit() async throws {
        let handler = MockPlaidLinkHandler()
        handler.resultToReturn = .exit(errorMessage: nil)
        try await handler.prepare(linkToken: "link-sandbox-abc")

        let result = await handler.open()

        #expect(result == .exit(errorMessage: nil))
    }

    @Test("open returns exit with error message on Plaid error")
    func openReturnsExitWithError() async throws {
        let handler = MockPlaidLinkHandler()
        handler.resultToReturn = .exit(errorMessage: "INSTITUTION_NOT_FOUND")
        try await handler.prepare(linkToken: "link-sandbox-abc")

        let result = await handler.open()

        #expect(result == .exit(errorMessage: "INSTITUTION_NOT_FOUND"))
    }

    @Test("open returns failure result on internal error")
    func openReturnsFailure() async throws {
        let handler = MockPlaidLinkHandler()
        let error = PlaidLinkError.sdkInitializationFailed("crash")
        handler.resultToReturn = .failure(error)
        try await handler.prepare(linkToken: "link-sandbox-abc")

        let result = await handler.open()

        #expect(result == .failure(error))
    }
}

// MARK: - PlaidLinkResult Tests

@Suite("PlaidLinkResult")
struct PlaidLinkResultTests {

    @Test("success equality matches on publicToken and institutionName")
    func successEquality() {
        let a = PlaidLinkResult.success(publicToken: "abc", institutionName: "Chase")
        let b = PlaidLinkResult.success(publicToken: "abc", institutionName: "Chase")
        let c = PlaidLinkResult.success(publicToken: "xyz", institutionName: "Chase")
        let d = PlaidLinkResult.success(publicToken: "abc", institutionName: nil)

        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }

    @Test("exit equality matches on errorMessage")
    func exitEquality() {
        let a = PlaidLinkResult.exit(errorMessage: nil)
        let b = PlaidLinkResult.exit(errorMessage: nil)
        let c = PlaidLinkResult.exit(errorMessage: "error")

        #expect(a == b)
        #expect(a != c)
    }

    @Test("success and exit are not equal")
    func crossTypeInequality() {
        let success = PlaidLinkResult.success(publicToken: "abc", institutionName: nil)
        let exit = PlaidLinkResult.exit(errorMessage: nil)

        #expect(success != exit)
    }
}

// MARK: - PlaidLinkError Tests

@Suite("PlaidLinkError")
struct PlaidLinkErrorTests {

    @Test("notPrepared has descriptive message")
    func notPreparedDescription() {
        let error = PlaidLinkError.notPrepared
        #expect(error.errorDescription?.contains("not been prepared") == true)
    }

    @Test("invalidLinkToken has descriptive message")
    func invalidLinkTokenDescription() {
        let error = PlaidLinkError.invalidLinkToken
        #expect(error.errorDescription?.contains("empty or invalid") == true)
    }

    @Test("sdkInitializationFailed includes reason")
    func sdkInitFailedDescription() {
        let error = PlaidLinkError.sdkInitializationFailed("timeout")
        #expect(error.errorDescription?.contains("timeout") == true)
    }

    @Test("sdkUnavailable has descriptive message")
    func sdkUnavailableDescription() {
        let error = PlaidLinkError.sdkUnavailable
        #expect(error.errorDescription?.contains("not available") == true)
    }

    @Test("equality works for all cases")
    func equality() {
        #expect(PlaidLinkError.notPrepared == PlaidLinkError.notPrepared)
        #expect(PlaidLinkError.invalidLinkToken == PlaidLinkError.invalidLinkToken)
        #expect(PlaidLinkError.sdkUnavailable == PlaidLinkError.sdkUnavailable)
        #expect(PlaidLinkError.sdkInitializationFailed("a") == PlaidLinkError.sdkInitializationFailed("a"))
        #expect(PlaidLinkError.sdkInitializationFailed("a") != PlaidLinkError.sdkInitializationFailed("b"))
        #expect(PlaidLinkError.notPrepared != PlaidLinkError.invalidLinkToken)
    }
}

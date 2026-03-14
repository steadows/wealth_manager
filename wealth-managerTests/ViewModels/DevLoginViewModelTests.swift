import Testing
import Foundation

@testable import wealth_manager

// MARK: - MockDevAuthProvider

/// Mock implementation of DevAuthProvider for testing DevLoginViewModel.
final class MockDevAuthProvider: DevAuthProvider, @unchecked Sendable {
    var isAuthenticated: Bool = false
    var shouldThrow: Error?
    var devSignInCalled = false

    func devSignIn() async throws {
        devSignInCalled = true
        if let error = shouldThrow {
            throw error
        }
        isAuthenticated = true
    }
}

// MARK: - DevLoginViewModelTests

@Suite("DevLoginViewModel")
struct DevLoginViewModelTests {

    @Test("signIn calls authService.devSignIn and sets isSignedIn on success")
    func signInSuccess() async {
        let mockAuth = MockDevAuthProvider()
        let vm = DevLoginViewModel(authService: mockAuth)

        await vm.signIn()

        #expect(mockAuth.devSignInCalled)
        #expect(vm.isSignedIn)
        #expect(vm.error == nil)
    }

    @Test("signIn sets error message on failure")
    func signInFailure() async {
        let mockAuth = MockDevAuthProvider()
        mockAuth.shouldThrow = APIError.serverError(statusCode: 500, message: "Backend down")
        let vm = DevLoginViewModel(authService: mockAuth)

        await vm.signIn()

        #expect(!vm.isSignedIn)
        #expect(vm.error != nil)
    }

    @Test("signIn sets isLoading to false after completion")
    func signInSetsLoading() async {
        let mockAuth = MockDevAuthProvider()
        let vm = DevLoginViewModel(authService: mockAuth)

        await vm.signIn()

        #expect(!vm.isLoading)
    }

    @Test("checkBackendHealth sets isBackendReachable to true on success")
    func healthCheckSuccess() async {
        let mockClient = MockAPIClient()
        mockClient.responses["/health"] = HealthResponseDTO(status: "ok")
        let vm = DevLoginViewModel(
            authService: MockDevAuthProvider(),
            healthAPIClient: mockClient
        )

        await vm.checkBackendHealth()

        #expect(vm.isBackendReachable == true)
    }

    @Test("checkBackendHealth sets isBackendReachable to false on failure")
    func healthCheckFailure() async {
        let mockClient = MockAPIClient()
        mockClient.shouldThrow = APIError.networkError(
            NSError(domain: "test", code: -1)
        )
        let vm = DevLoginViewModel(
            authService: MockDevAuthProvider(),
            healthAPIClient: mockClient
        )

        await vm.checkBackendHealth()

        #expect(vm.isBackendReachable == false)
    }

    @Test("checkBackendHealth sets nil when no healthAPIClient provided")
    func healthCheckNoClient() async {
        let vm = DevLoginViewModel(authService: MockDevAuthProvider())

        await vm.checkBackendHealth()

        #expect(vm.isBackendReachable == nil)
    }
}

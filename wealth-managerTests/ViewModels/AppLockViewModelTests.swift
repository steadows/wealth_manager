import Testing
import Foundation

@testable import wealth_manager

// MARK: - MockBiometricAuthService

final class MockBiometricAuthService: BiometricAuthServiceProtocol, @unchecked Sendable {
    var biometryType: BiometryType = .faceID
    var isBiometricAvailable: Bool = true
    var authResultToReturn: Bool = true
    var shouldThrow: Error?
    var authenticateCallCount = 0
    var lastAuthReason: String?

    func authenticate(reason: String) async throws -> Bool {
        authenticateCallCount += 1
        lastAuthReason = reason
        if let error = shouldThrow { throw error }
        return authResultToReturn
    }
}

// MARK: - AppLockViewModelTests

@Suite("AppLockViewModel")
struct AppLockViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(
        biometricService: MockBiometricAuthService = MockBiometricAuthService(),
        isBiometricEnabled: Bool = true
    ) -> (AppLockViewModel, MockBiometricAuthService) {
        let vm = AppLockViewModel(
            biometricService: biometricService,
            isBiometricEnabled: isBiometricEnabled
        )
        return (vm, biometricService)
    }

    // MARK: - Initial State

    @Test("initialState: isLocked when biometrics enabled")
    func initialState_isLocked_whenBiometricsEnabled() {
        let (vm, _) = makeViewModel(isBiometricEnabled: true)

        #expect(vm.isLocked == true)
        #expect(vm.error == nil)
        #expect(vm.isAuthenticating == false)
    }

    @Test("initialState: isUnlocked when biometrics disabled")
    func initialState_isUnlocked_whenBiometricsDisabled() {
        let (vm, _) = makeViewModel(isBiometricEnabled: false)

        #expect(vm.isLocked == false)
        #expect(vm.error == nil)
        #expect(vm.isAuthenticating == false)
    }

    // MARK: - authenticate

    @Test("authenticate: success unlocks app")
    func authenticate_success_unlocksApp() async {
        let mockService = MockBiometricAuthService()
        mockService.authResultToReturn = true
        let (vm, _) = makeViewModel(biometricService: mockService)

        await vm.authenticate()

        #expect(vm.isLocked == false)
        #expect(vm.error == nil)
        #expect(mockService.authenticateCallCount == 1)
    }

    @Test("authenticate: failure stays locked and sets error")
    func authenticate_failure_staysLocked_setsError() async {
        let mockService = MockBiometricAuthService()
        mockService.authResultToReturn = false
        let (vm, _) = makeViewModel(biometricService: mockService)

        await vm.authenticate()

        #expect(vm.isLocked == true)
        #expect(vm.error != nil)
    }

    @Test("authenticate: biometricUnavailable sets error")
    func authenticate_biometricUnavailable_setsError() async {
        let mockService = MockBiometricAuthService()
        mockService.biometryType = .none
        mockService.isBiometricAvailable = false
        let (vm, _) = makeViewModel(biometricService: mockService)

        await vm.authenticate()

        #expect(vm.error != nil)
        #expect(vm.isLocked == true)
        #expect(mockService.authenticateCallCount == 0)
    }

    @Test("authenticate: thrown error stays locked and sets error message")
    func authenticate_thrownError_staysLocked_setsError() async {
        let mockService = MockBiometricAuthService()
        mockService.shouldThrow = APIError.unauthorized
        let (vm, _) = makeViewModel(biometricService: mockService)

        await vm.authenticate()

        #expect(vm.isLocked == true)
        #expect(vm.error != nil)
    }

    @Test("authenticate: sets isAuthenticating during call")
    func authenticate_setsIsAuthenticating_duringCall() async {
        // Use an actor-based service to capture mid-flight state
        final class SlowMockBiometricAuthService: BiometricAuthServiceProtocol, @unchecked Sendable {
            var biometryType: BiometryType = .faceID
            var isBiometricAvailable: Bool = true
            var capturedIsAuthenticating: Bool = false
            weak var vm: AppLockViewModel?

            func authenticate(reason: String) async throws -> Bool {
                capturedIsAuthenticating = vm?.isAuthenticating ?? false
                return true
            }
        }

        let slowService = SlowMockBiometricAuthService()
        let vm = AppLockViewModel(biometricService: slowService, isBiometricEnabled: true)
        slowService.vm = vm

        await vm.authenticate()

        #expect(slowService.capturedIsAuthenticating == true)
        #expect(vm.isAuthenticating == false)
    }

    @Test("authenticate: clears previous error on success")
    func authenticate_clearsError_onSuccess() async {
        let mockService = MockBiometricAuthService()
        // First call fails
        mockService.authResultToReturn = false
        let (vm, _) = makeViewModel(biometricService: mockService)
        await vm.authenticate()
        #expect(vm.error != nil)

        // Second call succeeds
        mockService.authResultToReturn = true
        mockService.shouldThrow = nil
        await vm.authenticate()

        #expect(vm.error == nil)
        #expect(vm.isLocked == false)
    }

    // MARK: - lockApp

    @Test("lockApp: sets isLocked to true")
    func lockApp_setsLockedTrue() async {
        let mockService = MockBiometricAuthService()
        mockService.authResultToReturn = true
        let (vm, _) = makeViewModel(biometricService: mockService)

        // Unlock first
        await vm.authenticate()
        #expect(vm.isLocked == false)

        // Re-lock
        vm.lockApp()

        #expect(vm.isLocked == true)
    }

    @Test("lockApp: clears any existing error")
    func lockApp_clearsError() async {
        let mockService = MockBiometricAuthService()
        mockService.authResultToReturn = false
        let (vm, _) = makeViewModel(biometricService: mockService)

        // Trigger an error state
        await vm.authenticate()
        #expect(vm.error != nil)

        vm.lockApp()

        #expect(vm.isLocked == true)
        #expect(vm.error == nil)
    }
}

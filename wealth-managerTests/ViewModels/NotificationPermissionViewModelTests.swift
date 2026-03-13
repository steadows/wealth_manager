import Testing
import Foundation

@testable import wealth_manager

// MARK: - Mock Notification Service

final class MockNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    var stubbedStatus: NotificationPermissionStatus = .notDetermined
    var stubbedRequestResult: NotificationPermissionStatus = .authorized
    var shouldThrow: Error?

    /// Tracks whether requestPermission was called.
    var requestPermissionCallCount: Int = 0

    func currentPermissionStatus() async -> NotificationPermissionStatus {
        stubbedStatus
    }

    func requestPermission() async throws -> NotificationPermissionStatus {
        requestPermissionCallCount += 1
        if let error = shouldThrow { throw error }
        return stubbedRequestResult
    }
}

// MARK: - NotificationPermissionViewModel Tests

@Suite("NotificationPermissionViewModel")
struct NotificationPermissionViewModelTests {

    // MARK: Initial state

    @Test("initial permissionStatus is notDetermined")
    func initialState_statusNotDetermined() {
        let mock = MockNotificationService()
        let vm = NotificationPermissionViewModel(service: mock)
        #expect(vm.permissionStatus == .notDetermined)
    }

    @Test("initial isRequestingPermission is false")
    func initialState_isRequestingFalse() {
        let mock = MockNotificationService()
        let vm = NotificationPermissionViewModel(service: mock)
        #expect(vm.isRequestingPermission == false)
    }

    @Test("initial error is nil")
    func initialState_errorNil() {
        let mock = MockNotificationService()
        let vm = NotificationPermissionViewModel(service: mock)
        #expect(vm.error == nil)
    }

    // MARK: checkCurrentStatus

    @Test("checkCurrentStatus updates permissionStatus from service")
    func checkStatus_updatesPermissionStatus() async {
        let mock = MockNotificationService()
        mock.stubbedStatus = .authorized
        let vm = NotificationPermissionViewModel(service: mock)

        await vm.checkCurrentStatus()

        #expect(vm.permissionStatus == .authorized)
    }

    @Test("checkCurrentStatus reflects denied status")
    func checkStatus_deniedStatus() async {
        let mock = MockNotificationService()
        mock.stubbedStatus = .denied
        let vm = NotificationPermissionViewModel(service: mock)

        await vm.checkCurrentStatus()

        #expect(vm.permissionStatus == .denied)
    }

    // MARK: requestPermission — happy path

    @Test("requestPermission authorized updates status to authorized")
    func requestPermission_authorized_updatesStatus() async {
        let mock = MockNotificationService()
        mock.stubbedRequestResult = .authorized
        let vm = NotificationPermissionViewModel(service: mock)

        await vm.requestPermission()

        #expect(vm.permissionStatus == .authorized)
        #expect(vm.error == nil)
    }

    @Test("requestPermission denied updates status to denied")
    func requestPermission_denied_updatesStatus() async {
        let mock = MockNotificationService()
        mock.stubbedRequestResult = .denied
        let vm = NotificationPermissionViewModel(service: mock)

        await vm.requestPermission()

        #expect(vm.permissionStatus == .denied)
    }

    // MARK: requestPermission — loading state

    @Test("isRequestingPermission is false after requestPermission completes")
    func requestPermission_setsIsRequesting_duringCall() async {
        let mock = MockNotificationService()
        let vm = NotificationPermissionViewModel(service: mock)

        await vm.requestPermission()

        // After the call completes, isRequestingPermission must be reset to false
        #expect(vm.isRequestingPermission == false)
    }

    // MARK: requestPermission — error path

    @Test("requestPermission stores error message on throw")
    func requestPermission_error_setsErrorMessage() async {
        struct FakeError: Error, LocalizedError {
            var errorDescription: String? { "Permission request failed" }
        }
        let mock = MockNotificationService()
        mock.shouldThrow = FakeError()
        let vm = NotificationPermissionViewModel(service: mock)

        await vm.requestPermission()

        #expect(vm.error != nil)
        #expect(vm.isRequestingPermission == false)
    }

    // MARK: shouldShowPermissionPrompt

    @Test("shouldShowPermissionPrompt is true when notDetermined")
    func shouldShowPrompt_trueWhenNotDetermined() {
        let mock = MockNotificationService()
        mock.stubbedStatus = .notDetermined
        let vm = NotificationPermissionViewModel(service: mock)
        // Initial state is notDetermined
        #expect(vm.shouldShowPermissionPrompt == true)
    }

    @Test("shouldShowPermissionPrompt is false when authorized")
    func shouldShowPrompt_falseWhenAuthorized() async {
        let mock = MockNotificationService()
        mock.stubbedStatus = .authorized
        let vm = NotificationPermissionViewModel(service: mock)

        await vm.checkCurrentStatus()

        #expect(vm.shouldShowPermissionPrompt == false)
    }

    @Test("shouldShowPermissionPrompt is false when denied")
    func shouldShowPrompt_falseWhenDenied() async {
        let mock = MockNotificationService()
        mock.stubbedStatus = .denied
        let vm = NotificationPermissionViewModel(service: mock)

        await vm.checkCurrentStatus()

        #expect(vm.shouldShowPermissionPrompt == false)
    }
}

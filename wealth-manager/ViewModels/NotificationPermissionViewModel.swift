import Foundation
import Observation

// MARK: - NotificationPermissionViewModel

/// Manages the notification permission request flow.
///
/// Inject a `NotificationServiceProtocol` for full testability.
@Observable
final class NotificationPermissionViewModel {

    // MARK: Published state

    /// Current notification authorisation status.
    private(set) var permissionStatus: NotificationPermissionStatus = .notDetermined

    /// `true` while a permission request is in-flight.
    private(set) var isRequestingPermission: Bool = false

    /// Non-nil when `requestPermission()` throws.
    private(set) var error: String?

    // MARK: Computed

    /// `true` only when the user has not yet been asked — drives permission prompt UI.
    var shouldShowPermissionPrompt: Bool {
        permissionStatus == .notDetermined
    }

    // MARK: Dependencies

    private let service: NotificationServiceProtocol

    // MARK: Init

    /// - Parameter service: Defaults to the production `NotificationService`.
    init(service: NotificationServiceProtocol = NotificationService()) {
        self.service = service
    }

    // MARK: Actions

    /// Reads the current permission status from the service and updates `permissionStatus`.
    func checkCurrentStatus() async {
        permissionStatus = await service.currentPermissionStatus()
    }

    /// Requests notification permission from the user.
    ///
    /// Sets `isRequestingPermission` to `true` during the request and resets it
    /// afterwards, regardless of success or failure.
    func requestPermission() async {
        isRequestingPermission = true
        error = nil
        defer { isRequestingPermission = false }

        do {
            permissionStatus = try await service.requestPermission()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

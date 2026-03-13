import Foundation
import UserNotifications

// MARK: - NotificationService

/// Production implementation that wraps `UNUserNotificationCenter`.
///
/// Not used in unit tests — inject `NotificationServiceProtocol` and use a mock.
final class NotificationService: NotificationServiceProtocol {

    private let center: UNUserNotificationCenter

    /// - Parameter center: Defaults to `.current()`. Injectable for testing at the
    ///   integration level if needed.
    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// Returns the current authorisation status without showing a prompt.
    func currentPermissionStatus() async -> NotificationPermissionStatus {
        let settings = await center.notificationSettings()
        return map(settings.authorizationStatus)
    }

    /// Requests `.alert`, `.sound`, and `.badge` permissions.
    func requestPermission() async throws -> NotificationPermissionStatus {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        // After the request, read the authoritative settings object.
        let settings = await center.notificationSettings()
        _ = granted // requestAuthorization result is a Bool; settings is more precise.
        return map(settings.authorizationStatus)
    }

    // MARK: Private

    private func map(_ status: UNAuthorizationStatus) -> NotificationPermissionStatus {
        switch status {
        case .notDetermined:         return .notDetermined
        case .authorized, .ephemeral: return .authorized
        case .denied:                return .denied
        case .provisional:           return .provisional
        @unknown default:            return .notDetermined
        }
    }
}

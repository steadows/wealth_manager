import Foundation

// MARK: - Permission Status

/// Mirrors UNAuthorizationStatus without importing UserNotifications in tests.
enum NotificationPermissionStatus: Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case provisional
}

// MARK: - Protocol

/// Abstraction over UNUserNotificationCenter for testability.
protocol NotificationServiceProtocol: Sendable {
    /// Returns the current notification permission status without prompting the user.
    func currentPermissionStatus() async -> NotificationPermissionStatus

    /// Requests notification permission from the user.
    /// - Returns: The resulting permission status.
    /// - Throws: Any error produced by the underlying framework.
    func requestPermission() async throws -> NotificationPermissionStatus
}

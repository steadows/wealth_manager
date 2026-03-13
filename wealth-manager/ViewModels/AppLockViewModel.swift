import Foundation
import Observation

// MARK: - AppLockViewModel

/// Manages the app lock/unlock lifecycle using biometric authentication.
/// When `isBiometricEnabled` is true, the app starts locked and requires
/// a successful biometric challenge before content is shown.
@Observable
final class AppLockViewModel {

    // MARK: - Published State

    /// Whether the app is currently locked and showing the lock screen.
    private(set) var isLocked: Bool

    /// A user-facing error message from the last failed authentication attempt.
    private(set) var error: String?

    /// `true` while a biometric authentication challenge is in flight.
    private(set) var isAuthenticating: Bool = false

    // MARK: - Dependencies

    private let biometricService: BiometricAuthServiceProtocol
    private let isBiometricEnabled: Bool

    // MARK: - Init

    /// - Parameters:
    ///   - biometricService: Abstraction over `LAContext` for testability.
    ///   - isBiometricEnabled: Whether the user has opted in to biometric lock.
    init(biometricService: BiometricAuthServiceProtocol, isBiometricEnabled: Bool) {
        self.biometricService = biometricService
        self.isBiometricEnabled = isBiometricEnabled
        self.isLocked = isBiometricEnabled
    }

    // MARK: - Actions

    /// Initiates a biometric authentication challenge.
    /// On success the app is unlocked; on failure `error` is populated.
    func authenticate() async {
        guard isBiometricEnabled else { return }

        guard biometricService.isBiometricAvailable else {
            error = biometricService.biometryType == .none
                ? "Biometric authentication is not available on this device."
                : "Biometric authentication is not configured."
            return
        }

        isAuthenticating = true
        error = nil

        do {
            let success = try await biometricService.authenticate(
                reason: "Unlock Wealth Manager"
            )
            isAuthenticating = false
            if success {
                isLocked = false
            } else {
                error = "Authentication failed. Please try again."
            }
        } catch {
            isAuthenticating = false
            self.error = error.localizedDescription
        }
    }

    /// Locks the app, clearing any previous error state.
    func lockApp() {
        isLocked = true
        error = nil
    }
}

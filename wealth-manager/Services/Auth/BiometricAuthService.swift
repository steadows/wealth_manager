import Foundation
import LocalAuthentication

// MARK: - BiometricAuthService

/// Production biometric authentication service backed by `LAContext`.
final class BiometricAuthService: BiometricAuthServiceProtocol, @unchecked Sendable {

    // MARK: - BiometricAuthServiceProtocol

    var biometryType: BiometryType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }

    var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Presents the system biometric prompt and returns the result.
    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }
}

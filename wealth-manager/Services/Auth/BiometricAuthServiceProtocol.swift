import Foundation

// MARK: - BiometryType

/// The type of biometric authentication available on the device.
enum BiometryType: Sendable {
    case faceID
    case touchID
    case none
}

// MARK: - BiometricAuthServiceProtocol

/// Abstracts biometric authentication so ViewModels remain testable.
protocol BiometricAuthServiceProtocol: Sendable {
    /// The biometry type available on the current device.
    var biometryType: BiometryType { get }

    /// Whether biometric authentication is currently available and enrolled.
    var isBiometricAvailable: Bool { get }

    /// Performs a biometric authentication challenge.
    /// - Parameter reason: A user-facing string explaining why authentication is needed.
    /// - Returns: `true` if the user authenticated successfully.
    /// - Throws: An error if authentication could not be attempted (e.g., biometry locked out).
    func authenticate(reason: String) async throws -> Bool
}

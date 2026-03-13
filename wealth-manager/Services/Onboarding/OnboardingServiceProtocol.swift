import Foundation

/// Contract for persisting onboarding completion state.
protocol OnboardingServiceProtocol: Sendable {
    /// Whether the user has completed onboarding.
    var hasCompletedOnboarding: Bool { get }

    /// Marks onboarding as complete in persistent storage.
    func markOnboardingComplete()

    /// Resets onboarding state (used for testing or re-onboarding).
    func resetOnboarding()
}

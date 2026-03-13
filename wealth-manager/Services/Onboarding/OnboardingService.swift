import Foundation

/// UserDefaults-backed implementation of OnboardingServiceProtocol.
final class OnboardingService: OnboardingServiceProtocol, @unchecked Sendable {

    // MARK: - Constants

    private enum Keys {
        static let hasCompletedOnboarding = "wealth_manager.onboarding.completed"
    }

    // MARK: - Dependencies

    private let defaults: UserDefaults

    // MARK: - Init

    /// Creates a service backed by the given UserDefaults instance.
    /// - Parameter defaults: Defaults store. Defaults to `.standard`.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - OnboardingServiceProtocol

    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }

    func markOnboardingComplete() {
        defaults.set(true, forKey: Keys.hasCompletedOnboarding)
    }

    func resetOnboarding() {
        defaults.removeObject(forKey: Keys.hasCompletedOnboarding)
    }
}

import Foundation

/// Represents each step in the onboarding wizard.
enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome = 0
    case profile = 1
    case linkAccount = 2
    case setGoal = 3
    case complete = 4
}

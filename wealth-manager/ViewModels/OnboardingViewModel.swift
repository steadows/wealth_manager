import Foundation
import Observation

/// Manages state and navigation logic for the multi-step onboarding wizard.
@Observable
final class OnboardingViewModel {

    // MARK: - State

    /// The currently displayed step.
    private(set) var currentStep: OnboardingStep = .welcome

    /// User-entered name for the profile step.
    var profileName: String = ""

    /// User-entered age for the profile step.
    var profileAge: Int?

    /// User-entered annual income for the profile step (optional).
    var profileIncome: Decimal?

    /// Whether the wizard has been fully completed.
    private(set) var isComplete: Bool = false

    /// Validation or navigation error message, cleared on successful advance.
    var error: String?

    // MARK: - Computed

    /// True when the current step's validation requirements are satisfied.
    var canAdvance: Bool {
        switch currentStep {
        case .profile:
            return !profileName.trimmingCharacters(in: .whitespaces).isEmpty && profileAge != nil
        default:
            return true
        }
    }

    /// Fraction of onboarding completed (0.0 – 1.0).
    /// Uses the raw step index divided by the number of steps before `complete`.
    var progressFraction: Double {
        let total = Double(OnboardingStep.allCases.count - 1)
        return Double(currentStep.rawValue) / total
    }

    // MARK: - Dependencies

    private let service: any OnboardingServiceProtocol

    // MARK: - Init

    /// Creates a ViewModel backed by the given onboarding service.
    init(service: any OnboardingServiceProtocol) {
        self.service = service
    }

    // MARK: - Navigation

    /// Validates the current step and advances to the next step if valid.
    /// Sets `error` and stays on the current step when validation fails.
    func nextStep() {
        guard currentStep != .complete else { return }

        guard canAdvance else {
            error = validationMessage(for: currentStep)
            return
        }

        error = nil
        advance()
    }

    /// Advances to the next step without performing validation.
    func skipStep() {
        guard currentStep != .complete else { return }
        error = nil
        advance()
    }

    /// Goes back to the previous step, clearing any pending error.
    func previousStep() {
        guard currentStep != .welcome else { return }
        error = nil
        let previousRaw = currentStep.rawValue - 1
        if let previous = OnboardingStep(rawValue: previousRaw) {
            currentStep = previous
        }
    }

    /// Marks onboarding complete via the service and sets `isComplete`.
    func completeOnboarding() {
        service.markOnboardingComplete()
        isComplete = true
    }

    // MARK: - Private Helpers

    private func advance() {
        let nextRaw = currentStep.rawValue + 1
        if let next = OnboardingStep(rawValue: nextRaw) {
            currentStep = next
        }
    }

    private func validationMessage(for step: OnboardingStep) -> String {
        switch step {
        case .profile:
            if profileName.trimmingCharacters(in: .whitespaces).isEmpty {
                return "Please enter your name."
            }
            if profileAge == nil {
                return "Please enter your age."
            }
            return "Please complete all required fields."
        default:
            return "Please complete this step before continuing."
        }
    }
}

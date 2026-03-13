import Testing
import Foundation

@testable import wealth_manager

// MARK: - MockOnboardingService

final class MockOnboardingService: OnboardingServiceProtocol, @unchecked Sendable {
    var hasCompletedOnboarding: Bool = false
    var markOnboardingCompleteCallCount = 0
    var resetOnboardingCallCount = 0

    func markOnboardingComplete() {
        markOnboardingCompleteCallCount += 1
        hasCompletedOnboarding = true
    }

    func resetOnboarding() {
        resetOnboardingCallCount += 1
        hasCompletedOnboarding = false
    }
}

// MARK: - OnboardingViewModelTests

@Suite("OnboardingViewModel")
struct OnboardingViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(
        service: MockOnboardingService = MockOnboardingService()
    ) -> (OnboardingViewModel, MockOnboardingService) {
        let vm = OnboardingViewModel(service: service)
        return (vm, service)
    }

    // MARK: - Initial State

    @Test("initialStep_isWelcome")
    func initialStep_isWelcome() {
        let (vm, _) = makeViewModel()
        #expect(vm.currentStep == .welcome)
    }

    @Test("initial state: isComplete is false")
    func initialState_isComplete_false() {
        let (vm, _) = makeViewModel()
        #expect(vm.isComplete == false)
    }

    @Test("initial state: error is nil")
    func initialState_error_isNil() {
        let (vm, _) = makeViewModel()
        #expect(vm.error == nil)
    }

    @Test("initial state: profileName is empty")
    func initialState_profileName_isEmpty() {
        let (vm, _) = makeViewModel()
        #expect(vm.profileName.isEmpty)
    }

    @Test("initial state: profileAge is nil")
    func initialState_profileAge_isNil() {
        let (vm, _) = makeViewModel()
        #expect(vm.profileAge == nil)
    }

    @Test("initial state: profileIncome is nil")
    func initialState_profileIncome_isNil() {
        let (vm, _) = makeViewModel()
        #expect(vm.profileIncome == nil)
    }

    // MARK: - nextStep

    @Test("nextStep_advancesFromWelcomeToProfile")
    func nextStep_advancesFromWelcomeToProfile() {
        let (vm, _) = makeViewModel()
        #expect(vm.currentStep == .welcome)

        vm.nextStep()

        #expect(vm.currentStep == .profile)
    }

    @Test("nextStep_fromProfile_requiresNameAndAge")
    func nextStep_fromProfile_requiresNameAndAge() {
        let (vm, _) = makeViewModel()
        vm.nextStep() // advance to profile
        #expect(vm.currentStep == .profile)

        // Attempt next without name or age
        vm.nextStep()

        #expect(vm.currentStep == .profile)
        #expect(vm.error != nil)
    }

    @Test("nextStep_fromProfile_withNameOnly_doesNotAdvance")
    func nextStep_fromProfile_withNameOnly_doesNotAdvance() {
        let (vm, _) = makeViewModel()
        vm.nextStep() // advance to profile
        vm.profileName = "Alice"

        vm.nextStep()

        #expect(vm.currentStep == .profile)
        #expect(vm.error != nil)
    }

    @Test("nextStep_fromProfile_withValidData_advances")
    func nextStep_fromProfile_withValidData_advances() {
        let (vm, _) = makeViewModel()
        vm.nextStep() // advance to profile
        vm.profileName = "Alice"
        vm.profileAge = 30

        vm.nextStep()

        #expect(vm.currentStep == .linkAccount)
        #expect(vm.error == nil)
    }

    @Test("nextStep_fromSetGoal_advancesToComplete")
    func nextStep_fromSetGoal_advancesToComplete() {
        let (vm, _) = makeViewModel()
        // Navigate to setGoal step
        vm.nextStep() // welcome -> profile
        vm.profileName = "Alice"
        vm.profileAge = 30
        vm.nextStep() // profile -> linkAccount
        vm.nextStep() // linkAccount -> setGoal
        #expect(vm.currentStep == .setGoal)

        vm.nextStep() // setGoal -> complete

        #expect(vm.currentStep == .complete)
    }

    @Test("nextStep_atComplete_doesNotAdvanceBeyond")
    func nextStep_atComplete_doesNotAdvanceBeyond() {
        let (vm, _) = makeViewModel()
        // Navigate to complete
        vm.nextStep()
        vm.profileName = "Alice"
        vm.profileAge = 30
        vm.nextStep()
        vm.nextStep()
        vm.nextStep()
        #expect(vm.currentStep == .complete)

        vm.nextStep()

        #expect(vm.currentStep == .complete)
    }

    // MARK: - skipStep

    @Test("skipStep_advancesWithoutValidation")
    func skipStep_advancesWithoutValidation() {
        let (vm, _) = makeViewModel()
        vm.nextStep() // welcome -> profile
        #expect(vm.currentStep == .profile)

        // Skip profile without providing name or age
        vm.skipStep()

        #expect(vm.currentStep == .linkAccount)
        #expect(vm.error == nil)
    }

    @Test("skipStep_onLinkAccount_advances")
    func skipStep_onLinkAccount_advances() {
        let (vm, _) = makeViewModel()
        vm.nextStep() // welcome -> profile
        vm.profileName = "Alice"
        vm.profileAge = 30
        vm.nextStep() // profile -> linkAccount
        #expect(vm.currentStep == .linkAccount)

        vm.skipStep()

        #expect(vm.currentStep == .setGoal)
    }

    @Test("skipStep_atComplete_staysAtComplete")
    func skipStep_atComplete_staysAtComplete() {
        let (vm, _) = makeViewModel()
        vm.nextStep()
        vm.profileName = "Alice"
        vm.profileAge = 30
        vm.nextStep()
        vm.nextStep()
        vm.nextStep()
        #expect(vm.currentStep == .complete)

        vm.skipStep()

        #expect(vm.currentStep == .complete)
    }

    // MARK: - previousStep

    @Test("previousStep_goesBack")
    func previousStep_goesBack() {
        let (vm, _) = makeViewModel()
        vm.nextStep() // welcome -> profile
        #expect(vm.currentStep == .profile)

        vm.previousStep()

        #expect(vm.currentStep == .welcome)
    }

    @Test("previousStep_atWelcome_staysAtWelcome")
    func previousStep_atWelcome_staysAtWelcome() {
        let (vm, _) = makeViewModel()
        #expect(vm.currentStep == .welcome)

        vm.previousStep()

        #expect(vm.currentStep == .welcome)
    }

    @Test("previousStep_clearsError")
    func previousStep_clearsError() {
        let (vm, _) = makeViewModel()
        vm.nextStep() // welcome -> profile
        vm.nextStep() // attempt without data — sets error
        #expect(vm.error != nil)

        vm.previousStep()

        #expect(vm.error == nil)
    }

    // MARK: - completeOnboarding

    @Test("completeOnboarding_callsService")
    func completeOnboarding_callsService() {
        let service = MockOnboardingService()
        let (vm, _) = makeViewModel(service: service)

        vm.completeOnboarding()

        #expect(service.markOnboardingCompleteCallCount == 1)
    }

    @Test("completeOnboarding_setsIsComplete")
    func completeOnboarding_setsIsComplete() {
        let (vm, _) = makeViewModel()

        vm.completeOnboarding()

        #expect(vm.isComplete == true)
    }

    // MARK: - progressFraction

    @Test("progressFraction_calculatedCorrectly")
    func progressFraction_calculatedCorrectly() {
        let (vm, _) = makeViewModel()
        let total = Double(OnboardingStep.allCases.count - 1) // exclude complete from divisor

        // welcome (step 0)
        #expect(vm.progressFraction == 0.0 / total)

        vm.nextStep() // -> profile
        #expect(vm.progressFraction == 1.0 / total)

        vm.profileName = "Alice"
        vm.profileAge = 30
        vm.nextStep() // -> linkAccount
        #expect(vm.progressFraction == 2.0 / total)

        vm.nextStep() // -> setGoal
        #expect(vm.progressFraction == 3.0 / total)

        vm.nextStep() // -> complete
        #expect(vm.progressFraction == 4.0 / total)
    }

    // MARK: - canAdvance

    @Test("canAdvance_trueForNonProfileSteps")
    func canAdvance_trueForNonProfileSteps() {
        let (vm, _) = makeViewModel()

        // welcome
        #expect(vm.currentStep == .welcome)
        #expect(vm.canAdvance == true)

        vm.nextStep() // -> profile (canAdvance false without data)
        vm.profileName = "Alice"
        vm.profileAge = 30
        vm.nextStep() // -> linkAccount

        #expect(vm.currentStep == .linkAccount)
        #expect(vm.canAdvance == true)

        vm.nextStep() // -> setGoal
        #expect(vm.currentStep == .setGoal)
        #expect(vm.canAdvance == true)
    }

    @Test("canAdvance_falseForProfile_whenNameAndAgeEmpty")
    func canAdvance_falseForProfile_whenNameAndAgeEmpty() {
        let (vm, _) = makeViewModel()
        vm.nextStep() // -> profile

        #expect(vm.currentStep == .profile)
        #expect(vm.canAdvance == false)
    }

    @Test("canAdvance_trueForProfile_whenNameAndAgeProvided")
    func canAdvance_trueForProfile_whenNameAndAgeProvided() {
        let (vm, _) = makeViewModel()
        vm.nextStep() // -> profile
        vm.profileName = "Alice"
        vm.profileAge = 25

        #expect(vm.canAdvance == true)
    }
}

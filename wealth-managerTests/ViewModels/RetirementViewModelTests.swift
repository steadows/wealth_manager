import Testing
import Foundation

@testable import wealth_manager

// MARK: - RetirementViewModelTests

@Suite("RetirementViewModel")
struct RetirementViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(
        accounts: [Account] = [],
        profile: UserProfile? = nil
    ) -> RetirementViewModel {
        let accountRepo = MockAccountRepository()
        accountRepo.items = accounts
        let profileRepo = MockUserProfileRepository()
        profileRepo.profile = profile

        return RetirementViewModel(
            accountRepo: accountRepo,
            profileRepo: profileRepo
        )
    }

    /// Creates a profile for an age-45 person with income $150k and expenses $5k/month.
    private func makeProfile45() -> UserProfile {
        let dob = Calendar.current.date(byAdding: .year, value: -45, to: Date())!
        return UserProfile(
            dateOfBirth: dob,
            annualIncome: 150_000,
            monthlyExpenses: 5_000,
            riskTolerance: .moderate
        )
    }

    /// Creates a profile for an age-55 person (catch-up eligible).
    private func makeProfile55() -> UserProfile {
        let dob = Calendar.current.date(byAdding: .year, value: -55, to: Date())!
        return UserProfile(
            dateOfBirth: dob,
            annualIncome: 200_000,
            monthlyExpenses: 7_000,
            riskTolerance: .moderate
        )
    }

    private func makeSampleAccounts() -> [Account] {
        [
            Account(
                institutionName: "Vanguard",
                accountName: "401k",
                accountType: .retirement,
                currentBalance: 250_000,
                isManual: true
            ),
            Account(
                institutionName: "Chase",
                accountName: "Checking",
                accountType: .checking,
                currentBalance: 50_000,
                isManual: true
            ),
        ]
    }

    // MARK: - Initial State

    @Test("initial state: isLoading is false")
    func initialStateIsLoadingFalse() {
        let vm = makeViewModel()
        #expect(!vm.isLoading)
    }

    @Test("initial state: error is nil")
    func initialStateErrorNil() {
        let vm = makeViewModel()
        #expect(vm.error == nil)
    }

    @Test("initial state: readinessScore is 0")
    func initialStateReadinessScoreZero() {
        let vm = makeViewModel()
        #expect(vm.readinessScore == 0)
    }

    // MARK: - loadRetirementData with profile

    @Test("loadRetirementData: sets readinessScore in 0-100 range")
    func loadSetsReadinessScoreInRange() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile45()
        )
        await vm.loadRetirementData()
        #expect(vm.readinessScore >= 0)
        #expect(vm.readinessScore <= 100)
    }

    @Test("loadRetirementData: sets fireNumber > 0")
    func loadSetsFireNumber() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile45()
        )
        await vm.loadRetirementData()
        #expect(vm.fireNumber > 0)
    }

    @Test("loadRetirementData: age-45 profile sets contribution limits without catch-up")
    func loadSetsContributionLimitsNoCatchUp() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile45()
        )
        await vm.loadRetirementData()
        let limits = vm.contributionLimits
        #expect(limits != nil)
        if let limits {
            #expect(limits.traditional401k == 23_500)
            #expect(limits.catchUp401k == 0)
            #expect(limits.ira == 7_000)
            #expect(limits.catchUpIra == 0)
        }
    }

    @Test("loadRetirementData: age-55 profile sets contribution limits with catch-up")
    func loadSetsContributionLimitsWithCatchUp() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile55()
        )
        await vm.loadRetirementData()
        let limits = vm.contributionLimits
        #expect(limits != nil)
        if let limits {
            #expect(limits.traditional401k == 23_500)
            #expect(limits.catchUp401k == 7_500)
            #expect(limits.ira == 7_000)
            #expect(limits.catchUpIra == 1_000)
        }
    }

    @Test("loadRetirementData: socialSecurityEstimates contains entries for ages 62-70")
    func loadSetsSocialSecurityEstimates() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile45()
        )
        await vm.loadRetirementData()
        for age in 62...70 {
            #expect(vm.socialSecurityEstimates[age] != nil,
                    "Missing SS estimate for age \(age)")
        }
    }

    @Test("loadRetirementData: SS benefit at 70 > benefit at 67 > benefit at 62")
    func socialSecurityBenefitsIncreaseWithAge() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile45()
        )
        await vm.loadRetirementData()
        let benefit62 = vm.socialSecurityEstimates[62] ?? 0
        let benefit67 = vm.socialSecurityEstimates[67] ?? 0
        let benefit70 = vm.socialSecurityEstimates[70] ?? 0
        #expect(benefit62 < benefit67)
        #expect(benefit67 < benefit70)
    }

    // MARK: - Empty State

    @Test("loadRetirementData: no profile uses graceful defaults")
    func loadNoProfileUsesDefaults() async {
        let vm = makeViewModel(accounts: makeSampleAccounts())
        await vm.loadRetirementData()
        // Should not crash; fireNumber should be > 0 (uses default expenses)
        #expect(vm.fireNumber >= 0)
        #expect(vm.readinessScore >= 0)
        #expect(vm.readinessScore <= 100)
        #expect(vm.error == nil)
    }

    @Test("loadRetirementData: no accounts still completes successfully")
    func loadNoAccountsCompletes() async {
        let vm = makeViewModel(profile: makeProfile45())
        await vm.loadRetirementData()
        #expect(vm.error == nil)
        #expect(vm.fireNumber > 0)
    }

    // MARK: - isLoading

    @Test("loadRetirementData: isLoading is false after completion")
    func isLoadingFalseAfterCompletion() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile45()
        )
        #expect(!vm.isLoading)
        await vm.loadRetirementData()
        #expect(!vm.isLoading)
    }

    // MARK: - yearsToFIRE

    @Test("loadRetirementData: yearsToFIRE is nil or non-negative")
    func yearsToFIREIsNilOrNonNegative() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile45()
        )
        await vm.loadRetirementData()
        if let years = vm.yearsToFIRE {
            #expect(years >= 0)
        }
    }

    // MARK: - retirementAge

    @Test("loadRetirementData: retirementAge matches profile")
    func retirementAgeMatchesProfile() async {
        let profile = makeProfile45()
        profile.retirementAge = 62
        let vm = makeViewModel(accounts: makeSampleAccounts(), profile: profile)
        await vm.loadRetirementData()
        #expect(vm.retirementAge == 62)
    }
}

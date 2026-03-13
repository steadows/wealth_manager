import Testing
import Foundation

@testable import wealth_manager

// MARK: - InsuranceViewModelTests

@Suite("InsuranceViewModel")
struct InsuranceViewModelTests {

    // MARK: - Helpers

    private func makeProfile(
        annualIncome: Decimal = 100_000,
        monthlyExpenses: Decimal = 5_000,
        dependents: Int = 2
    ) -> UserProfile {
        UserProfile(
            annualIncome: annualIncome,
            monthlyExpenses: monthlyExpenses,
            dependents: dependents
        )
    }

    private func makeSavingsAccount(balance: Decimal) -> Account {
        Account(
            institutionName: "Bank",
            accountName: "Savings",
            accountType: .savings,
            currentBalance: balance,
            isManual: true
        )
    }

    private func makeCheckingAccount(balance: Decimal) -> Account {
        Account(
            institutionName: "Bank",
            accountName: "Checking",
            accountType: .checking,
            currentBalance: balance,
            isManual: true
        )
    }

    private func makeViewModel(
        accounts: [Account] = [],
        profile: UserProfile? = nil
    ) -> InsuranceViewModel {
        let accountRepo = MockAccountRepository()
        accountRepo.items = accounts
        let profileRepo = MockUserProfileRepository()
        profileRepo.profile = profile
        return InsuranceViewModel(accountRepo: accountRepo, profileRepo: profileRepo)
    }

    // MARK: - Initial State

    @Test("initial state: isLoading is false")
    func initialStateIsLoading() {
        let vm = makeViewModel()
        #expect(!vm.isLoading)
    }

    @Test("initial state: all values are zero")
    func initialStateAllZero() {
        let vm = makeViewModel()
        #expect(vm.lifeInsuranceGap == 0)
        #expect(vm.lifeInsuranceTotalNeed == 0)
        #expect(vm.emergencyFundMonthsCovered == 0)
        #expect(vm.emergencyFundShortfall == 0)
        #expect(vm.disabilityCoverageGap == 0)
    }

    @Test("initial state: checklist has expected item count")
    func initialStateChecklistCount() {
        let vm = makeViewModel()
        // Estate planning checklist has 5 items
        #expect(vm.estatePlanningChecklist.count == 5)
    }

    // MARK: - loadInsuranceData

    @Test("loadInsuranceData: sets values from profile income $100k, expenses $5k/mo")
    func loadInsuranceDataSetsValues() async {
        let profile = makeProfile(annualIncome: 100_000, monthlyExpenses: 5_000, dependents: 2)
        let accounts = [makeSavingsAccount(balance: 15_000)]
        let vm = makeViewModel(accounts: accounts, profile: profile)

        await vm.loadInsuranceData()

        #expect(!vm.isLoading)
        #expect(vm.error == nil)
        // Life insurance need = dependents * 4 years of income + zero existing coverage
        // = 2 * 4 = 8 years of 100k = 800k total need, gap = 800k
        #expect(vm.lifeInsuranceTotalNeed > 0)
        #expect(vm.lifeInsuranceGap >= 0)
    }

    @Test("loadInsuranceData: emergencyFundMonthsCovered correct for given savings")
    func loadInsuranceDataEmergencyFund() async {
        // 15k savings / 5k/mo expenses = 3 months
        let profile = makeProfile(monthlyExpenses: 5_000)
        let accounts = [makeSavingsAccount(balance: 15_000)]
        let vm = makeViewModel(accounts: accounts, profile: profile)

        await vm.loadInsuranceData()

        #expect(vm.emergencyFundMonthsCovered == 3)
    }

    @Test("loadInsuranceData: emergency fund shortfall calculated correctly")
    func loadInsuranceDataEmergencyShortfall() async {
        // 6-month target: 30k; savings: 15k; shortfall: 15k
        let profile = makeProfile(monthlyExpenses: 5_000)
        let accounts = [makeSavingsAccount(balance: 15_000)]
        let vm = makeViewModel(accounts: accounts, profile: profile)

        await vm.loadInsuranceData()

        #expect(vm.emergencyFundShortfall == 15_000)
    }

    @Test("loadInsuranceData: uses both savings and checking for liquid savings")
    func loadInsuranceDataLiquidSavingsFromBothTypes() async {
        let profile = makeProfile(monthlyExpenses: 5_000)
        let accounts = [
            makeSavingsAccount(balance: 10_000),
            makeCheckingAccount(balance: 5_000),
        ]
        let vm = makeViewModel(accounts: accounts, profile: profile)

        await vm.loadInsuranceData()

        // 15k total liquid / 5k expenses = 3 months
        #expect(vm.emergencyFundMonthsCovered == 3)
    }

    @Test("loadInsuranceData: lifeInsuranceGap is non-negative")
    func loadInsuranceDataLifeInsuranceGapNonNegative() async {
        let profile = makeProfile(annualIncome: 100_000, dependents: 3)
        let vm = makeViewModel(profile: profile)

        await vm.loadInsuranceData()

        #expect(vm.lifeInsuranceGap >= 0)
    }

    @Test("loadInsuranceData: disability coverage gap computed from income")
    func loadInsuranceDataDisabilityGap() async {
        // 65% of 100k = 65k recommended; 0 existing = 65k gap
        let profile = makeProfile(annualIncome: 100_000)
        let vm = makeViewModel(profile: profile)

        await vm.loadInsuranceData()

        #expect(vm.disabilityCoverageGap == 65_000)
    }

    @Test("loadInsuranceData: no profile yields graceful zero values")
    func loadInsuranceDataNoProfile() async {
        let vm = makeViewModel(accounts: [], profile: nil)

        await vm.loadInsuranceData()

        #expect(vm.lifeInsuranceTotalNeed == 0)
        #expect(vm.lifeInsuranceGap == 0)
        #expect(vm.emergencyFundMonthsCovered == 0)
        #expect(vm.disabilityCoverageGap == 0)
        #expect(!vm.isLoading)
        #expect(vm.error == nil)
    }

    @Test("loadInsuranceData: checklist has 5 items after load")
    func loadInsuranceDataChecklistItemCount() async {
        let profile = makeProfile()
        let vm = makeViewModel(profile: profile)

        await vm.loadInsuranceData()

        #expect(vm.estatePlanningChecklist.count == 5)
    }

    // MARK: - updateEstatePlanning

    @Test("updateEstatePlanning: marks will complete")
    func updateEstatePlanningWill() async {
        let vm = makeViewModel(profile: makeProfile())
        await vm.loadInsuranceData()

        vm.updateEstatePlanning(
            hasWill: true,
            hasTrust: false,
            hasPOA: false,
            hasHealthcareDirective: false,
            hasBeneficiariesUpdated: false
        )

        let willItem = vm.estatePlanningChecklist.first { $0.item == "Last Will & Testament" }
        #expect(willItem?.isComplete == true)
    }

    @Test("updateEstatePlanning: all true marks all complete")
    func updateEstatePlanningAllTrue() async {
        let vm = makeViewModel(profile: makeProfile())
        await vm.loadInsuranceData()

        vm.updateEstatePlanning(
            hasWill: true,
            hasTrust: true,
            hasPOA: true,
            hasHealthcareDirective: true,
            hasBeneficiariesUpdated: true
        )

        #expect(vm.estatePlanningChecklist.allSatisfy { $0.isComplete })
    }
}

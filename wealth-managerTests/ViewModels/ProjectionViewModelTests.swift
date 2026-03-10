import Testing
import Foundation

@testable import wealth_manager

// MARK: - ProjectionViewModelTests

@Suite("ProjectionViewModel")
struct ProjectionViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(
        accounts: [Account] = [],
        profile: UserProfile? = nil
    ) -> ProjectionViewModel {
        let accountRepo = MockAccountRepository()
        accountRepo.items = accounts
        let profileRepo = MockUserProfileRepository()
        profileRepo.profile = profile

        return ProjectionViewModel(
            projectionService: ProjectionService(),
            accountRepo: accountRepo,
            profileRepo: profileRepo
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

    private func makeProfile() -> UserProfile {
        UserProfile(
            annualIncome: 150_000,
            monthlyExpenses: 6_000,
            riskTolerance: .moderate
        )
    }

    // MARK: - Loading

    @Test("loadProjections: populates scenarios")
    func loadProjectionsPopulatesScenarios() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadProjections()

        #expect(vm.scenarios.count == 3)
        #expect(vm.scenarios[0].label == "Conservative")
        #expect(vm.scenarios[1].label == "Moderate")
        #expect(vm.scenarios[2].label == "Aggressive")
    }

    @Test("loadProjections: conservative < moderate < aggressive final net worth")
    func scenarioOrdering() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadProjections()

        #expect(vm.scenarios[0].finalNetWorth < vm.scenarios[1].finalNetWorth)
        #expect(vm.scenarios[1].finalNetWorth < vm.scenarios[2].finalNetWorth)
    }

    @Test("loadProjections: populates Monte Carlo result")
    func loadProjectionsPopulatesMonteCarlo() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadProjections()

        #expect(vm.monteCarloResult != nil)
        let result = vm.monteCarloResult!
        let successDouble = NSDecimalNumber(decimal: result.successRate).doubleValue
        #expect(successDouble >= 0)
        #expect(successDouble <= 1)
    }

    @Test("loadProjections: default projection horizon is 30 years")
    func defaultProjectionHorizon() {
        let vm = makeViewModel()
        #expect(vm.projectionYears == 30)
    }

    @Test("loadProjections: uses current net worth from accounts")
    func usesCurrentNetWorth() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadProjections()

        // Starting net worth = 250k + 50k = 300k
        #expect(vm.currentNetWorth == 300_000)
    }

    // MARK: - Projection Horizon

    @Test("updateProjectionYears: reloads projections with new horizon")
    func updateProjectionYears() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadProjections()
        let initialFinal = vm.scenarios.first?.finalNetWorth ?? 0

        vm.projectionYears = 10
        await vm.loadProjections()

        // 10 year projection should yield less than 30 year
        #expect((vm.scenarios.first?.finalNetWorth ?? 0) < initialFinal)
    }

    // MARK: - Empty State

    @Test("loadProjections: empty accounts yields zero scenarios")
    func emptyAccountsZeroScenarios() async {
        let vm = makeViewModel(profile: makeProfile())

        await vm.loadProjections()

        // Should still produce 3 scenarios, just starting from 0
        #expect(vm.scenarios.count == 3)
        #expect(vm.currentNetWorth == 0)
    }

    @Test("loadProjections: no profile uses defaults")
    func noProfileUsesDefaults() async {
        let vm = makeViewModel(accounts: makeSampleAccounts())

        await vm.loadProjections()

        // Should still work with default assumptions
        #expect(vm.scenarios.count == 3)
    }

    // MARK: - Loading State

    @Test("loadProjections: isLoading transitions correctly")
    func isLoadingTransitions() async {
        let vm = makeViewModel()
        #expect(!vm.isLoading)
        await vm.loadProjections()
        #expect(!vm.isLoading)
    }

    // MARK: - FIRE Result

    @Test("loadProjections: populates FIRE result")
    func populatesFireResult() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadProjections()

        #expect(vm.fireResult != nil)
        #expect(vm.fireResult!.fireNumber > 0)
    }
}

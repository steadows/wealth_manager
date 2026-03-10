import Testing
import Foundation

@testable import wealth_manager

// MARK: - WhatIfViewModelTests

@Suite("WhatIfViewModel")
struct WhatIfViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(
        accounts: [Account] = [],
        profile: UserProfile? = nil
    ) -> WhatIfViewModel {
        let accountRepo = MockAccountRepository()
        accountRepo.items = accounts
        let profileRepo = MockUserProfileRepository()
        profileRepo.profile = profile

        return WhatIfViewModel(
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
                currentBalance: 300_000,
                isManual: true
            ),
            Account(
                institutionName: "Chase",
                accountName: "Mortgage",
                accountType: .loan,
                currentBalance: 200_000,
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

    @Test("loadBaseline: computes baseline projection")
    func loadBaselineComputesProjection() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadBaseline()

        #expect(!vm.baselinePoints.isEmpty)
        #expect(vm.baselinePoints[0].year == 0)
    }

    @Test("loadBaseline: baseline starts at current net worth")
    func baselineStartsAtCurrentNetWorth() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadBaseline()

        // Net worth = 300k (asset) - 200k (liability) = 100k
        #expect(vm.currentNetWorth == 100_000)
        #expect(vm.baselinePoints.first?.netWorth == 100_000)
    }

    // MARK: - What-If Scenarios

    @Test("applyAdjustment: increaseSavings produces higher final net worth")
    func increaseSavingsHigherFinal() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadBaseline()
        await vm.applyAdjustment(.increaseSavings(24_000))

        let baselineFinal = vm.baselinePoints.last!.netWorth
        let adjustedFinal = vm.adjustedPoints.last!.netWorth
        #expect(adjustedFinal > baselineFinal)
    }

    @Test("applyAdjustment: payOffMortgage starts lower but may cross over")
    func payOffMortgageStartsLower() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadBaseline()
        await vm.applyAdjustment(.payOffMortgage(200_000))

        // Year 0 should be lower (net worth drops by mortgage amount)
        let adjustedStart = vm.adjustedPoints.first!.netWorth
        let baselineStart = vm.baselinePoints.first!.netWorth
        #expect(adjustedStart < baselineStart)
    }

    @Test("applyAdjustment: sellRSUs increases starting net worth")
    func sellRSUsIncreasesStart() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadBaseline()
        await vm.applyAdjustment(.sellRSUs(50_000))

        let adjustedStart = vm.adjustedPoints.first!.netWorth
        let baselineStart = vm.baselinePoints.first!.netWorth
        #expect(adjustedStart > baselineStart)
    }

    @Test("applyAdjustment: sabbatical reduces final net worth")
    func sabbaticalReducesFinal() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadBaseline()
        await vm.applyAdjustment(.sabbatical(months: 12))

        let baselineFinal = vm.baselinePoints.last!.netWorth
        let adjustedFinal = vm.adjustedPoints.last!.netWorth
        #expect(adjustedFinal < baselineFinal)
    }

    // MARK: - Impact Calculation

    @Test("applyAdjustment: computes impact amount")
    func computesImpactAmount() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadBaseline()
        await vm.applyAdjustment(.increaseSavings(12_000))

        #expect(vm.impactAmount != 0)
        #expect(vm.impactAmount > 0) // extra savings = positive impact
    }

    // MARK: - Projection Horizon

    @Test("default projection horizon is 20 years")
    func defaultHorizon() {
        let vm = makeViewModel()
        #expect(vm.projectionYears == 20)
    }

    @Test("changing horizon updates projections")
    func changingHorizonUpdates() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadBaseline()
        let points30 = vm.baselinePoints.count

        vm.projectionYears = 10
        await vm.loadBaseline()

        #expect(vm.baselinePoints.count < points30)
    }

    // MARK: - Empty State

    @Test("loadBaseline: empty accounts yields zero baseline")
    func emptyAccountsZeroBaseline() async {
        let vm = makeViewModel(profile: makeProfile())

        await vm.loadBaseline()

        #expect(vm.currentNetWorth == 0)
        #expect(vm.baselinePoints.first?.netWorth == 0)
    }

    // MARK: - Clear Adjustment

    @Test("clearAdjustment: clears adjusted points and impact")
    func clearAdjustment() async {
        let vm = makeViewModel(
            accounts: makeSampleAccounts(),
            profile: makeProfile()
        )

        await vm.loadBaseline()
        await vm.applyAdjustment(.increaseSavings(12_000))
        #expect(!vm.adjustedPoints.isEmpty)

        vm.clearAdjustment()

        #expect(vm.adjustedPoints.isEmpty)
        #expect(vm.impactAmount == 0)
    }
}

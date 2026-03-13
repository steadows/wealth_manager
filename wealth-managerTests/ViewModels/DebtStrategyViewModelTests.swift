import Testing
import Foundation

@testable import wealth_manager

// MARK: - DebtStrategyViewModelTests

@Suite("DebtStrategyViewModel")
struct DebtStrategyViewModelTests {

    // MARK: - Helpers

    private func makeDebt(
        name: String,
        balance: Decimal,
        rate: Decimal,
        minimum: Decimal
    ) -> Debt {
        Debt(
            debtName: name,
            debtType: .creditCard,
            originalBalance: balance,
            currentBalance: balance,
            interestRate: rate,
            minimumPayment: minimum,
            isFixedRate: true
        )
    }

    private func makeViewModel(debts: [Debt] = []) -> DebtStrategyViewModel {
        let debtRepo = MockDebtRepository()
        debtRepo.items = debts
        let accountRepo = MockAccountRepository()
        let profileRepo = MockUserProfileRepository()
        return DebtStrategyViewModel(
            debtRepo: debtRepo,
            accountRepo: accountRepo,
            profileRepo: profileRepo
        )
    }

    // MARK: - Initial State

    @Test("initial state: isLoading is false")
    func initialStateIsLoading() {
        let vm = makeViewModel()
        #expect(!vm.isLoading)
    }

    @Test("initial state: plans are nil before load")
    func initialStatePlansNil() {
        let vm = makeViewModel()
        #expect(vm.avalanchePlan == nil)
        #expect(vm.snowballPlan == nil)
    }

    @Test("initial state: totalDebt is zero")
    func initialStateTotalDebtZero() {
        let vm = makeViewModel()
        #expect(vm.totalDebt == 0)
    }

    // MARK: - loadDebtData

    @Test("loadDebtData: populates avalanche and snowball plans with 2 debts")
    func loadDebtDataPopulatesPlans() async {
        let debts = [
            makeDebt(name: "Credit Card", balance: 5_000, rate: Decimal(string: "0.20")!, minimum: 150),
            makeDebt(name: "Car Loan", balance: 12_000, rate: Decimal(string: "0.06")!, minimum: 250),
        ]
        let vm = makeViewModel(debts: debts)

        await vm.loadDebtData()

        #expect(vm.avalanchePlan != nil)
        #expect(vm.snowballPlan != nil)
        #expect(!vm.isLoading)
        #expect(vm.error == nil)
    }

    @Test("loadDebtData: totalDebt equals sum of all current balances")
    func loadDebtDataTotalDebt() async {
        let debts = [
            makeDebt(name: "Credit Card", balance: 5_000, rate: Decimal(string: "0.20")!, minimum: 150),
            makeDebt(name: "Car Loan", balance: 12_000, rate: Decimal(string: "0.06")!, minimum: 250),
        ]
        let vm = makeViewModel(debts: debts)

        await vm.loadDebtData()

        #expect(vm.totalDebt == 17_000)
    }

    @Test("loadDebtData: recommendedStrategy is non-empty after load")
    func loadDebtDataRecommendedStrategy() async {
        let debts = [
            makeDebt(name: "Credit Card", balance: 5_000, rate: Decimal(string: "0.20")!, minimum: 150),
        ]
        let vm = makeViewModel(debts: debts)

        await vm.loadDebtData()

        #expect(!vm.recommendedStrategy.isEmpty)
    }

    @Test("loadDebtData: empty debts yields graceful defaults")
    func loadDebtDataEmptyDebts() async {
        let vm = makeViewModel(debts: [])

        await vm.loadDebtData()

        #expect(vm.totalDebt == 0)
        #expect(vm.avalanchePlan != nil)
        #expect(vm.snowballPlan != nil)
        // Plans should have zero months and zero interest for empty debt
        #expect(vm.avalanchePlan?.totalMonths == 0)
        #expect(vm.avalanchePlan?.totalInterestPaid == 0)
        #expect(!vm.isLoading)
    }

    @Test("loadDebtData: debts array is populated")
    func loadDebtDataPopulatesDebts() async {
        let debts = [
            makeDebt(name: "Credit Card", balance: 5_000, rate: Decimal(string: "0.20")!, minimum: 150),
            makeDebt(name: "Car Loan", balance: 12_000, rate: Decimal(string: "0.06")!, minimum: 250),
        ]
        let vm = makeViewModel(debts: debts)

        await vm.loadDebtData()

        #expect(vm.debts.count == 2)
    }

    // MARK: - updateExtraPayment

    @Test("updateExtraPayment: recalculates plans with extra amount")
    func updateExtraPaymentRecalculates() async {
        let debts = [
            makeDebt(name: "Credit Card", balance: 5_000, rate: Decimal(string: "0.20")!, minimum: 150),
        ]
        let vm = makeViewModel(debts: debts)
        await vm.loadDebtData()

        let originalMonths = vm.avalanchePlan?.totalMonths ?? 0

        await vm.updateExtraPayment(500)

        // With extra $500/mo, payoff should be faster (fewer months)
        let updatedMonths = vm.avalanchePlan?.totalMonths ?? 0
        #expect(updatedMonths <= originalMonths)
    }

    @Test("updateExtraPayment: updates extraMonthlyPayment property")
    func updateExtraPaymentUpdatesProperty() async {
        let vm = makeViewModel()
        await vm.loadDebtData()

        await vm.updateExtraPayment(200)

        #expect(vm.extraMonthlyPayment == 200)
    }

    @Test("updateExtraPayment: zero extra payment valid")
    func updateExtraPaymentZero() async {
        let debts = [
            makeDebt(name: "Credit Card", balance: 5_000, rate: Decimal(string: "0.20")!, minimum: 150),
        ]
        let vm = makeViewModel(debts: debts)
        await vm.loadDebtData()

        await vm.updateExtraPayment(0)

        #expect(vm.extraMonthlyPayment == 0)
        #expect(vm.avalanchePlan != nil)
    }
}

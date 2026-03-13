import Foundation
import Observation

// MARK: - DebtStrategyViewModel

/// ViewModel for the Debt Strategy screen: avalanche vs snowball comparison,
/// extra payment slider, and recommended strategy.
@Observable
final class DebtStrategyViewModel {

    // MARK: - Published State

    var debts: [Debt] = []
    var avalanchePlan: DebtCalculator.PayoffPlan?
    var snowballPlan: DebtCalculator.PayoffPlan?
    var totalDebt: Decimal = 0
    var recommendedStrategy: String = ""
    var extraMonthlyPayment: Decimal = 0
    var isLoading: Bool = false
    var error: Error?

    // MARK: - Dependencies

    private let debtRepo: any DebtRepository
    private let accountRepo: any AccountRepository
    private let profileRepo: any UserProfileRepository

    // MARK: - Init

    /// Creates the view model with injected repositories.
    ///
    /// - Parameters:
    ///   - debtRepo: Repository providing `Debt` records.
    ///   - accountRepo: Repository providing account balances.
    ///   - profileRepo: Repository providing the user profile.
    init(
        debtRepo: any DebtRepository,
        accountRepo: any AccountRepository,
        profileRepo: any UserProfileRepository
    ) {
        self.debtRepo = debtRepo
        self.accountRepo = accountRepo
        self.profileRepo = profileRepo
    }

    // MARK: - Data Loading

    /// Loads all debt data and computes payoff plans.
    func loadDebtData() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let fetchedDebts = try await debtRepo.fetchAll()
            debts = fetchedDebts
            totalDebt = fetchedDebts.reduce(Decimal.zero) { $0 + $1.currentBalance }
            computePlans(debts: fetchedDebts, extraPayment: extraMonthlyPayment)
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Updates the extra monthly payment amount and recalculates payoff plans.
    ///
    /// - Parameter amount: Additional monthly payment above all minimums.
    func updateExtraPayment(_ amount: Decimal) async {
        extraMonthlyPayment = max(amount, 0)
        computePlans(debts: debts, extraPayment: extraMonthlyPayment)
    }

    // MARK: - Private Helpers

    private func computePlans(debts: [Debt], extraPayment: Decimal) {
        let avalanche = DebtCalculator.avalanchePayoff(
            debts: debts,
            extraMonthlyPayment: extraPayment
        )
        let snowball = DebtCalculator.snowballPayoff(
            debts: debts,
            extraMonthlyPayment: extraPayment
        )
        avalanchePlan = avalanche
        snowballPlan = snowball
        recommendedStrategy = buildRecommendation(avalanche: avalanche, snowball: snowball)
    }

    private func buildRecommendation(
        avalanche: DebtCalculator.PayoffPlan,
        snowball: DebtCalculator.PayoffPlan
    ) -> String {
        guard avalanche.totalMonths > 0 || snowball.totalMonths > 0 else {
            return "No outstanding debts — great work!"
        }

        if avalanche.totalInterestPaid < snowball.totalInterestPaid {
            let saved = snowball.totalInterestPaid - avalanche.totalInterestPaid
            let monthDiff = snowball.totalMonths - avalanche.totalMonths
            let monthText = monthDiff > 0 ? " and \(monthDiff) months faster" : ""
            return "Avalanche method saves \(formatCurrency(saved)) in interest\(monthText). "
                + "Pay highest-rate debts first."
        } else if snowball.totalInterestPaid < avalanche.totalInterestPaid {
            return "Snowball method keeps you motivated by clearing small debts quickly. "
                + "Avalanche saves slightly more interest."
        } else {
            return "Both strategies yield similar results. "
                + "Avalanche minimizes interest; snowball builds momentum."
        }
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

import Foundation

// MARK: - DebtCalculator

/// Pure calculator for debt payoff strategies, amortization, and debt-vs-invest analysis.
/// Never mutates passed-in `Debt` model objects — copies fields into local value types.
nonisolated struct DebtCalculator: Sendable {

    // MARK: - Types

    /// A single row in an amortization schedule.
    struct AmortizationEntry: Sendable, Equatable {
        let month: Int
        let payment: Decimal
        let principal: Decimal
        let interest: Decimal
        let remainingBalance: Decimal
    }

    /// Result of a multi-debt payoff simulation.
    struct PayoffPlan: Sendable, Equatable {
        let debts: [(name: String, payoffMonth: Int, totalInterestPaid: Decimal)]
        let totalMonths: Int
        let totalInterestPaid: Decimal

        static func == (lhs: PayoffPlan, rhs: PayoffPlan) -> Bool {
            guard lhs.totalMonths == rhs.totalMonths,
                  lhs.totalInterestPaid == rhs.totalInterestPaid,
                  lhs.debts.count == rhs.debts.count else { return false }
            return zip(lhs.debts, rhs.debts).allSatisfy {
                $0.name == $1.name
                    && $0.payoffMonth == $1.payoffMonth
                    && $0.totalInterestPaid == $1.totalInterestPaid
            }
        }
    }

    /// Lightweight value-type snapshot of a Debt model for simulation.
    private struct DebtSnapshot {
        let name: String
        var balance: Decimal
        let interestRate: Decimal
        let minimumPayment: Decimal
    }

    // MARK: - Amortization

    /// Generate a full amortization schedule for a single debt.
    ///
    /// - Parameters:
    ///   - balance: Current outstanding balance.
    ///   - annualRate: Annual interest rate as a decimal.
    ///   - monthlyPayment: Fixed monthly payment amount.
    /// - Returns: An array of `AmortizationEntry` rows, one per month until payoff.
    static func amortizationSchedule(
        balance: Decimal,
        annualRate: Decimal,
        monthlyPayment: Decimal
    ) -> [AmortizationEntry] {
        guard balance > 0, monthlyPayment > 0 else { return [] }

        let monthlyRate = annualRate / 12
        var remaining = balance
        var entries: [AmortizationEntry] = []
        var month = 0
        let maxMonths = 1200 // 100-year safety cap

        while remaining > 0, month < maxMonths {
            month += 1
            let interestCharge = remaining * monthlyRate

            // Payment cannot exceed interest on zero-progress debts
            if monthlyPayment <= interestCharge, annualRate > 0 {
                // Will never pay off — return what we have plus a final entry
                entries.append(AmortizationEntry(
                    month: month,
                    payment: monthlyPayment,
                    principal: monthlyPayment - interestCharge,
                    interest: interestCharge,
                    remainingBalance: remaining + interestCharge - monthlyPayment
                ))
                break
            }

            let payment = min(monthlyPayment, remaining + interestCharge)
            let principalPaid = payment - interestCharge
            remaining = max(remaining - principalPaid, 0)

            entries.append(AmortizationEntry(
                month: month,
                payment: payment,
                principal: principalPaid,
                interest: interestCharge,
                remainingBalance: remaining
            ))
        }

        return entries
    }

    // MARK: - Payoff Strategies

    /// Avalanche method: direct extra payments to the highest-interest debt first.
    ///
    /// - Parameters:
    ///   - debts: Array of `Debt` model objects (not mutated).
    ///   - extraMonthlyPayment: Additional monthly amount beyond all minimums.
    /// - Returns: A `PayoffPlan` describing when each debt is paid off.
    static func avalanchePayoff(
        debts: [Debt],
        extraMonthlyPayment: Decimal
    ) -> PayoffPlan {
        let snapshots = debts.map { snapshot(from: $0) }
        return simulatePayoff(
            snapshots: snapshots,
            extraMonthlyPayment: extraMonthlyPayment,
            sortStrategy: .highestRateFirst
        )
    }

    /// Snowball method: direct extra payments to the smallest balance first.
    ///
    /// - Parameters:
    ///   - debts: Array of `Debt` model objects (not mutated).
    ///   - extraMonthlyPayment: Additional monthly amount beyond all minimums.
    /// - Returns: A `PayoffPlan` describing when each debt is paid off.
    static func snowballPayoff(
        debts: [Debt],
        extraMonthlyPayment: Decimal
    ) -> PayoffPlan {
        let snapshots = debts.map { snapshot(from: $0) }
        return simulatePayoff(
            snapshots: snapshots,
            extraMonthlyPayment: extraMonthlyPayment,
            sortStrategy: .lowestBalanceFirst
        )
    }

    /// Hybrid/optimized payoff: debts with rates above the expected investment return
    /// are prioritized by rate (avalanche); the rest are sorted by balance (snowball).
    ///
    /// - Parameters:
    ///   - debts: Array of `Debt` model objects (not mutated).
    ///   - extraMonthlyPayment: Additional monthly amount beyond all minimums.
    ///   - expectedInvestmentReturn: Expected annual return if money were invested instead.
    /// - Returns: A `PayoffPlan` describing when each debt is paid off.
    static func optimizedPayoff(
        debts: [Debt],
        extraMonthlyPayment: Decimal,
        expectedInvestmentReturn: Decimal
    ) -> PayoffPlan {
        let snapshots = debts.map { snapshot(from: $0) }
        return simulatePayoff(
            snapshots: snapshots,
            extraMonthlyPayment: extraMonthlyPayment,
            sortStrategy: .optimized(investmentReturn: expectedInvestmentReturn)
        )
    }

    // MARK: - Refinance Break-Even

    /// Calculate the number of months until refinancing savings exceed closing costs.
    ///
    /// - Parameters:
    ///   - currentBalance: Remaining loan balance.
    ///   - currentRate: Current annual interest rate.
    ///   - newRate: Proposed refinance annual rate.
    ///   - closingCosts: One-time refinance costs.
    ///   - remainingMonths: Months left on the current loan.
    /// - Returns: Break-even month, or `nil` if refinancing never breaks even.
    static func refinanceBreakeven(
        currentBalance: Decimal,
        currentRate: Decimal,
        newRate: Decimal,
        closingCosts: Decimal,
        remainingMonths: Int
    ) -> Int? {
        guard currentBalance > 0, newRate < currentRate, closingCosts > 0 else {
            return nil
        }

        let currentMonthlyRate = currentRate / 12
        let newMonthlyRate = newRate / 12
        let currentMonthlyInterest = currentBalance * currentMonthlyRate
        let newMonthlyInterest = currentBalance * newMonthlyRate
        let monthlySavings = currentMonthlyInterest - newMonthlyInterest

        guard monthlySavings > 0 else { return nil }

        let breakeven = closingCosts / monthlySavings
        let breakevenMonths = Int(NSDecimalNumber(decimal: breakeven).doubleValue.rounded(.up))

        guard breakevenMonths <= remainingMonths else { return nil }
        return breakevenMonths
    }

    // MARK: - Debt vs. Invest

    /// Compare the net benefit of paying off debt versus investing the same amount.
    ///
    /// - Parameters:
    ///   - debtBalance: Outstanding debt balance.
    ///   - debtRate: Annual interest rate on the debt.
    ///   - investmentReturn: Expected annual investment return.
    ///   - monthlyAmount: Monthly amount to allocate.
    ///   - years: Time horizon in years.
    /// - Returns: Net benefit of each strategy and a recommendation string.
    static func debtVsInvest(
        debtBalance: Decimal,
        debtRate: Decimal,
        investmentReturn: Decimal,
        monthlyAmount: Decimal,
        years: Int
    ) -> (payDebtBenefit: Decimal, investBenefit: Decimal, recommendation: String) {
        guard years > 0, monthlyAmount > 0 else {
            return (0, 0, "Insufficient parameters for comparison.")
        }

        let interestSaved = calculateInterestSaved(
            balance: debtBalance,
            annualRate: debtRate,
            monthlyPayment: monthlyAmount,
            years: years
        )

        let investmentGrowth = CompoundInterestCalculator.futureValueWithContributions(
            monthlyContribution: monthlyAmount,
            annualRate: investmentReturn,
            years: years
        )
        let totalContributed = monthlyAmount * Decimal(12 * years)
        let investGain = investmentGrowth - totalContributed

        let recommendation = makeDebtVsInvestRecommendation(
            interestSaved: interestSaved,
            investGain: investGain,
            debtRate: debtRate,
            investmentReturn: investmentReturn
        )

        return (
            payDebtBenefit: interestSaved,
            investBenefit: investGain,
            recommendation: recommendation
        )
    }

    // MARK: - Private Helpers

    private enum SortStrategy {
        case highestRateFirst
        case lowestBalanceFirst
        case optimized(investmentReturn: Decimal)
    }

    private static func snapshot(from debt: Debt) -> DebtSnapshot {
        DebtSnapshot(
            name: debt.debtName,
            balance: debt.currentBalance,
            interestRate: debt.interestRate,
            minimumPayment: debt.minimumPayment
        )
    }

    private static func simulatePayoff(
        snapshots: [DebtSnapshot],
        extraMonthlyPayment: Decimal,
        sortStrategy: SortStrategy
    ) -> PayoffPlan {
        guard !snapshots.isEmpty else {
            return PayoffPlan(debts: [], totalMonths: 0, totalInterestPaid: 0)
        }

        var working = snapshots
        var interestAccumulated = [Decimal](repeating: 0, count: working.count)
        var payoffMonths = [Int](repeating: 0, count: working.count)
        var month = 0
        let maxMonths = 1200

        while working.contains(where: { $0.balance > 0 }), month < maxMonths {
            month += 1

            // Accrue interest
            for i in working.indices where working[i].balance > 0 {
                let interest = working[i].balance * working[i].interestRate / 12
                interestAccumulated[i] += interest
                working[i].balance += interest
            }

            // Make minimum payments
            var extra = extraMonthlyPayment
            for i in working.indices where working[i].balance > 0 {
                let payment = min(working[i].minimumPayment, working[i].balance)
                working[i].balance -= payment
                if working[i].balance <= 0 {
                    working[i].balance = 0
                    if payoffMonths[i] == 0 { payoffMonths[i] = month }
                }
            }

            // Freed-up minimums from paid-off debts become extra
            for i in working.indices where working[i].balance == 0 && payoffMonths[i] == month {
                extra += snapshots[i].minimumPayment
            }

            // Direct extra to priority debt
            let priorityOrder = sortedIndices(working: working, strategy: sortStrategy)
            var remainingExtra = extra
            for i in priorityOrder {
                guard remainingExtra > 0, working[i].balance > 0 else { continue }
                let payment = min(remainingExtra, working[i].balance)
                working[i].balance -= payment
                remainingExtra -= payment
                if working[i].balance <= 0 {
                    working[i].balance = 0
                    if payoffMonths[i] == 0 { payoffMonths[i] = month }
                }
            }
        }

        let debtResults: [(String, Int, Decimal)] = snapshots.indices.map { i in
            (snapshots[i].name, payoffMonths[i], interestAccumulated[i])
        }
        let totalMonths = payoffMonths.max() ?? 0
        let totalInterest = interestAccumulated.reduce(0, +)

        return PayoffPlan(
            debts: debtResults,
            totalMonths: totalMonths,
            totalInterestPaid: totalInterest
        )
    }

    private static func sortedIndices(
        working: [DebtSnapshot],
        strategy: SortStrategy
    ) -> [Int] {
        let activeIndices = working.indices.filter { working[$0].balance > 0 }

        switch strategy {
        case .highestRateFirst:
            return activeIndices.sorted { working[$0].interestRate > working[$1].interestRate }

        case .lowestBalanceFirst:
            return activeIndices.sorted { working[$0].balance < working[$1].balance }

        case .optimized(let investmentReturn):
            // High-rate debts (above investment return) first by rate, rest by balance
            let highRate = activeIndices
                .filter { working[$0].interestRate > investmentReturn }
                .sorted { working[$0].interestRate > working[$1].interestRate }
            let lowRate = activeIndices
                .filter { working[$0].interestRate <= investmentReturn }
                .sorted { working[$0].balance < working[$1].balance }
            return highRate + lowRate
        }
    }

    private static func calculateInterestSaved(
        balance: Decimal,
        annualRate: Decimal,
        monthlyPayment: Decimal,
        years: Int
    ) -> Decimal {
        guard balance > 0, monthlyPayment > 0, years > 0 else { return 0 }

        let monthlyRate = annualRate / 12
        let totalMonths = 12 * years
        var remaining = balance
        var totalInterestMinimum: Decimal = 0
        var totalInterestAccelerated: Decimal = 0

        // Interest with minimum-only payments
        var minRemaining = balance
        for _ in 0..<totalMonths {
            guard minRemaining > 0 else { break }
            let interest = minRemaining * monthlyRate
            totalInterestMinimum += interest
            let minPayment = min(balance * Decimal(string: "0.02")!, minRemaining + interest)
            minRemaining = max(minRemaining + interest - minPayment, 0)
        }

        // Interest with accelerated payments
        for _ in 0..<totalMonths {
            guard remaining > 0 else { break }
            let interest = remaining * monthlyRate
            totalInterestAccelerated += interest
            let payment = min(monthlyPayment, remaining + interest)
            remaining = max(remaining + interest - payment, 0)
        }

        return max(totalInterestMinimum - totalInterestAccelerated, 0)
    }

    private static func makeDebtVsInvestRecommendation(
        interestSaved: Decimal,
        investGain: Decimal,
        debtRate: Decimal,
        investmentReturn: Decimal
    ) -> String {
        if interestSaved > investGain {
            return "Pay off debt first. The guaranteed \(debtRate * 100)% interest savings "
                + "exceeds the expected \(investmentReturn * 100)% investment return."
        } else if investGain > interestSaved {
            return "Invest the money. The expected \(investmentReturn * 100)% return "
                + "exceeds the \(debtRate * 100)% debt interest rate."
        } else {
            return "Both strategies yield similar results. Consider paying debt "
                + "for the guaranteed return."
        }
    }
}

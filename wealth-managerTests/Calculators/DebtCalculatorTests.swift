import Testing
import Foundation

@testable import wealth_manager

// MARK: - Test Helpers

private func makeDebt(
    name: String = "Test Debt",
    type: DebtType = .creditCard,
    balance: Decimal,
    rate: Decimal,
    minimumPayment: Decimal
) -> Debt {
    Debt(
        debtName: name,
        debtType: type,
        originalBalance: balance,
        currentBalance: balance,
        interestRate: rate,
        minimumPayment: minimumPayment,
        isFixedRate: true
    )
}

// MARK: - DebtCalculatorTests

@Suite("DebtCalculator")
struct DebtCalculatorTests {

    // MARK: - amortizationSchedule

    @Test("amortizationSchedule: final balance approximately 0")
    func amortizationFinalBalanceZero() {
        let schedule = DebtCalculator.amortizationSchedule(
            balance: 10_000,
            annualRate: Decimal(string: "0.06")!,
            monthlyPayment: 200
        )
        #expect(!schedule.isEmpty)
        let finalBalance = NSDecimalNumber(decimal: schedule.last!.remainingBalance).doubleValue
        #expect(abs(finalBalance) < 1)
    }

    @Test("amortizationSchedule: total payments equal principal plus interest")
    func amortizationTotalPayments() {
        let schedule = DebtCalculator.amortizationSchedule(
            balance: 10_000,
            annualRate: Decimal(string: "0.06")!,
            monthlyPayment: 200
        )
        let totalPaid = schedule.reduce(Decimal(0)) { $0 + $1.payment }
        let totalInterest = schedule.reduce(Decimal(0)) { $0 + $1.interest }
        let totalPrincipal = schedule.reduce(Decimal(0)) { $0 + $1.principal }
        let totalPaidDouble = NSDecimalNumber(decimal: totalPaid).doubleValue
        let sumDouble = NSDecimalNumber(decimal: totalInterest + totalPrincipal).doubleValue
        #expect(abs(totalPaidDouble - sumDouble) < 1)
    }

    @Test("amortizationSchedule: months increment correctly")
    func amortizationMonthsIncrement() {
        let schedule = DebtCalculator.amortizationSchedule(
            balance: 5_000,
            annualRate: Decimal(string: "0.05")!,
            monthlyPayment: 500
        )
        for (index, entry) in schedule.enumerated() {
            #expect(entry.month == index + 1)
        }
    }

    @Test("amortizationSchedule: zero balance returns empty")
    func amortizationZeroBalance() {
        let schedule = DebtCalculator.amortizationSchedule(
            balance: 0,
            annualRate: Decimal(string: "0.06")!,
            monthlyPayment: 200
        )
        #expect(schedule.isEmpty)
    }

    @Test("amortizationSchedule: zero interest pays off evenly")
    func amortizationZeroInterest() {
        let schedule = DebtCalculator.amortizationSchedule(
            balance: 1_000,
            annualRate: 0,
            monthlyPayment: 200
        )
        #expect(schedule.count == 5)
        let totalInterest = schedule.reduce(Decimal(0)) { $0 + $1.interest }
        #expect(totalInterest == 0)
    }

    // MARK: - avalanchePayoff

    @Test("avalanchePayoff: highest-rate debt paid first")
    func avalancheHighestRateFirst() {
        let highRate = makeDebt(
            name: "High Rate",
            balance: 5_000,
            rate: Decimal(string: "0.24")!,
            minimumPayment: 100
        )
        let lowRate = makeDebt(
            name: "Low Rate",
            balance: 5_000,
            rate: Decimal(string: "0.06")!,
            minimumPayment: 100
        )
        let plan = DebtCalculator.avalanchePayoff(
            debts: [lowRate, highRate],
            extraMonthlyPayment: 200
        )
        // High rate debt should be paid off first (lower payoff month)
        let highRateDebt = plan.debts.first { $0.name == "High Rate" }
        let lowRateDebt = plan.debts.first { $0.name == "Low Rate" }
        #expect(highRateDebt != nil)
        #expect(lowRateDebt != nil)
        if let highMonth = highRateDebt?.payoffMonth, let lowMonth = lowRateDebt?.payoffMonth {
            #expect(highMonth <= lowMonth)
        }
    }

    // MARK: - snowballPayoff

    @Test("snowballPayoff: lowest-balance debt paid first")
    func snowballLowestBalanceFirst() {
        let smallBalance = makeDebt(
            name: "Small",
            balance: 2_000,
            rate: Decimal(string: "0.06")!,
            minimumPayment: 50
        )
        let largeBalance = makeDebt(
            name: "Large",
            balance: 10_000,
            rate: Decimal(string: "0.24")!,
            minimumPayment: 200
        )
        let plan = DebtCalculator.snowballPayoff(
            debts: [largeBalance, smallBalance],
            extraMonthlyPayment: 200
        )
        let smallDebt = plan.debts.first { $0.name == "Small" }
        let largeDebt = plan.debts.first { $0.name == "Large" }
        #expect(smallDebt != nil)
        #expect(largeDebt != nil)
        if let smallMonth = smallDebt?.payoffMonth, let largeMonth = largeDebt?.payoffMonth {
            #expect(smallMonth <= largeMonth)
        }
    }

    // MARK: - refinanceBreakeven

    @Test("refinanceBreakeven: known scenario")
    func refinanceBreakevenKnown() {
        let result = DebtCalculator.refinanceBreakeven(
            currentBalance: 200_000,
            currentRate: Decimal(string: "0.06")!,
            newRate: Decimal(string: "0.04")!,
            closingCosts: 5_000,
            remainingMonths: 240
        )
        #expect(result != nil)
        if let months = result {
            // Monthly savings ≈ 200,000 * (0.06 - 0.04) / 12 ≈ $333
            // Breakeven ≈ 5,000 / 333 ≈ 15-16 months (amortization gives 16)
            #expect(months >= 14 && months <= 17)
        }
    }

    @Test("refinanceBreakeven: new rate higher returns nil")
    func refinanceBreakevenHigherRate() {
        let result = DebtCalculator.refinanceBreakeven(
            currentBalance: 200_000,
            currentRate: Decimal(string: "0.04")!,
            newRate: Decimal(string: "0.06")!,
            closingCosts: 5_000,
            remainingMonths: 240
        )
        #expect(result == nil)
    }

    @Test("refinanceBreakeven: breakeven exceeds remaining months returns nil")
    func refinanceBreakevenExceedsRemaining() {
        let result = DebtCalculator.refinanceBreakeven(
            currentBalance: 200_000,
            currentRate: Decimal(string: "0.06")!,
            newRate: Decimal(string: "0.04")!,
            closingCosts: 50_000,
            remainingMonths: 12
        )
        // Monthly savings ≈ $333.33, breakeven ≈ 150 months > 12
        #expect(result == nil)
    }

    // MARK: - debtVsInvest

    @Test("debtVsInvest: 4% debt vs 8% return recommends investing")
    func debtVsInvestRecommendsInvesting() {
        let result = DebtCalculator.debtVsInvest(
            debtBalance: 10_000,
            debtRate: Decimal(string: "0.04")!,
            investmentReturn: Decimal(string: "0.08")!,
            monthlyAmount: 500,
            years: 5
        )
        #expect(result.investBenefit > result.payDebtBenefit)
        #expect(result.recommendation.contains("Invest"))
    }

    @Test("debtVsInvest: 20% debt vs 7% return recommends paying debt")
    func debtVsInvestRecommendsDebt() {
        let result = DebtCalculator.debtVsInvest(
            debtBalance: 10_000,
            debtRate: Decimal(string: "0.20")!,
            investmentReturn: Decimal(string: "0.07")!,
            monthlyAmount: 500,
            years: 5
        )
        #expect(result.payDebtBenefit > result.investBenefit)
        #expect(result.recommendation.contains("debt"))
    }

    @Test("debtVsInvest: zero years returns zeros")
    func debtVsInvestZeroYears() {
        let result = DebtCalculator.debtVsInvest(
            debtBalance: 10_000,
            debtRate: Decimal(string: "0.04")!,
            investmentReturn: Decimal(string: "0.08")!,
            monthlyAmount: 500,
            years: 0
        )
        #expect(result.payDebtBenefit == 0)
        #expect(result.investBenefit == 0)
    }

    // MARK: - Edge cases

    @Test("avalanchePayoff: empty debts returns empty plan")
    func avalancheEmptyDebts() {
        let plan = DebtCalculator.avalanchePayoff(debts: [], extraMonthlyPayment: 200)
        #expect(plan.debts.isEmpty)
        #expect(plan.totalMonths == 0)
        #expect(plan.totalInterestPaid == 0)
    }

    @Test("snowballPayoff: empty debts returns empty plan")
    func snowballEmptyDebts() {
        let plan = DebtCalculator.snowballPayoff(debts: [], extraMonthlyPayment: 200)
        #expect(plan.debts.isEmpty)
        #expect(plan.totalMonths == 0)
        #expect(plan.totalInterestPaid == 0)
    }
}

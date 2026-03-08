import Testing
import Foundation

@testable import wealth_manager

// MARK: - CompoundInterestCalculatorTests

@Suite("CompoundInterestCalculator")
struct CompoundInterestCalculatorTests {

    // MARK: - futureValue

    @Test("futureValue: $10,000 at 7% for 30 years monthly ≈ $81,164")
    func futureValueLumpSum() {
        let result = CompoundInterestCalculator.futureValue(
            presentValue: 10_000,
            annualRate: Decimal(string: "0.07")!,
            years: 30
        )
        let resultDouble = NSDecimalNumber(decimal: result).doubleValue
        #expect(abs(resultDouble - 81_164.0) < 100)
    }

    @Test("futureValue: zero years returns present value")
    func futureValueZeroYears() {
        let result = CompoundInterestCalculator.futureValue(
            presentValue: 10_000,
            annualRate: Decimal(string: "0.07")!,
            years: 0
        )
        #expect(result == 10_000)
    }

    @Test("futureValue: zero rate returns present value")
    func futureValueZeroRate() {
        let result = CompoundInterestCalculator.futureValue(
            presentValue: 10_000,
            annualRate: 0,
            years: 30
        )
        #expect(result == 10_000)
    }

    // MARK: - futureValueWithContributions

    @Test("futureValueWithContributions: $500/month at 7% for 30 years")
    func futureValueWithContributions() {
        let result = CompoundInterestCalculator.futureValueWithContributions(
            monthlyContribution: 500,
            annualRate: Decimal(string: "0.07")!,
            years: 30
        )
        let resultDouble = NSDecimalNumber(decimal: result).doubleValue
        // Expected ≈ $609,985 from standard annuity formula
        #expect(resultDouble > 600_000)
        #expect(resultDouble < 620_000)
    }

    @Test("futureValueWithContributions: zero rate gives simple accumulation")
    func futureValueWithContributionsZeroRate() {
        let result = CompoundInterestCalculator.futureValueWithContributions(
            monthlyContribution: 500,
            annualRate: 0,
            years: 10
        )
        #expect(result == 500 * 12 * 10)
    }

    @Test("futureValueWithContributions: zero years returns 0")
    func futureValueWithContributionsZeroYears() {
        let result = CompoundInterestCalculator.futureValueWithContributions(
            monthlyContribution: 500,
            annualRate: Decimal(string: "0.07")!,
            years: 0
        )
        #expect(result == 0)
    }

    // MARK: - presentValue

    @Test("presentValue: inverse of futureValue")
    func presentValueInverse() {
        let fv = CompoundInterestCalculator.futureValue(
            presentValue: 10_000,
            annualRate: Decimal(string: "0.07")!,
            years: 30
        )
        let pv = CompoundInterestCalculator.presentValue(
            futureValue: fv,
            annualRate: Decimal(string: "0.07")!,
            years: 30
        )
        let pvDouble = NSDecimalNumber(decimal: pv).doubleValue
        #expect(abs(pvDouble - 10_000.0) < 1)
    }

    @Test("presentValue: zero years returns future value")
    func presentValueZeroYears() {
        let result = CompoundInterestCalculator.presentValue(
            futureValue: 50_000,
            annualRate: Decimal(string: "0.07")!,
            years: 0
        )
        #expect(result == 50_000)
    }

    @Test("presentValue: zero rate returns future value")
    func presentValueZeroRate() {
        let result = CompoundInterestCalculator.presentValue(
            futureValue: 50_000,
            annualRate: 0,
            years: 30
        )
        #expect(result == 50_000)
    }

    // MARK: - cagr

    @Test("cagr: $10,000 to $76,123 over 30 years ≈ 7%")
    func cagrKnownScenario() {
        let result = CompoundInterestCalculator.cagr(
            startValue: 10_000,
            endValue: 76_123,
            years: 30
        )
        let resultDouble = NSDecimalNumber(decimal: result).doubleValue
        #expect(abs(resultDouble - 0.07) < 0.005)
    }

    @Test("cagr: zero years returns 0")
    func cagrZeroYears() {
        let result = CompoundInterestCalculator.cagr(
            startValue: 10_000,
            endValue: 76_123,
            years: 0
        )
        #expect(result == 0)
    }

    @Test("cagr: negative start value returns 0")
    func cagrNegativeStart() {
        let result = CompoundInterestCalculator.cagr(
            startValue: -10_000,
            endValue: 76_123,
            years: 30
        )
        #expect(result == 0)
    }

    // MARK: - requiredMonthlyContribution

    @Test("requiredMonthlyContribution: to reach $1M from $0 at 7% over 30 years")
    func requiredMonthlyContributionFromZero() {
        let result = CompoundInterestCalculator.requiredMonthlyContribution(
            targetValue: 1_000_000,
            currentValue: 0,
            annualRate: Decimal(string: "0.07")!,
            years: 30
        )
        let resultDouble = NSDecimalNumber(decimal: result).doubleValue
        // Standard calculation: ~$820/month
        #expect(resultDouble > 790)
        #expect(resultDouble < 850)
    }

    @Test("requiredMonthlyContribution: target already met returns 0")
    func requiredMonthlyContributionAlreadyMet() {
        let result = CompoundInterestCalculator.requiredMonthlyContribution(
            targetValue: 100_000,
            currentValue: 200_000,
            annualRate: Decimal(string: "0.07")!,
            years: 30
        )
        #expect(result == 0)
    }

    @Test("requiredMonthlyContribution: zero years returns 0")
    func requiredMonthlyContributionZeroYears() {
        let result = CompoundInterestCalculator.requiredMonthlyContribution(
            targetValue: 1_000_000,
            currentValue: 0,
            annualRate: Decimal(string: "0.07")!,
            years: 0
        )
        #expect(result == 0)
    }

    @Test("requiredMonthlyContribution: zero rate uses simple division")
    func requiredMonthlyContributionZeroRate() {
        let result = CompoundInterestCalculator.requiredMonthlyContribution(
            targetValue: 120_000,
            currentValue: 0,
            annualRate: 0,
            years: 10
        )
        // 120,000 / 120 months = 1,000
        #expect(result == 1_000)
    }
}

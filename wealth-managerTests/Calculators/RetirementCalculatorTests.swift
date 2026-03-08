import Testing
import Foundation

@testable import wealth_manager

// MARK: - RetirementCalculatorTests

@Suite("RetirementCalculator")
struct RetirementCalculatorTests {

    // MARK: - fireNumber

    @Test("fireNumber: $40,000 expenses at 4% = $1,000,000")
    func fireNumberStandard() {
        let result = RetirementCalculator.fireNumber(annualExpenses: 40_000)
        #expect(result == 1_000_000)
    }

    @Test("fireNumber: zero expenses returns 0")
    func fireNumberZeroExpenses() {
        let result = RetirementCalculator.fireNumber(annualExpenses: 0)
        #expect(result == 0)
    }

    @Test("fireNumber: zero withdrawal rate returns 0")
    func fireNumberZeroRate() {
        let result = RetirementCalculator.fireNumber(
            annualExpenses: 40_000,
            withdrawalRate: 0
        )
        #expect(result == 0)
    }

    // MARK: - yearsToFIRE

    @Test("yearsToFIRE: known scenario converges")
    func yearsToFIREKnownScenario() {
        let result = RetirementCalculator.yearsToFIRE(
            currentPortfolio: 100_000,
            annualContribution: 30_000,
            annualExpenses: 40_000,
            expectedReturn: Decimal(string: "0.07")!
        )
        // Target = $1M, starting from $100K + $30K/yr at 7%
        #expect(result != nil)
        if let years = result {
            #expect(years > 10)
            #expect(years < 30)
        }
    }

    @Test("yearsToFIRE: already FI returns nil")
    func yearsToFIREAlreadyFI() {
        let result = RetirementCalculator.yearsToFIRE(
            currentPortfolio: 2_000_000,
            annualContribution: 30_000,
            annualExpenses: 40_000,
            expectedReturn: Decimal(string: "0.07")!
        )
        #expect(result == nil)
    }

    // MARK: - safeWithdrawal

    @Test("safeWithdrawal: 4% of $1M generates entries with inflation adjustment")
    func safeWithdrawalBasic() {
        let results = RetirementCalculator.safeWithdrawal(
            portfolio: 1_000_000,
            rate: Decimal(string: "0.04")!,
            inflationRate: Decimal(string: "0.03")!,
            years: 5
        )
        #expect(!results.isEmpty)
        #expect(results[0].year == 1)
        // Base withdrawal = $40,000
        #expect(results[0].withdrawalAmount == 40_000)
        // Year 1: no inflation adjustment yet (year-1 = 0 exponent)
        #expect(results[0].adjustedForInflation == 40_000)
        // Year 2 should be inflation-adjusted upward
        if results.count > 1 {
            let year2Adjusted = NSDecimalNumber(decimal: results[1].adjustedForInflation).doubleValue
            #expect(year2Adjusted > 40_000)
        }
    }

    @Test("safeWithdrawal: empty for zero portfolio")
    func safeWithdrawalZeroPortfolio() {
        let results = RetirementCalculator.safeWithdrawal(
            portfolio: 0,
            rate: Decimal(string: "0.04")!,
            inflationRate: Decimal(string: "0.03")!,
            years: 5
        )
        #expect(results.isEmpty)
    }

    // MARK: - contributionImpact

    @Test("contributionImpact: increasing contribution reduces years to FIRE")
    func contributionImpactReducesYears() {
        let impact = RetirementCalculator.contributionImpact(
            currentContribution: 20_000,
            increasePercent: Decimal(string: "0.50")!,
            currentPortfolio: 100_000,
            annualExpenses: 40_000,
            expectedReturn: Decimal(string: "0.07")!
        )
        #expect(impact.yearsSaved >= 0)
        #expect(impact.newYears <= impact.originalYears)
    }

    // MARK: - socialSecurityBreakeven

    @Test("socialSecurityBreakeven: standard 62/67/70 scenario")
    func socialSecurityBreakevenStandard() {
        let result = RetirementCalculator.socialSecurityBreakeven(
            age62Benefit: 1_500,
            age67Benefit: 2_100,
            age70Benefit: 2_600
        )
        // Delaying from 62 to 67 should break even somewhere around age 77-82
        #expect(result.delayTo67Breakeven > 67)
        #expect(result.delayTo67Breakeven <= 100)
        // Delaying from 62 to 70 should break even somewhere around age 80-85
        #expect(result.delayTo70Breakeven > 70)
        #expect(result.delayTo70Breakeven <= 100)
        // Delaying to 70 breakeven should be later than delaying to 67
        #expect(result.delayTo70Breakeven >= result.delayTo67Breakeven)
    }

    // MARK: - readinessScore

    @Test("readinessScore: well-funded scenario scores high")
    func readinessScoreHighFunding() {
        let score = RetirementCalculator.readinessScore(
            currentPortfolio: 800_000,
            annualContribution: 50_000,
            yearsToRetirement: 10,
            annualExpensesInRetirement: 40_000,
            expectedReturn: Decimal(string: "0.07")!,
            socialSecurityBenefit: nil
        )
        #expect(score >= 80)
        #expect(score <= 100)
    }

    @Test("readinessScore: underfunded scenario scores low")
    func readinessScoreLowFunding() {
        let score = RetirementCalculator.readinessScore(
            currentPortfolio: 10_000,
            annualContribution: 5_000,
            yearsToRetirement: 5,
            annualExpensesInRetirement: 60_000,
            expectedReturn: Decimal(string: "0.07")!,
            socialSecurityBenefit: nil
        )
        #expect(score >= 0)
        #expect(score < 30)
    }

    @Test("readinessScore: clamped to 0-100")
    func readinessScoreClamped() {
        // Massively overfunded
        let score = RetirementCalculator.readinessScore(
            currentPortfolio: 10_000_000,
            annualContribution: 100_000,
            yearsToRetirement: 20,
            annualExpensesInRetirement: 30_000,
            expectedReturn: Decimal(string: "0.07")!,
            socialSecurityBenefit: 20_000
        )
        #expect(score == 100)
    }

    @Test("readinessScore: zero expenses returns 0 (guard)")
    func readinessScoreZeroExpenses() {
        let score = RetirementCalculator.readinessScore(
            currentPortfolio: 500_000,
            annualContribution: 30_000,
            yearsToRetirement: 20,
            annualExpensesInRetirement: 0,
            expectedReturn: Decimal(string: "0.07")!,
            socialSecurityBenefit: nil
        )
        #expect(score == 0)
    }

    @Test("readinessScore: social security covers all expenses returns 100")
    func readinessScoreSSCoversAll() {
        let score = RetirementCalculator.readinessScore(
            currentPortfolio: 0,
            annualContribution: 0,
            yearsToRetirement: 10,
            annualExpensesInRetirement: 30_000,
            expectedReturn: Decimal(string: "0.07")!,
            socialSecurityBenefit: 30_000
        )
        // net expenses = 0, target = 0, guard target > 0 returns 100
        #expect(score == 100)
    }
}

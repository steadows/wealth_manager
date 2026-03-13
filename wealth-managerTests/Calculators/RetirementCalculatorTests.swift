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

    // MARK: - contributionLimits

    @Test("contributionLimits: age 45 — no catch-up")
    func contributionLimitsUnder50() {
        let limits = RetirementCalculator.contributionLimits(age: 45, year: 2025)
        #expect(limits.traditional401k == 23_500)
        #expect(limits.catchUp401k == 0)
        #expect(limits.ira == 7_000)
        #expect(limits.catchUpIra == 0)
    }

    @Test("contributionLimits: age 55 — catch-up eligible")
    func contributionLimitsAge55() {
        let limits = RetirementCalculator.contributionLimits(age: 55, year: 2025)
        #expect(limits.traditional401k == 23_500)
        #expect(limits.catchUp401k == 7_500)
        #expect(limits.ira == 7_000)
        #expect(limits.catchUpIra == 1_000)
    }

    @Test("contributionLimits: age 73 — still eligible with catch-up")
    func contributionLimitsAge73() {
        let limits = RetirementCalculator.contributionLimits(age: 73, year: 2025)
        #expect(limits.traditional401k == 23_500)
        #expect(limits.catchUp401k == 7_500)
        #expect(limits.ira == 7_000)
        #expect(limits.catchUpIra == 1_000)
    }

    // MARK: - requiredMinimumDistribution

    @Test("requiredMinimumDistribution: age 70 returns 0 (not required yet)")
    func rmdAge70ReturnsZero() {
        let rmd = RetirementCalculator.requiredMinimumDistribution(
            accountBalance: 500_000,
            age: 70
        )
        #expect(rmd == 0)
    }

    @Test("requiredMinimumDistribution: age 73 with $500k balance")
    func rmdAge73() {
        let rmd = RetirementCalculator.requiredMinimumDistribution(
            accountBalance: 500_000,
            age: 73
        )
        // $500,000 / 26.5 ≈ $18,867.92
        let rmdDouble = NSDecimalNumber(decimal: rmd).doubleValue
        #expect(rmdDouble > 18_000)
        #expect(rmdDouble < 20_000)
    }

    @Test("requiredMinimumDistribution: age 80")
    func rmdAge80() {
        let rmd = RetirementCalculator.requiredMinimumDistribution(
            accountBalance: 500_000,
            age: 80
        )
        // $500,000 / 20.2 ≈ $24,752
        let rmdDouble = NSDecimalNumber(decimal: rmd).doubleValue
        #expect(rmdDouble > 24_000)
        #expect(rmdDouble < 26_000)
    }

    // MARK: - socialSecurityEstimate

    @Test("socialSecurityEstimate: claim at 62 = ~70% of FRA benefit")
    func ssEstimateAge62() {
        let benefit = RetirementCalculator.socialSecurityEstimate(
            fullRetirementBenefit: 2_000,
            claimingAge: 62
        )
        let benefitDouble = NSDecimalNumber(decimal: benefit).doubleValue
        // Should be approximately 70% = $1,400
        #expect(benefitDouble >= 1_350)
        #expect(benefitDouble <= 1_450)
    }

    @Test("socialSecurityEstimate: claim at 67 = 100% of FRA benefit")
    func ssEstimateAge67() {
        let benefit = RetirementCalculator.socialSecurityEstimate(
            fullRetirementBenefit: 2_000,
            claimingAge: 67
        )
        #expect(benefit == 2_000)
    }

    @Test("socialSecurityEstimate: claim at 70 = 124% of FRA benefit")
    func ssEstimateAge70() {
        let benefit = RetirementCalculator.socialSecurityEstimate(
            fullRetirementBenefit: 2_000,
            claimingAge: 70
        )
        // +8%/year × 3 years = +24% → $2,480
        #expect(benefit == Decimal(string: "2480")!)
    }

    @Test("socialSecurityEstimate: claimingAge below 62 is clamped to 62")
    func ssEstimateAgeBelowMinimum() {
        let benefit62 = RetirementCalculator.socialSecurityEstimate(
            fullRetirementBenefit: 2_000,
            claimingAge: 62
        )
        let benefitBelow = RetirementCalculator.socialSecurityEstimate(
            fullRetirementBenefit: 2_000,
            claimingAge: 55
        )
        // Both should be equal — clamped to age 62 behavior
        #expect(benefitBelow == benefit62)
    }
}

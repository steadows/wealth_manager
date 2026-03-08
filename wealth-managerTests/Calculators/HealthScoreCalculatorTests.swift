import Testing
import Foundation

@testable import wealth_manager

// MARK: - HealthScoreCalculatorTests

@Suite("HealthScoreCalculator")
struct HealthScoreCalculatorTests {

    // MARK: - calculate (composite)

    @Test("calculate: all perfect inputs yields high score")
    func calculateAllPerfect() {
        let result = HealthScoreCalculator.calculate(
            monthlySavingsRate: Decimal(string: "0.20")!,
            debtToIncomeRatio: Decimal(string: "0.10")!,
            investmentDiversification: 1,
            investmentGrowthRate: Decimal(string: "0.10")!,
            emergencyFundMonths: 6,
            hasAdequateInsurance: true
        )
        // All components at 100: 100*0.25 + 100*0.25 + 100*0.20 + 100*0.20 + 100*0.10 = 100
        #expect(result.overallScore == 100)
        #expect(result.savingsScore == 100)
        #expect(result.debtScore == 100)
        #expect(result.investmentScore == 100)
        #expect(result.emergencyFundScore == 100)
        #expect(result.insuranceScore == 100)
    }

    @Test("calculate: all bad inputs yields near 0")
    func calculateAllBad() {
        let result = HealthScoreCalculator.calculate(
            monthlySavingsRate: 0,
            debtToIncomeRatio: Decimal(string: "0.50")!,
            investmentDiversification: 0,
            emergencyFundMonths: 0,
            hasAdequateInsurance: false
        )
        #expect(result.overallScore == 0)
        #expect(result.savingsScore == 0)
        #expect(result.debtScore == 0)
        #expect(result.investmentScore == 0)
        #expect(result.emergencyFundScore == 0)
        #expect(result.insuranceScore == 0)
    }

    @Test("calculate: mixed inputs produce intermediate score")
    func calculateMixed() {
        let result = HealthScoreCalculator.calculate(
            monthlySavingsRate: Decimal(string: "0.10")!,   // 50% of max
            debtToIncomeRatio: Decimal(string: "0.35")!,    // midpoint = 50%
            investmentDiversification: Decimal(string: "0.5")!,
            emergencyFundMonths: 3,                          // 50% of max
            hasAdequateInsurance: true
        )
        #expect(result.overallScore > 30)
        #expect(result.overallScore < 70)
    }

    // MARK: - Component scores

    @Test("savingsScore: 20% yields 100")
    func savingsScoreMax() {
        #expect(HealthScoreCalculator.savingsScore(rate: Decimal(string: "0.20")!) == 100)
    }

    @Test("savingsScore: 0% yields 0")
    func savingsScoreZero() {
        #expect(HealthScoreCalculator.savingsScore(rate: 0) == 0)
    }

    @Test("savingsScore: 10% yields ~50")
    func savingsScoreMid() {
        let score = HealthScoreCalculator.savingsScore(rate: Decimal(string: "0.10")!)
        #expect(score == 50)
    }

    @Test("savingsScore: above 20% still yields 100")
    func savingsScoreAboveMax() {
        #expect(HealthScoreCalculator.savingsScore(rate: Decimal(string: "0.50")!) == 100)
    }

    @Test("debtScore: below 20% DTI yields 100")
    func debtScoreLowDTI() {
        #expect(HealthScoreCalculator.debtScore(dtiRatio: Decimal(string: "0.10")!) == 100)
    }

    @Test("debtScore: above 50% DTI yields 0")
    func debtScoreHighDTI() {
        #expect(HealthScoreCalculator.debtScore(dtiRatio: Decimal(string: "0.60")!) == 0)
    }

    @Test("debtScore: 35% DTI yields ~50")
    func debtScoreMidDTI() {
        let score = HealthScoreCalculator.debtScore(dtiRatio: Decimal(string: "0.35")!)
        #expect(score == 50)
    }

    @Test("emergencyFundScore: 6 months yields 100")
    func emergencyScoreMax() {
        #expect(HealthScoreCalculator.emergencyFundScore(months: 6) == 100)
    }

    @Test("emergencyFundScore: 0 months yields 0")
    func emergencyScoreZero() {
        #expect(HealthScoreCalculator.emergencyFundScore(months: 0) == 0)
    }

    @Test("emergencyFundScore: 3 months yields 50")
    func emergencyScoreMid() {
        #expect(HealthScoreCalculator.emergencyFundScore(months: 3) == 50)
    }

    @Test("investmentScore: full diversification with zero growth")
    func investmentScoreFullDivers() {
        let score = HealthScoreCalculator.investmentScore(diversification: 1, growthRate: 0)
        // 100 * 0.7 + 0 * 0.3 = 70
        #expect(score == 70)
    }

    @Test("investmentScore: full diversification and 10% growth yields 100")
    func investmentScoreMaxBoth() {
        let score = HealthScoreCalculator.investmentScore(
            diversification: 1,
            growthRate: Decimal(string: "0.10")!
        )
        #expect(score == 100)
    }

    @Test("insuranceScore: all three types yields 100")
    func insuranceScoreAllTypes() {
        let score = HealthScoreCalculator.insuranceScore(
            hasLife: true,
            hasDisability: true,
            hasHealth: true
        )
        #expect(score == 100)
    }

    @Test("insuranceScore: health only yields 50")
    func insuranceScoreHealthOnly() {
        let score = HealthScoreCalculator.insuranceScore(
            hasLife: false,
            hasDisability: false,
            hasHealth: true
        )
        #expect(score == 50)
    }

    @Test("insuranceScore: none yields 0")
    func insuranceScoreNone() {
        let score = HealthScoreCalculator.insuranceScore(
            hasLife: false,
            hasDisability: false,
            hasHealth: false
        )
        #expect(score == 0)
    }

    // MARK: - Weight verification

    @Test("Weights sum to 1.0 — all perfect components yield 100")
    func weightsSum() {
        // savingsWeight(0.25) + debtWeight(0.25) + investmentWeight(0.20) + emergencyWeight(0.20) + insuranceWeight(0.10) = 1.0
        // With all components at 100: 100*0.25 + 100*0.25 + 100*0.20 + 100*0.20 + 100*0.10 = 100
        let result = HealthScoreCalculator.calculate(
            monthlySavingsRate: Decimal(string: "0.20")!,
            debtToIncomeRatio: 0,
            investmentDiversification: 1,
            investmentGrowthRate: Decimal(string: "0.10")!,
            emergencyFundMonths: 6,
            hasAdequateInsurance: true
        )
        #expect(result.overallScore == 100)
    }
}

import Testing
import Foundation

@testable import wealth_manager

// MARK: - InsuranceCalculatorTests

@Suite("InsuranceCalculator")
struct InsuranceCalculatorTests {

    // MARK: - DIME Method

    @Test("lifeInsuranceNeed: DIME method with known inputs")
    func dimeMethodKnown() {
        let result = InsuranceCalculator.lifeInsuranceNeed(
            totalDebt: 20_000,
            annualIncome: 80_000,
            yearsToReplace: 10,
            mortgageBalance: 250_000,
            educationCosts: 100_000,
            existingCoverage: 200_000
        )
        // D: 20,000 + I: 800,000 + M: 250,000 + E: 100,000 = 1,170,000
        #expect(result.totalNeed == 1_170_000)
        // Gap = 1,170,000 - 200,000 = 970,000
        #expect(result.gap == 970_000)
    }

    @Test("lifeInsuranceNeed: no gap when fully covered")
    func dimeMethodFullyCovered() {
        let result = InsuranceCalculator.lifeInsuranceNeed(
            totalDebt: 10_000,
            annualIncome: 50_000,
            yearsToReplace: 5,
            mortgageBalance: 100_000,
            educationCosts: 50_000,
            existingCoverage: 500_000
        )
        // Total need = 10K + 250K + 100K + 50K = 410K
        #expect(result.totalNeed == 410_000)
        #expect(result.gap == 0)
    }

    @Test("lifeInsuranceNeed: zero years to replace")
    func dimeMethodZeroYears() {
        let result = InsuranceCalculator.lifeInsuranceNeed(
            totalDebt: 10_000,
            annualIncome: 80_000,
            yearsToReplace: 0,
            mortgageBalance: 200_000,
            educationCosts: 0,
            existingCoverage: 0
        )
        // D: 10K + I: 0 + M: 200K + E: 0 = 210K
        #expect(result.totalNeed == 210_000)
        #expect(result.gap == 210_000)
    }

    // MARK: - Emergency Fund Adequacy

    @Test("emergencyFundAdequacy: 3 months savings / 6 month target")
    func emergencyFundAdequacy3Months() {
        let result = InsuranceCalculator.emergencyFundAdequacy(
            liquidSavings: 15_000,
            monthlyExpenses: 5_000
        )
        #expect(result.monthsCovered == 3)
        #expect(result.targetMonths == 6)
        // Shortfall = 6 * 5000 - 15000 = 15000
        #expect(result.shortfall == 15_000)
    }

    @Test("emergencyFundAdequacy: fully funded")
    func emergencyFundFullyFunded() {
        let result = InsuranceCalculator.emergencyFundAdequacy(
            liquidSavings: 30_000,
            monthlyExpenses: 5_000
        )
        #expect(result.monthsCovered == 6)
        #expect(result.shortfall == 0)
    }

    @Test("emergencyFundAdequacy: overfunded shows zero shortfall")
    func emergencyFundOverfunded() {
        let result = InsuranceCalculator.emergencyFundAdequacy(
            liquidSavings: 60_000,
            monthlyExpenses: 5_000
        )
        #expect(result.monthsCovered == 12)
        #expect(result.shortfall == 0)
    }

    @Test("emergencyFundAdequacy: zero expenses with savings")
    func emergencyFundZeroExpenses() {
        let result = InsuranceCalculator.emergencyFundAdequacy(
            liquidSavings: 10_000,
            monthlyExpenses: 0
        )
        // Zero expenses: monthsCovered should be large, shortfall 0
        #expect(result.shortfall == 0)
        #expect(result.targetMonths == 6)
    }

    @Test("emergencyFundAdequacy: zero savings")
    func emergencyFundZeroSavings() {
        let result = InsuranceCalculator.emergencyFundAdequacy(
            liquidSavings: 0,
            monthlyExpenses: 4_000
        )
        #expect(result.monthsCovered == 0)
        #expect(result.shortfall == 24_000)
    }

    // MARK: - Disability Coverage Gap

    @Test("disabilityCoverageGap: gap calculation")
    func disabilityCoverageGapBasic() {
        let result = InsuranceCalculator.disabilityCoverageGap(
            annualIncome: 100_000,
            existingCoverage: 40_000
        )
        // Recommended = 100K * 0.65 = 65K
        #expect(result.recommendedCoverage == 65_000)
        // Gap = 65K - 40K = 25K
        #expect(result.gap == 25_000)
    }

    @Test("disabilityCoverageGap: fully covered shows zero gap")
    func disabilityCoverageFullyCovered() {
        let result = InsuranceCalculator.disabilityCoverageGap(
            annualIncome: 100_000,
            existingCoverage: 80_000
        )
        #expect(result.recommendedCoverage == 65_000)
        #expect(result.gap == 0)
    }

    @Test("disabilityCoverageGap: no existing coverage")
    func disabilityCoverageNoCoverage() {
        let result = InsuranceCalculator.disabilityCoverageGap(
            annualIncome: 80_000,
            existingCoverage: 0
        )
        // Recommended = 80K * 0.65 = 52K
        #expect(result.recommendedCoverage == 52_000)
        #expect(result.gap == 52_000)
    }

    @Test("disabilityCoverageGap: zero income")
    func disabilityCoverageZeroIncome() {
        let result = InsuranceCalculator.disabilityCoverageGap(
            annualIncome: 0,
            existingCoverage: 10_000
        )
        #expect(result.recommendedCoverage == 0)
        #expect(result.gap == 0)
    }

    // MARK: - Estate Planning Checklist

    @Test("estatePlanningChecklist: all incomplete")
    func estatePlanningAllIncomplete() {
        let checklist = InsuranceCalculator.estatePlanningChecklist(
            hasWill: false,
            hasTrust: false,
            hasPOA: false,
            hasHealthcareDirective: false,
            hasBeneficiariesUpdated: false
        )
        #expect(checklist.count == 5)
        #expect(checklist.allSatisfy { !$0.isComplete })
    }

    @Test("estatePlanningChecklist: all complete")
    func estatePlanningAllComplete() {
        let checklist = InsuranceCalculator.estatePlanningChecklist(
            hasWill: true,
            hasTrust: true,
            hasPOA: true,
            hasHealthcareDirective: true,
            hasBeneficiariesUpdated: true
        )
        #expect(checklist.count == 5)
        #expect(checklist.allSatisfy { $0.isComplete })
    }

    @Test("estatePlanningChecklist: partial completion reflects correct items")
    func estatePlanningPartial() {
        let checklist = InsuranceCalculator.estatePlanningChecklist(
            hasWill: true,
            hasTrust: false,
            hasPOA: true,
            hasHealthcareDirective: false,
            hasBeneficiariesUpdated: false
        )
        // Will and POA are complete
        let willItem = checklist.first { $0.item == "Last Will & Testament" }
        let trustItem = checklist.first { $0.item == "Living Trust" }
        let poaItem = checklist.first { $0.item == "Power of Attorney" }
        let healthItem = checklist.first { $0.item == "Healthcare Directive" }
        let benefItem = checklist.first { $0.item == "Beneficiaries Updated" }

        #expect(willItem?.isComplete == true)
        #expect(trustItem?.isComplete == false)
        #expect(poaItem?.isComplete == true)
        #expect(healthItem?.isComplete == false)
        #expect(benefItem?.isComplete == false)
    }

    @Test("estatePlanningChecklist: priorities assigned correctly")
    func estatePlanningPriorities() {
        let checklist = InsuranceCalculator.estatePlanningChecklist(
            hasWill: false,
            hasTrust: false,
            hasPOA: false,
            hasHealthcareDirective: false,
            hasBeneficiariesUpdated: false
        )
        let willItem = checklist.first { $0.item == "Last Will & Testament" }
        let trustItem = checklist.first { $0.item == "Living Trust" }
        let poaItem = checklist.first { $0.item == "Power of Attorney" }
        let healthItem = checklist.first { $0.item == "Healthcare Directive" }
        let benefItem = checklist.first { $0.item == "Beneficiaries Updated" }

        #expect(willItem?.priority == "Critical")
        #expect(benefItem?.priority == "Critical")
        #expect(poaItem?.priority == "High")
        #expect(healthItem?.priority == "High")
        #expect(trustItem?.priority == "Recommended")
    }

    @Test("estatePlanningChecklist: Critical items appear before Recommended")
    func estatePlanningOrderedByPriority() {
        let checklist = InsuranceCalculator.estatePlanningChecklist(
            hasWill: false,
            hasTrust: false,
            hasPOA: false,
            hasHealthcareDirective: false,
            hasBeneficiariesUpdated: false
        )
        let priorities = checklist.map(\.priority)
        let criticalIndices = priorities.indices.filter { priorities[$0] == "Critical" }
        let recommendedIndices = priorities.indices.filter { priorities[$0] == "Recommended" }
        let maxCritical = criticalIndices.max() ?? -1
        let minRecommended = recommendedIndices.min() ?? Int.max
        #expect(maxCritical < minRecommended)
    }
}

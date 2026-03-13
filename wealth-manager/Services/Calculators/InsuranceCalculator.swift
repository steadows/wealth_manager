import Foundation

// MARK: - InsuranceCalculator

/// Pure calculator for insurance needs analysis, emergency fund adequacy,
/// and disability coverage gap assessment.
nonisolated struct InsuranceCalculator: Sendable {

    // MARK: - Constants

    /// Default emergency fund target in months of expenses.
    private static let defaultTargetMonths = 6

    /// Recommended disability coverage as a fraction of annual income (65%).
    private static let disabilityCoverageRate: Decimal = Decimal(string: "0.65")!

    // MARK: - Life Insurance (DIME Method)

    /// Calculate life insurance need using the DIME method.
    ///
    /// - **D**ebt: Total outstanding debt.
    /// - **I**ncome: Replacement income for surviving dependents.
    /// - **M**ortgage: Outstanding mortgage balance.
    /// - **E**ducation: Anticipated education costs for dependents.
    ///
    /// - Parameters:
    ///   - totalDebt: Total non-mortgage debt.
    ///   - annualIncome: Annual income to replace.
    ///   - yearsToReplace: Number of years of income replacement needed.
    ///   - mortgageBalance: Outstanding mortgage balance.
    ///   - educationCosts: Total anticipated education expenses.
    ///   - existingCoverage: Current life insurance coverage already in place.
    /// - Returns: A tuple of the total insurance need and the coverage gap.
    static func lifeInsuranceNeed(
        totalDebt: Decimal,
        annualIncome: Decimal,
        yearsToReplace: Int,
        mortgageBalance: Decimal,
        educationCosts: Decimal,
        existingCoverage: Decimal
    ) -> (totalNeed: Decimal, gap: Decimal) {
        let incomeReplacement = annualIncome * Decimal(max(yearsToReplace, 0))
        let totalNeed = max(totalDebt, 0)
            + incomeReplacement
            + max(mortgageBalance, 0)
            + max(educationCosts, 0)
        let gap = max(totalNeed - max(existingCoverage, 0), 0)
        return (totalNeed: totalNeed, gap: gap)
    }

    // MARK: - Emergency Fund

    /// Assess emergency fund adequacy relative to monthly expenses.
    ///
    /// - Parameters:
    ///   - liquidSavings: Current liquid savings available.
    ///   - monthlyExpenses: Average monthly expenses.
    /// - Returns: Months currently covered, target months (6), and any shortfall.
    static func emergencyFundAdequacy(
        liquidSavings: Decimal,
        monthlyExpenses: Decimal
    ) -> (monthsCovered: Decimal, targetMonths: Int, shortfall: Decimal) {
        guard monthlyExpenses > 0 else {
            return (
                monthsCovered: liquidSavings > 0 ? 999 : 0,
                targetMonths: defaultTargetMonths,
                shortfall: 0
            )
        }

        let safeSavings = max(liquidSavings, 0)
        let monthsCovered = safeSavings / monthlyExpenses
        let targetAmount = monthlyExpenses * Decimal(defaultTargetMonths)
        let shortfall = max(targetAmount - safeSavings, 0)

        return (
            monthsCovered: monthsCovered,
            targetMonths: defaultTargetMonths,
            shortfall: shortfall
        )
    }

    // MARK: - Disability Coverage

    /// Calculate the disability insurance coverage gap.
    ///
    /// Recommended coverage is 65% of annual income. The gap is
    /// the difference between the recommendation and existing coverage.
    ///
    /// - Parameters:
    ///   - annualIncome: Pre-disability annual income.
    ///   - existingCoverage: Annual disability benefit already in place.
    /// - Returns: The recommended coverage amount and the gap.
    static func disabilityCoverageGap(
        annualIncome: Decimal,
        existingCoverage: Decimal
    ) -> (recommendedCoverage: Decimal, gap: Decimal) {
        let recommended = max(annualIncome, 0) * disabilityCoverageRate
        let gap = max(recommended - max(existingCoverage, 0), 0)
        return (recommendedCoverage: recommended, gap: gap)
    }

    // MARK: - Estate Planning Checklist

    /// Build an ordered estate planning checklist with completion status and priorities.
    ///
    /// Priority levels: "Critical", "High", "Recommended".
    /// Items are ordered by decreasing priority.
    ///
    /// - Parameters:
    ///   - hasWill: Whether the user has a valid will.
    ///   - hasTrust: Whether the user has an established trust.
    ///   - hasPOA: Whether the user has a power of attorney.
    ///   - hasHealthcareDirective: Whether the user has a healthcare directive / living will.
    ///   - hasBeneficiariesUpdated: Whether all account beneficiaries are current.
    /// - Returns: An ordered array of checklist items with completion status and priority label.
    static func estatePlanningChecklist(
        hasWill: Bool,
        hasTrust: Bool,
        hasPOA: Bool,
        hasHealthcareDirective: Bool,
        hasBeneficiariesUpdated: Bool
    ) -> [(item: String, isComplete: Bool, priority: String)] {
        [
            (item: "Last Will & Testament", isComplete: hasWill, priority: "Critical"),
            (item: "Beneficiaries Updated", isComplete: hasBeneficiariesUpdated, priority: "Critical"),
            (item: "Power of Attorney", isComplete: hasPOA, priority: "High"),
            (item: "Healthcare Directive", isComplete: hasHealthcareDirective, priority: "High"),
            (item: "Living Trust", isComplete: hasTrust, priority: "Recommended"),
        ]
    }
}

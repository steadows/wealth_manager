import Foundation
import Observation

// MARK: - ProjectionService

/// Thin orchestration service that maps `UserProfile` fields to calculator inputs
/// and delegates to `NetWorthProjector` and `RetirementCalculator`.
@Observable final class ProjectionService {

    // MARK: - Defaults

    private static let defaultAnnualReturn: Decimal = Decimal(string: "0.07")!
    private static let defaultAnnualIncome: Decimal = 75_000
    private static let defaultYearsToRetirement: Int = 30
    private static let defaultMilestones: [Decimal] = [
        100_000, 250_000, 500_000, 1_000_000, 2_500_000, 5_000_000,
    ]

    // MARK: - Public API

    /// Generate multi-scenario net worth projections using the user's profile.
    ///
    /// - Parameters:
    ///   - profile: The user's profile for extracting savings and return assumptions.
    ///   - currentNetWorth: Current net worth value.
    ///   - years: Projection horizon in years.
    /// - Returns: Array of `ScenarioResult` (conservative, moderate, aggressive).
    func netWorthProjection(
        profile: UserProfile,
        currentNetWorth: Decimal,
        years: Int
    ) async -> [ScenarioResult] {
        let annualSavings = estimateAnnualSavings(from: profile)

        return NetWorthProjector.multiScenario(
            currentNetWorth: currentNetWorth,
            annualSavings: annualSavings,
            years: years
        )
    }

    /// Calculate retirement readiness as a FIRE result using the user's profile.
    ///
    /// - Parameters:
    ///   - profile: The user's profile.
    ///   - portfolio: Current investment portfolio value.
    ///   - annualContribution: Annual amount being contributed.
    /// - Returns: A `RetirementCalculator.FIREResult`.
    func retirementReadiness(
        profile: UserProfile,
        portfolio: Decimal,
        annualContribution: Decimal
    ) async -> RetirementCalculator.FIREResult {
        let annualExpenses = estimateAnnualExpenses(from: profile)
        let yearsToRetirement = profile.yearsToRetirement ?? Self.defaultYearsToRetirement
        let expectedReturn = returnForRiskTolerance(profile.riskTolerance)

        let target = RetirementCalculator.fireNumber(annualExpenses: annualExpenses)
        let years = RetirementCalculator.yearsToFIRE(
            currentPortfolio: portfolio,
            annualContribution: annualContribution,
            annualExpenses: annualExpenses,
            expectedReturn: expectedReturn
        )

        let monthlyNeeded = CompoundInterestCalculator.requiredMonthlyContribution(
            targetValue: target,
            currentValue: portfolio,
            annualRate: expectedReturn,
            years: yearsToRetirement
        )

        let projectedPortfolio = projectedPortfolioValue(
            currentPortfolio: portfolio,
            annualContribution: annualContribution,
            expectedReturn: expectedReturn,
            years: yearsToRetirement
        )
        let projectedIncome = projectedPortfolio * Decimal(string: "0.04")!

        return RetirementCalculator.FIREResult(
            fireNumber: target,
            yearsToFIRE: years,
            monthlyContributionNeeded: monthlyNeeded,
            projectedRetirementIncome: projectedIncome
        )
    }

    /// Calculate milestone dates for reaching key net worth targets.
    ///
    /// - Parameters:
    ///   - currentNetWorth: Current net worth.
    ///   - profile: The user's profile for return assumptions.
    /// - Returns: Array of tuples with milestone value and projected date.
    func milestones(
        currentNetWorth: Decimal,
        profile: UserProfile
    ) async -> [(milestone: Decimal, date: Date)] {
        let annualSavings = estimateAnnualSavings(from: profile)
        let expectedReturn = returnForRiskTolerance(profile.riskTolerance)

        let timeline = NetWorthProjector.milestoneTimeline(
            currentNetWorth: currentNetWorth,
            annualSavings: annualSavings,
            annualReturn: expectedReturn,
            milestones: Self.defaultMilestones
        )

        return timeline.map { (milestone: $0.milestone, date: $0.date) }
    }

    // MARK: - Private Helpers

    private func estimateAnnualSavings(from profile: UserProfile) -> Decimal {
        let income = profile.annualIncome ?? Self.defaultAnnualIncome
        let monthlyExpenses = profile.monthlyExpenses ?? (income / 12 * Decimal(string: "0.70")!)
        let annualExpenses = monthlyExpenses * 12
        return max(income - annualExpenses, 0)
    }

    private func estimateAnnualExpenses(from profile: UserProfile) -> Decimal {
        let income = profile.annualIncome ?? Self.defaultAnnualIncome
        let monthlyExpenses = profile.monthlyExpenses ?? (income / 12 * Decimal(string: "0.70")!)
        return monthlyExpenses * 12
    }

    private func returnForRiskTolerance(_ tolerance: RiskTolerance) -> Decimal {
        switch tolerance {
        case .conservative:
            return Decimal(string: "0.04")!
        case .moderate:
            return Decimal(string: "0.07")!
        case .aggressive:
            return Decimal(string: "0.10")!
        }
    }

    private func projectedPortfolioValue(
        currentPortfolio: Decimal,
        annualContribution: Decimal,
        expectedReturn: Decimal,
        years: Int
    ) -> Decimal {
        guard years > 0 else { return currentPortfolio }

        let lumpFV = CompoundInterestCalculator.futureValue(
            presentValue: currentPortfolio,
            annualRate: expectedReturn,
            years: years
        )
        let contribFV = CompoundInterestCalculator.futureValueWithContributions(
            monthlyContribution: annualContribution / 12,
            annualRate: expectedReturn,
            years: years
        )
        return lumpFV + contribFV
    }
}

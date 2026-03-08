import Foundation

// MARK: - HealthScoreCalculator

/// Pure calculator for composite financial health scoring.
/// Weights: savings 25%, debt 25%, investments 20%, emergency 20%, insurance 10%.
/// All component scores use piecewise linear interpolation clamped to 0-100.
nonisolated struct HealthScoreCalculator: Sendable {

    // MARK: - Weights

    private static let savingsWeight: Double = 0.25
    private static let debtWeight: Double = 0.25
    private static let investmentWeight: Double = 0.20
    private static let emergencyWeight: Double = 0.20
    private static let insuranceWeight: Double = 0.10

    // MARK: - Public API

    /// Calculate a composite financial health score from individual metrics.
    ///
    /// - Parameters:
    ///   - monthlySavingsRate: Savings as a fraction of income (e.g. 0.20 for 20%).
    ///   - debtToIncomeRatio: Monthly debt payments as a fraction of income.
    ///   - investmentDiversification: Diversification score from 0 to 1.
    ///   - emergencyFundMonths: Months of expenses covered by liquid savings.
    ///   - hasAdequateInsurance: Whether the user has adequate insurance coverage.
    /// - Returns: A `HealthScoreResult` with overall and component scores.
    static func calculate(
        monthlySavingsRate: Decimal,
        debtToIncomeRatio: Decimal,
        investmentDiversification: Decimal,
        investmentGrowthRate: Decimal = 0,
        emergencyFundMonths: Decimal,
        hasAdequateInsurance: Bool
    ) -> HealthScoreResult {
        let savings = savingsScore(rate: monthlySavingsRate)
        let debt = debtScore(dtiRatio: debtToIncomeRatio)
        let investment = investmentScore(diversification: investmentDiversification, growthRate: investmentGrowthRate)
        let emergency = emergencyFundScore(months: emergencyFundMonths)
        let insurance = hasAdequateInsurance ? 100 : 0

        let weighted = Double(savings) * savingsWeight
            + Double(debt) * debtWeight
            + Double(investment) * investmentWeight
            + Double(emergency) * emergencyWeight
            + Double(insurance) * insuranceWeight

        let overall = clampScore(Int(weighted.rounded()))

        return HealthScoreResult(
            overallScore: overall,
            savingsScore: savings,
            debtScore: debt,
            investmentScore: investment,
            emergencyFundScore: emergency,
            insuranceScore: insurance
        )
    }

    /// Score based on monthly savings rate. 20%+ = 100, 0% = 0, linear between.
    ///
    /// - Parameter rate: Savings rate as a decimal (e.g. 0.20 for 20%).
    /// - Returns: Score from 0 to 100.
    static func savingsScore(rate: Decimal) -> Int {
        clampScore(linearInterpolate(value: rate, floor: 0, ceiling: Decimal(string: "0.20")!))
    }

    /// Score based on debt-to-income ratio. < 20% = 100, > 50% = 0, linear between.
    ///
    /// - Parameter dtiRatio: Debt-to-income ratio as a decimal.
    /// - Returns: Score from 0 to 100.
    static func debtScore(dtiRatio: Decimal) -> Int {
        // Inverted: lower DTI is better
        let floor = Decimal(string: "0.20")!
        let ceiling = Decimal(string: "0.50")!

        if dtiRatio <= floor { return 100 }
        if dtiRatio >= ceiling { return 0 }

        let range = ceiling - floor
        let distance = dtiRatio - floor
        let ratio = toDouble(distance) / toDouble(range)
        return clampScore(Int(((1.0 - ratio) * 100.0).rounded()))
    }

    /// Score based on investment diversification and growth rate.
    ///
    /// - Parameters:
    ///   - diversification: Score from 0 to 1 based on asset class spread.
    ///   - growthRate: Portfolio growth rate (used as a secondary factor).
    /// - Returns: Score from 0 to 100.
    static func investmentScore(diversification: Decimal, growthRate: Decimal) -> Int {
        // Primary factor: diversification (70% weight), secondary: growth (30% weight)
        let diversScore = linearInterpolate(value: diversification, floor: 0, ceiling: 1)
        let growthScore = linearInterpolate(
            value: growthRate,
            floor: 0,
            ceiling: Decimal(string: "0.10")!
        )
        let combined = Double(diversScore) * 0.7 + Double(growthScore) * 0.3
        return clampScore(Int(combined.rounded()))
    }

    /// Score based on emergency fund coverage. 6+ months = 100, 0 months = 0, linear.
    ///
    /// - Parameter months: Number of months of expenses covered.
    /// - Returns: Score from 0 to 100.
    static func emergencyFundScore(months: Decimal) -> Int {
        clampScore(linearInterpolate(value: months, floor: 0, ceiling: 6))
    }

    /// Score based on insurance coverage types held.
    ///
    /// - Parameters:
    ///   - hasLife: Whether life insurance is held.
    ///   - hasDisability: Whether disability insurance is held.
    ///   - hasHealth: Whether health insurance is held.
    /// - Returns: Score from 0 to 100.
    static func insuranceScore(hasLife: Bool, hasDisability: Bool, hasHealth: Bool) -> Int {
        // Health: 50 points, Life: 30 points, Disability: 20 points
        var score = 0
        if hasHealth { score += 50 }
        if hasLife { score += 30 }
        if hasDisability { score += 20 }
        return clampScore(score)
    }

    // MARK: - Private Helpers

    private static func toDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    /// Linear interpolation: maps `value` in `[floor, ceiling]` to `[0, 100]`.
    private static func linearInterpolate(
        value: Decimal,
        floor: Decimal,
        ceiling: Decimal
    ) -> Int {
        guard ceiling > floor else { return 0 }
        if value <= floor { return 0 }
        if value >= ceiling { return 100 }

        let range = ceiling - floor
        let distance = value - floor
        let ratio = toDouble(distance) / toDouble(range)
        return Int((ratio * 100.0).rounded())
    }

    /// Clamp an integer score to the 0-100 range.
    private static func clampScore(_ score: Int) -> Int {
        min(max(score, 0), 100)
    }
}

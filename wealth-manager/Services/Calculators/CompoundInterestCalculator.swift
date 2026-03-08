import Foundation

// MARK: - CompoundInterestCalculator

/// Pure calculator for compound interest, future/present value, and contribution analysis.
/// All functions are stateless and use `Decimal` for monetary precision.
nonisolated struct CompoundInterestCalculator: Sendable {

    // MARK: - Private Helpers

    /// Raise a `Decimal` base to an integer exponent via `NSDecimalNumber`.
    private static func pow(_ base: Decimal, _ exponent: Int) -> Decimal {
        guard exponent >= 0 else { return 0 }
        guard exponent > 0 else { return 1 }
        return (base as NSDecimalNumber)
            .raising(toPower: exponent)
            .decimalValue
    }

    // MARK: - Public API

    /// Future value of a lump sum: `FV = PV * (1 + r/n)^(n*t)`.
    ///
    /// - Parameters:
    ///   - presentValue: Current lump-sum amount.
    ///   - annualRate: Annual interest rate as a decimal (e.g. 0.07 for 7%).
    ///   - years: Number of years to compound.
    ///   - compoundingPerYear: Compounding periods per year (default 12).
    /// - Returns: The future value, or `presentValue` when inputs make compounding inapplicable.
    static func futureValue(
        presentValue: Decimal,
        annualRate: Decimal,
        years: Int,
        compoundingPerYear: Int = 12
    ) -> Decimal {
        guard years > 0 else { return presentValue }
        guard compoundingPerYear > 0 else { return presentValue }
        guard annualRate != 0 else { return presentValue }

        let n = Decimal(compoundingPerYear)
        let ratePerPeriod = annualRate / n
        let totalPeriods = compoundingPerYear * years
        let growthFactor = pow(1 + ratePerPeriod, totalPeriods)
        return presentValue * growthFactor
    }

    /// Future value of a series of equal monthly contributions:
    /// `FV = PMT * (((1 + r/12)^(12*t) - 1) / (r/12))`.
    ///
    /// - Parameters:
    ///   - monthlyContribution: Amount contributed each month.
    ///   - annualRate: Annual interest rate as a decimal.
    ///   - years: Number of years of contributions.
    /// - Returns: The accumulated future value of contributions.
    static func futureValueWithContributions(
        monthlyContribution: Decimal,
        annualRate: Decimal,
        years: Int
    ) -> Decimal {
        guard years > 0, monthlyContribution != 0 else { return 0 }

        if annualRate == 0 {
            return monthlyContribution * Decimal(12 * years)
        }

        let monthlyRate = annualRate / 12
        let totalMonths = 12 * years
        let growthFactor = pow(1 + monthlyRate, totalMonths)
        return monthlyContribution * (growthFactor - 1) / monthlyRate
    }

    /// Present value needed today for a target future value:
    /// `PV = FV / (1 + r/12)^(12*t)`.
    ///
    /// - Parameters:
    ///   - futureValue: Desired future amount.
    ///   - annualRate: Annual interest rate as a decimal.
    ///   - years: Number of years until the future value is needed.
    /// - Returns: The present value, or `futureValue` when compounding is inapplicable.
    static func presentValue(
        futureValue: Decimal,
        annualRate: Decimal,
        years: Int
    ) -> Decimal {
        guard years > 0 else { return futureValue }
        guard annualRate != 0 else { return futureValue }

        let monthlyRate = annualRate / 12
        let totalMonths = 12 * years
        let growthFactor = pow(1 + monthlyRate, totalMonths)
        guard growthFactor != 0 else { return futureValue }
        return futureValue / growthFactor
    }

    /// Compound Annual Growth Rate: `CAGR = (endValue/startValue)^(1/years) - 1`.
    ///
    /// Uses Double internally for the fractional exponent, then converts back.
    ///
    /// - Parameters:
    ///   - startValue: Beginning value (must be positive).
    ///   - endValue: Ending value (must be positive).
    ///   - years: Time period in years (must be > 0).
    /// - Returns: The CAGR as a decimal, or 0 when inputs are invalid.
    static func cagr(startValue: Decimal, endValue: Decimal, years: Int) -> Decimal {
        guard years > 0, startValue > 0, endValue > 0 else { return 0 }

        let ratio = NSDecimalNumber(decimal: endValue / startValue).doubleValue
        let exponent = 1.0 / Double(years)
        let result = Foundation.pow(ratio, exponent) - 1.0

        guard result.isFinite else { return 0 }
        return Decimal(result)
    }

    /// Monthly contribution required to grow from `currentValue` to `targetValue`
    /// over the given number of years at a specified annual return.
    ///
    /// - Parameters:
    ///   - targetValue: The desired future amount.
    ///   - currentValue: Current portfolio / savings balance.
    ///   - annualRate: Expected annual return as a decimal.
    ///   - years: Time horizon in years.
    /// - Returns: The required monthly contribution, or 0 when the target is already met.
    static func requiredMonthlyContribution(
        targetValue: Decimal,
        currentValue: Decimal,
        annualRate: Decimal,
        years: Int
    ) -> Decimal {
        guard years > 0 else { return 0 }

        let fvOfCurrent = futureValue(
            presentValue: currentValue,
            annualRate: annualRate,
            years: years
        )
        let gap = targetValue - fvOfCurrent
        guard gap > 0 else { return 0 }

        if annualRate == 0 {
            let totalMonths = Decimal(12 * years)
            return gap / totalMonths
        }

        let monthlyRate = annualRate / 12
        let totalMonths = 12 * years
        let growthFactor = pow(1 + monthlyRate, totalMonths)
        let denominator = (growthFactor - 1) / monthlyRate
        guard denominator != 0 else { return 0 }
        return gap / denominator
    }
}

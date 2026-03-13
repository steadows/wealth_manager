import Foundation

// MARK: - RetirementCalculator

/// Pure calculator for FIRE analysis, safe withdrawal modeling, and retirement readiness.
/// Uses `CompoundInterestCalculator` for future value projections.
/// All functions are stateless and use `Decimal` for monetary precision.
nonisolated struct RetirementCalculator: Sendable {

    // MARK: - Types

    /// Result of a FIRE (Financial Independence, Retire Early) analysis.
    struct FIREResult: Sendable, Equatable {
        let fireNumber: Decimal
        let yearsToFIRE: Int?
        let monthlyContributionNeeded: Decimal
        let projectedRetirementIncome: Decimal
    }

    /// FIRE lifestyle variants affecting the target multiplier.
    enum FIREType: Sendable {
        case lean
        case regular
        case fat
    }

    // MARK: - Private Helpers

    private static let maxSimulationYears = 200

    /// Convert `Decimal` to `Double` for iterative math.
    private static func toDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    /// Convert `Double` back to `Decimal`.
    private static func toDecimal(_ value: Double) -> Decimal {
        guard value.isFinite else { return 0 }
        return Decimal(value)
    }

    // MARK: - Public API

    /// Calculate the FIRE number: the portfolio size needed to sustain annual expenses
    /// at a given withdrawal rate indefinitely.
    ///
    /// - Parameters:
    ///   - annualExpenses: Yearly spending target in retirement.
    ///   - withdrawalRate: Safe withdrawal rate (default 4%).
    /// - Returns: Required portfolio value, or 0 if inputs are invalid.
    static func fireNumber(
        annualExpenses: Decimal,
        withdrawalRate: Decimal = Decimal(string: "0.04")!
    ) -> Decimal {
        guard withdrawalRate > 0, annualExpenses >= 0 else { return 0 }
        return annualExpenses / withdrawalRate
    }

    /// Iterative year-by-year simulation to determine how many years until
    /// the portfolio reaches the FIRE number.
    ///
    /// - Parameters:
    ///   - currentPortfolio: Current invested amount.
    ///   - annualContribution: Amount added each year.
    ///   - annualExpenses: Target annual spending in retirement.
    ///   - expectedReturn: Annual return rate as a decimal.
    ///   - withdrawalRate: Safe withdrawal rate (default 4%).
    /// - Returns: Years to FIRE, or `nil` if already financially independent.
    static func yearsToFIRE(
        currentPortfolio: Decimal,
        annualContribution: Decimal,
        annualExpenses: Decimal,
        expectedReturn: Decimal,
        withdrawalRate: Decimal = Decimal(string: "0.04")!
    ) -> Int? {
        let target = fireNumber(annualExpenses: annualExpenses, withdrawalRate: withdrawalRate)
        guard target > 0 else { return nil }
        guard currentPortfolio < target else { return nil }

        var portfolio = toDouble(currentPortfolio)
        let contribution = toDouble(annualContribution)
        let returnRate = toDouble(expectedReturn)
        let targetDouble = toDouble(target)

        for year in 1...maxSimulationYears {
            portfolio = portfolio * (1.0 + returnRate) + contribution
            if portfolio >= targetDouble {
                return year
            }
        }

        // Cannot reach FIRE within simulation horizon
        return maxSimulationYears
    }

    /// Model safe withdrawals over a fixed number of years with inflation adjustment.
    ///
    /// - Parameters:
    ///   - portfolio: Starting portfolio value.
    ///   - rate: Annual withdrawal rate as a decimal (e.g. 0.04 for 4%).
    ///   - inflationRate: Annual inflation rate for adjusting withdrawals.
    ///   - years: Number of years to model.
    ///   - returnRate: Expected annual portfolio return rate (default 0.07 for 7%).
    /// - Returns: Array of `YearlyWithdrawal` entries.
    static func safeWithdrawal(
        portfolio: Decimal,
        rate: Decimal,
        inflationRate: Decimal,
        years: Int,
        returnRate: Decimal = Decimal(string: "0.07")!
    ) -> [YearlyWithdrawal] {
        guard portfolio > 0, rate > 0, years > 0 else { return [] }

        var remaining = toDouble(portfolio)
        let baseWithdrawal = toDouble(portfolio * rate)
        let inflation = toDouble(inflationRate)
        let annualReturn = toDouble(returnRate)
        var results: [YearlyWithdrawal] = []

        for year in 1...years {
            let inflationMultiplier = Foundation.pow(1.0 + inflation, Double(year - 1))
            let adjustedWithdrawal = baseWithdrawal * inflationMultiplier

            let actualWithdrawal = min(adjustedWithdrawal, max(remaining, 0))
            remaining -= actualWithdrawal
            remaining = max(remaining, 0)

            // Grow remaining portfolio at expected return rate
            remaining *= (1.0 + annualReturn)

            results.append(YearlyWithdrawal(
                year: year,
                withdrawalAmount: toDecimal(baseWithdrawal),
                adjustedForInflation: toDecimal(actualWithdrawal),
                remainingPortfolio: toDecimal(remaining)
            ))

            if remaining <= 0 { break }
        }

        return results
    }

    /// Calculate how many years earlier retirement occurs when contributions increase.
    ///
    /// - Parameters:
    ///   - currentContribution: Current annual contribution.
    ///   - increasePercent: Percentage increase (e.g. 0.10 for 10%).
    ///   - currentPortfolio: Current portfolio value.
    ///   - annualExpenses: Target annual spending in retirement.
    ///   - expectedReturn: Expected annual return rate.
    /// - Returns: Tuple of original years, new years, and years saved.
    static func contributionImpact(
        currentContribution: Decimal,
        increasePercent: Decimal,
        currentPortfolio: Decimal,
        annualExpenses: Decimal,
        expectedReturn: Decimal
    ) -> (originalYears: Int, newYears: Int, yearsSaved: Int) {
        let originalYears = yearsToFIRE(
            currentPortfolio: currentPortfolio,
            annualContribution: currentContribution,
            annualExpenses: annualExpenses,
            expectedReturn: expectedReturn
        ) ?? 0

        let newContribution = currentContribution * (1 + increasePercent)
        let newYears = yearsToFIRE(
            currentPortfolio: currentPortfolio,
            annualContribution: newContribution,
            annualExpenses: annualExpenses,
            expectedReturn: expectedReturn
        ) ?? 0

        return (
            originalYears: originalYears,
            newYears: newYears,
            yearsSaved: max(originalYears - newYears, 0)
        )
    }

    /// Calculate the age at which delaying Social Security benefits breaks even
    /// compared to claiming earlier.
    ///
    /// - Parameters:
    ///   - age62Benefit: Monthly benefit if claimed at 62.
    ///   - age67Benefit: Monthly benefit if claimed at 67.
    ///   - age70Benefit: Monthly benefit if claimed at 70.
    /// - Returns: Breakeven ages for delaying from 62 to 67 and from 62 to 70.
    static func socialSecurityBreakeven(
        age62Benefit: Decimal,
        age67Benefit: Decimal,
        age70Benefit: Decimal
    ) -> (delayTo67Breakeven: Int, delayTo70Breakeven: Int) {
        let breakeven67 = calculateBreakevenAge(
            earlyBenefit: age62Benefit,
            delayedBenefit: age67Benefit,
            earlyStartAge: 62,
            delayedStartAge: 67
        )
        let breakeven70 = calculateBreakevenAge(
            earlyBenefit: age62Benefit,
            delayedBenefit: age70Benefit,
            earlyStartAge: 62,
            delayedStartAge: 70
        )
        return (delayTo67Breakeven: breakeven67, delayTo70Breakeven: breakeven70)
    }

    /// Compute a retirement readiness score from 0 to 100.
    ///
    /// - Parameters:
    ///   - currentPortfolio: Current invested assets.
    ///   - annualContribution: Annual amount being saved.
    ///   - yearsToRetirement: Years until planned retirement.
    ///   - annualExpensesInRetirement: Expected yearly spending.
    ///   - expectedReturn: Expected annual return rate.
    ///   - socialSecurityBenefit: Optional annual Social Security income.
    /// - Returns: Integer score clamped between 0 and 100.
    static func readinessScore(
        currentPortfolio: Decimal,
        annualContribution: Decimal,
        yearsToRetirement: Int,
        annualExpensesInRetirement: Decimal,
        expectedReturn: Decimal,
        socialSecurityBenefit: Decimal?
    ) -> Int {
        guard annualExpensesInRetirement > 0, yearsToRetirement >= 0 else { return 0 }

        let projectedPortfolio = projectedValue(
            currentPortfolio: currentPortfolio,
            annualContribution: annualContribution,
            expectedReturn: expectedReturn,
            years: yearsToRetirement
        )

        let ssBenefit = socialSecurityBenefit ?? 0
        let netExpenses = max(annualExpensesInRetirement - ssBenefit, 0)
        let target = fireNumber(annualExpenses: netExpenses)

        guard target > 0 else { return 100 }

        let ratio = toDouble(projectedPortfolio) / toDouble(target)
        let score = Int((ratio * 100.0).rounded())
        return min(max(score, 0), 100)
    }

    // MARK: - Contribution Limits

    /// Returns IRS contribution limits for the given age and year.
    ///
    /// - Parameters:
    ///   - age: The contributor's age.
    ///   - year: The tax year (currently only 2025 limits are defined).
    /// - Returns: Tuple of traditional 401k, catch-up 401k, IRA, and IRA catch-up limits.
    static func contributionLimits(
        age: Int,
        year: Int
    ) -> (traditional401k: Decimal, catchUp401k: Decimal, ira: Decimal, catchUpIra: Decimal) {
        // 2025 IRS limits
        let base401k: Decimal = 23_500
        let catchUp401k: Decimal = age >= 50 ? 7_500 : 0
        let baseIra: Decimal = 7_000
        let catchUpIra: Decimal = age >= 50 ? 1_000 : 0
        return (traditional401k: base401k, catchUp401k: catchUp401k, ira: baseIra, catchUpIra: catchUpIra)
    }

    // MARK: - Required Minimum Distributions

    /// Computes the Required Minimum Distribution (RMD) for a given account balance and age.
    ///
    /// Uses IRS Uniform Lifetime Table divisors. Returns 0 for ages below 73.
    /// Extrapolates linearly for ages above 80 (divisor decreases ~0.9/year).
    ///
    /// - Parameters:
    ///   - accountBalance: The total balance in the retirement account.
    ///   - age: The account owner's age.
    /// - Returns: The required minimum distribution amount, or 0 if not yet required.
    static func requiredMinimumDistribution(
        accountBalance: Decimal,
        age: Int
    ) -> Decimal {
        guard age >= 73 else { return 0 }
        guard accountBalance > 0 else { return 0 }

        let divisor = rmdDivisor(for: age)
        guard divisor > 0 else { return 0 }
        return accountBalance / Decimal(divisor)
    }

    // MARK: - Social Security Estimate

    /// Estimates a Social Security monthly benefit based on claiming age relative to FRA (67).
    ///
    /// - Parameters:
    ///   - fullRetirementBenefit: The benefit amount if claimed at FRA (age 67).
    ///   - claimingAge: The age at which benefits will be claimed (clamped to 62–70).
    /// - Returns: Adjusted monthly benefit as a `Decimal`.
    static func socialSecurityEstimate(
        fullRetirementBenefit: Decimal,
        claimingAge: Int
    ) -> Decimal {
        let effectiveAge = max(claimingAge, 62)
        let fra = 67

        if effectiveAge == fra {
            return fullRetirementBenefit
        }

        if effectiveAge > fra {
            // Delayed credits: +8%/year for each year beyond FRA (max age 70)
            let yearsDelayed = min(effectiveAge - fra, 3)
            let multiplier = Decimal(1) + Decimal(yearsDelayed) * Decimal(string: "0.08")!
            return fullRetirementBenefit * multiplier
        }

        // Early claiming: reduces benefit
        // Age 62 = 70% of FRA benefit
        // Reduction: -6.67%/yr for years before 65, -5%/yr for years 65-67
        let yearsEarly = fra - effectiveAge
        var reductionRate = Decimal(0)

        if effectiveAge < 65 {
            let yearsBefore65 = 65 - effectiveAge
            let yearsFrom65ToFRA = fra - 65  // always 2
            reductionRate = Decimal(yearsBefore65) * Decimal(string: "0.0667")!
                          + Decimal(yearsFrom65ToFRA) * Decimal(string: "0.05")!
        } else {
            // Between 65 and 67
            reductionRate = Decimal(yearsEarly) * Decimal(string: "0.05")!
        }

        let multiplier = Decimal(1) - reductionRate
        return fullRetirementBenefit * multiplier
    }

    // MARK: - Private RMD Helpers

    /// Returns the IRS Uniform Lifetime Table divisor for a given age.
    /// Ages 73–80 use tabulated values; ages above 80 use linear extrapolation.
    private static func rmdDivisor(for age: Int) -> Double {
        let table: [Int: Double] = [
            73: 26.5,
            74: 25.5,
            75: 24.6,
            76: 23.7,
            77: 22.9,
            78: 22.0,
            79: 21.1,
            80: 20.2,
        ]

        if let divisor = table[age] {
            return divisor
        }

        // Linear extrapolation for ages above 80 (~0.9/year decrease)
        let yearsAbove80 = age - 80
        let extrapolated = 20.2 - Double(yearsAbove80) * 0.9
        return max(extrapolated, 1.0)
    }

    // MARK: - Private Helpers

    private static func projectedValue(
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

    private static func calculateBreakevenAge(
        earlyBenefit: Decimal,
        delayedBenefit: Decimal,
        earlyStartAge: Int,
        delayedStartAge: Int
    ) -> Int {
        guard delayedBenefit > earlyBenefit, earlyBenefit > 0 else {
            return delayedStartAge
        }

        let earlyMonthly = toDouble(earlyBenefit)
        let delayedMonthly = toDouble(delayedBenefit)
        let delayMonths = (delayedStartAge - earlyStartAge) * 12
        var earlyCumulative = earlyMonthly * Double(delayMonths)
        var delayedCumulative = 0.0

        let maxAge = 100
        let monthsToSimulate = (maxAge - delayedStartAge) * 12

        for month in 1...monthsToSimulate {
            earlyCumulative += earlyMonthly
            delayedCumulative += delayedMonthly

            if delayedCumulative >= earlyCumulative {
                let ageInMonths = delayedStartAge * 12 + month
                return ageInMonths / 12
            }
        }

        return maxAge
    }
}

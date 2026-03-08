import Foundation

// MARK: - NetWorthProjector

/// Pure calculator for net worth projections, Monte Carlo simulation, milestones, and what-if analysis.
/// Uses `CompoundInterestCalculator` for deterministic projections and `Double` internally
/// for Monte Carlo performance, converting results back to `Decimal`.
nonisolated struct NetWorthProjector: Sendable {

    // MARK: - Private Helpers

    private static func toDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    private static func toDecimal(_ value: Double) -> Decimal {
        guard value.isFinite else { return 0 }
        return Decimal(value)
    }

    /// Box-Muller transform: generate a normally distributed random Double.
    private static func normalRandom(mean: Double, stddev: Double) -> Double {
        let u1 = Double.random(in: Double.ulpOfOne...1.0)
        let u2 = Double.random(in: Double.ulpOfOne...1.0)
        let z = (-2.0 * Foundation.log(u1)).squareRoot() * cos(2.0 * .pi * u2)
        return mean + stddev * z
    }

    // MARK: - Public API

    /// Linear projection of net worth over a given number of years, assuming
    /// annual savings are added and the portfolio grows at a fixed return rate.
    ///
    /// - Parameters:
    ///   - currentNetWorth: Starting net worth.
    ///   - annualSavings: Amount saved per year.
    ///   - annualReturn: Annual growth rate as a decimal.
    ///   - years: Projection horizon.
    /// - Returns: Array of `ProjectionPoint`, one per year including year 0.
    static func linearProjection(
        currentNetWorth: Decimal,
        annualSavings: Decimal,
        annualReturn: Decimal,
        years: Int
    ) -> [ProjectionPoint] {
        guard years >= 0 else { return [] }

        var points: [ProjectionPoint] = [
            ProjectionPoint(
                year: 0,
                netWorth: currentNetWorth,
                assets: max(currentNetWorth, 0),
                liabilities: currentNetWorth < 0 ? abs(currentNetWorth) : 0
            )
        ]

        var netWorth = toDouble(currentNetWorth)
        let savings = toDouble(annualSavings)
        let returnRate = toDouble(annualReturn)

        for year in 1...max(years, 0) {
            netWorth = netWorth * (1.0 + returnRate) + savings
            let nw = toDecimal(netWorth)
            points.append(ProjectionPoint(
                year: year,
                netWorth: nw,
                assets: max(nw, 0),
                liabilities: nw < 0 ? abs(nw) : 0
            ))
        }

        return points
    }

    /// Multi-scenario projection: conservative (4%), moderate (7%), aggressive (10%).
    ///
    /// - Parameters:
    ///   - currentNetWorth: Starting net worth.
    ///   - annualSavings: Amount saved per year.
    ///   - years: Projection horizon.
    /// - Returns: Three `ScenarioResult` entries.
    static func multiScenario(
        currentNetWorth: Decimal,
        annualSavings: Decimal,
        years: Int
    ) -> [ScenarioResult] {
        let scenarios: [(String, Decimal)] = [
            ("Conservative", Decimal(string: "0.04")!),
            ("Moderate", Decimal(string: "0.07")!),
            ("Aggressive", Decimal(string: "0.10")!),
        ]

        return scenarios.map { label, returnRate in
            let points = linearProjection(
                currentNetWorth: currentNetWorth,
                annualSavings: annualSavings,
                annualReturn: returnRate,
                years: years
            )
            let finalNW = points.last?.netWorth ?? currentNetWorth
            return ScenarioResult(label: label, points: points, finalNetWorth: finalNW)
        }
    }

    /// Monte Carlo simulation using random normal returns.
    /// Uses Double internally for performance, converts results to Decimal.
    ///
    /// - Parameters:
    ///   - currentNetWorth: Starting net worth.
    ///   - annualSavings: Amount saved per year.
    ///   - years: Projection horizon.
    ///   - runs: Number of simulation runs (default 1000).
    /// - Returns: `MonteCarloResult` with percentile bands and success rate.
    static func monteCarlo(
        currentNetWorth: Decimal,
        annualSavings: Decimal,
        years: Int,
        runs: Int = 1000
    ) -> MonteCarloResult {
        guard years > 0 else {
            return singlePointResult(currentNetWorth: currentNetWorth)
        }

        let startNW = toDouble(currentNetWorth)
        let savings = toDouble(annualSavings)
        let meanReturn = 0.07
        let stddev = 0.15
        let effectiveRuns = max(runs, 1)

        // Run simulations — each run produces yearly net worth values
        var allRuns = [[Double]](repeating: [Double](repeating: 0, count: years + 1), count: effectiveRuns)

        for run in 0..<effectiveRuns {
            allRuns[run][0] = startNW
            var nw = startNW
            for year in 1...years {
                let annualReturn = normalRandom(mean: meanReturn, stddev: stddev)
                nw = nw * (1.0 + annualReturn) + savings
                allRuns[run][year] = nw
            }
        }

        // Extract percentile bands
        let percentile10 = extractPercentile(allRuns: allRuns, percentile: 0.10, years: years)
        let percentile25 = extractPercentile(allRuns: allRuns, percentile: 0.25, years: years)
        let median = extractPercentile(allRuns: allRuns, percentile: 0.50, years: years)
        let percentile75 = extractPercentile(allRuns: allRuns, percentile: 0.75, years: years)
        let percentile90 = extractPercentile(allRuns: allRuns, percentile: 0.90, years: years)

        // Success rate: percentage of runs where final net worth > starting
        let successCount = allRuns.filter { $0[years] > startNW }.count
        let successRate = toDecimal(Double(successCount) / Double(effectiveRuns))

        return MonteCarloResult(
            percentile10: percentile10,
            percentile25: percentile25,
            median: median,
            percentile75: percentile75,
            percentile90: percentile90,
            successRate: successRate
        )
    }

    /// Calculate when specific net worth milestones will be reached.
    ///
    /// - Parameters:
    ///   - currentNetWorth: Starting net worth.
    ///   - annualSavings: Amount saved per year.
    ///   - annualReturn: Expected annual return rate.
    ///   - milestones: Target net worth values.
    /// - Returns: Array of tuples with milestone, years from now, and projected date.
    static func milestoneTimeline(
        currentNetWorth: Decimal,
        annualSavings: Decimal,
        annualReturn: Decimal,
        milestones: [Decimal]
    ) -> [(milestone: Decimal, yearsFromNow: Int, date: Date)] {
        guard !milestones.isEmpty else { return [] }

        let sorted = milestones.sorted()
        var results: [(milestone: Decimal, yearsFromNow: Int, date: Date)] = []
        let calendar = Calendar.current
        let now = Date()

        var netWorth = toDouble(currentNetWorth)
        let savings = toDouble(annualSavings)
        let returnRate = toDouble(annualReturn)
        let maxYears = 200
        var milestoneIndex = 0

        // Check milestones already achieved at year 0
        while milestoneIndex < sorted.count, netWorth >= toDouble(sorted[milestoneIndex]) {
            results.append((
                milestone: sorted[milestoneIndex],
                yearsFromNow: 0,
                date: now
            ))
            milestoneIndex += 1
        }

        for year in 1...maxYears {
            guard milestoneIndex < sorted.count else { break }
            netWorth = netWorth * (1.0 + returnRate) + savings

            while milestoneIndex < sorted.count, netWorth >= toDouble(sorted[milestoneIndex]) {
                let date = calendar.date(byAdding: .year, value: year, to: now) ?? now
                results.append((
                    milestone: sorted[milestoneIndex],
                    yearsFromNow: year,
                    date: date
                ))
                milestoneIndex += 1
            }
        }

        return results
    }

    /// What-if scenario analysis: apply an adjustment and project forward.
    ///
    /// - Parameters:
    ///   - currentNetWorth: Starting net worth.
    ///   - annualSavings: Baseline annual savings.
    ///   - annualReturn: Expected annual return rate.
    ///   - years: Projection horizon.
    ///   - adjustment: The what-if adjustment to apply.
    /// - Returns: Adjusted projection points.
    static func whatIf(
        currentNetWorth: Decimal,
        annualSavings: Decimal,
        annualReturn: Decimal,
        years: Int,
        adjustment: WhatIfAdjustment
    ) -> [ProjectionPoint] {
        switch adjustment {
        case .increaseSavings(let amount):
            return linearProjection(
                currentNetWorth: currentNetWorth,
                annualSavings: annualSavings + amount,
                annualReturn: annualReturn,
                years: years
            )

        case .payOffMortgage(let mortgageBalance):
            return linearProjection(
                currentNetWorth: currentNetWorth - mortgageBalance,
                annualSavings: annualSavings,
                annualReturn: annualReturn,
                years: years
            )

        case .sabbatical(let months):
            return projectWithSabbatical(
                currentNetWorth: currentNetWorth,
                annualSavings: annualSavings,
                annualReturn: annualReturn,
                years: years,
                sabbaticalMonths: months
            )

        case .sellRSUs(let rsuValue):
            return linearProjection(
                currentNetWorth: currentNetWorth + rsuValue,
                annualSavings: annualSavings,
                annualReturn: annualReturn,
                years: years
            )
        }
    }

    // MARK: - Private Helpers

    private static func singlePointResult(currentNetWorth: Decimal) -> MonteCarloResult {
        let point = [ProjectionPoint(
            year: 0,
            netWorth: currentNetWorth,
            assets: max(currentNetWorth, 0),
            liabilities: currentNetWorth < 0 ? abs(currentNetWorth) : 0
        )]
        return MonteCarloResult(
            percentile10: point,
            percentile25: point,
            median: point,
            percentile75: point,
            percentile90: point,
            successRate: 1
        )
    }

    private static func extractPercentile(
        allRuns: [[Double]],
        percentile: Double,
        years: Int
    ) -> [ProjectionPoint] {
        var points: [ProjectionPoint] = []

        for year in 0...years {
            let values = allRuns.map { $0[year] }.sorted()
            let index = min(Int((percentile * Double(values.count)).rounded()), values.count - 1)
            let nw = toDecimal(values[max(index, 0)])
            points.append(ProjectionPoint(
                year: year,
                netWorth: nw,
                assets: max(nw, 0),
                liabilities: nw < 0 ? abs(nw) : 0
            ))
        }

        return points
    }

    private static func projectWithSabbatical(
        currentNetWorth: Decimal,
        annualSavings: Decimal,
        annualReturn: Decimal,
        years: Int,
        sabbaticalMonths: Int
    ) -> [ProjectionPoint] {
        guard years > 0 else {
            return [ProjectionPoint(
                year: 0,
                netWorth: currentNetWorth,
                assets: max(currentNetWorth, 0),
                liabilities: currentNetWorth < 0 ? abs(currentNetWorth) : 0
            )]
        }

        let sabbaticalYears = max(sabbaticalMonths, 0) / 12
        let sabbaticalPartialMonths = max(sabbaticalMonths, 0) % 12

        var netWorth = toDouble(currentNetWorth)
        let savings = toDouble(annualSavings)
        let returnRate = toDouble(annualReturn)
        var points: [ProjectionPoint] = []

        let nw0 = toDecimal(netWorth)
        points.append(ProjectionPoint(
            year: 0,
            netWorth: nw0,
            assets: max(nw0, 0),
            liabilities: nw0 < 0 ? abs(nw0) : 0
        ))

        for year in 1...years {
            let isSabbaticalYear = year <= sabbaticalYears
            let isPartialSabbaticalYear = year == sabbaticalYears + 1 && sabbaticalPartialMonths > 0

            if isSabbaticalYear {
                // No savings during sabbatical, portfolio still grows
                netWorth = netWorth * (1.0 + returnRate)
            } else if isPartialSabbaticalYear {
                // Partial savings for the remainder of the year
                let activeFraction = Double(12 - sabbaticalPartialMonths) / 12.0
                netWorth = netWorth * (1.0 + returnRate) + savings * activeFraction
            } else {
                netWorth = netWorth * (1.0 + returnRate) + savings
            }

            let nw = toDecimal(netWorth)
            points.append(ProjectionPoint(
                year: year,
                netWorth: nw,
                assets: max(nw, 0),
                liabilities: nw < 0 ? abs(nw) : 0
            ))
        }

        return points
    }
}

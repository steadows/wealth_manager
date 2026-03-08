import Testing
import Foundation

@testable import wealth_manager

// MARK: - NetWorthProjectorTests

@Suite("NetWorthProjector")
struct NetWorthProjectorTests {

    // MARK: - linearProjection

    @Test("linearProjection: year-over-year growth increases")
    func linearProjectionGrowth() {
        let points = NetWorthProjector.linearProjection(
            currentNetWorth: 100_000,
            annualSavings: 20_000,
            annualReturn: Decimal(string: "0.07")!,
            years: 10
        )
        #expect(points.count == 11) // year 0 through 10
        #expect(points[0].year == 0)
        #expect(points[0].netWorth == 100_000)

        // Each year should be greater than the previous
        for i in 1..<points.count {
            #expect(points[i].netWorth > points[i - 1].netWorth)
        }
    }

    @Test("linearProjection: zero years returns single point")
    func linearProjectionZeroYears() {
        let points = NetWorthProjector.linearProjection(
            currentNetWorth: 100_000,
            annualSavings: 20_000,
            annualReturn: Decimal(string: "0.07")!,
            years: 0
        )
        #expect(points.count == 1)
        #expect(points[0].netWorth == 100_000)
    }

    @Test("linearProjection: negative years returns empty")
    func linearProjectionNegativeYears() {
        let points = NetWorthProjector.linearProjection(
            currentNetWorth: 100_000,
            annualSavings: 20_000,
            annualReturn: Decimal(string: "0.07")!,
            years: -1
        )
        #expect(points.isEmpty)
    }

    // MARK: - multiScenario

    @Test("multiScenario: conservative < moderate < aggressive")
    func multiScenarioOrdering() {
        let scenarios = NetWorthProjector.multiScenario(
            currentNetWorth: 100_000,
            annualSavings: 20_000,
            years: 20
        )
        #expect(scenarios.count == 3)
        #expect(scenarios[0].label == "Conservative")
        #expect(scenarios[1].label == "Moderate")
        #expect(scenarios[2].label == "Aggressive")
        #expect(scenarios[0].finalNetWorth < scenarios[1].finalNetWorth)
        #expect(scenarios[1].finalNetWorth < scenarios[2].finalNetWorth)
    }

    // MARK: - monteCarlo

    @Test("monteCarlo: percentile ordering (10th < 25th < 50th < 75th < 90th)")
    func monteCarloPercentileOrdering() {
        let result = NetWorthProjector.monteCarlo(
            currentNetWorth: 200_000,
            annualSavings: 30_000,
            years: 20,
            runs: 500
        )
        // At the final year, percentiles should generally be ordered
        let finalYear = 20
        let p10 = result.percentile10[finalYear].netWorth
        let p25 = result.percentile25[finalYear].netWorth
        let p50 = result.median[finalYear].netWorth
        let p75 = result.percentile75[finalYear].netWorth
        let p90 = result.percentile90[finalYear].netWorth

        #expect(p10 <= p25)
        #expect(p25 <= p50)
        #expect(p50 <= p75)
        #expect(p75 <= p90)
    }

    @Test("monteCarlo: initial year matches current net worth")
    func monteCarloInitialYear() {
        let result = NetWorthProjector.monteCarlo(
            currentNetWorth: 200_000,
            annualSavings: 30_000,
            years: 10,
            runs: 100
        )
        #expect(result.percentile10[0].netWorth == 200_000)
        #expect(result.median[0].netWorth == 200_000)
        #expect(result.percentile90[0].netWorth == 200_000)
    }

    @Test("monteCarlo: zero years returns single-point result")
    func monteCarloZeroYears() {
        let result = NetWorthProjector.monteCarlo(
            currentNetWorth: 100_000,
            annualSavings: 10_000,
            years: 0
        )
        #expect(result.median.count == 1)
        #expect(result.median[0].netWorth == 100_000)
        #expect(result.successRate == 1)
    }

    @Test("monteCarlo: success rate is between 0 and 1")
    func monteCarloSuccessRate() {
        let result = NetWorthProjector.monteCarlo(
            currentNetWorth: 100_000,
            annualSavings: 10_000,
            years: 10,
            runs: 200
        )
        let rateDouble = NSDecimalNumber(decimal: result.successRate).doubleValue
        #expect(rateDouble >= 0)
        #expect(rateDouble <= 1)
    }

    // MARK: - milestoneTimeline

    @Test("milestoneTimeline: chronological ordering")
    func milestoneTimelineOrdering() {
        let milestones: [Decimal] = [250_000, 500_000, 1_000_000]
        let timeline = NetWorthProjector.milestoneTimeline(
            currentNetWorth: 100_000,
            annualSavings: 30_000,
            annualReturn: Decimal(string: "0.07")!,
            milestones: milestones
        )
        #expect(!timeline.isEmpty)
        // Each milestone's yearsFromNow should be non-decreasing
        for i in 1..<timeline.count {
            #expect(timeline[i].yearsFromNow >= timeline[i - 1].yearsFromNow)
        }
    }

    @Test("milestoneTimeline: already-achieved milestones at year 0")
    func milestoneTimelineAlreadyAchieved() {
        let milestones: [Decimal] = [50_000, 100_000, 500_000]
        let timeline = NetWorthProjector.milestoneTimeline(
            currentNetWorth: 200_000,
            annualSavings: 20_000,
            annualReturn: Decimal(string: "0.07")!,
            milestones: milestones
        )
        // $50K and $100K are already achieved
        let achievedNow = timeline.filter { $0.yearsFromNow == 0 }
        #expect(achievedNow.count == 2)
    }

    @Test("milestoneTimeline: empty milestones returns empty")
    func milestoneTimelineEmpty() {
        let timeline = NetWorthProjector.milestoneTimeline(
            currentNetWorth: 100_000,
            annualSavings: 20_000,
            annualReturn: Decimal(string: "0.07")!,
            milestones: []
        )
        #expect(timeline.isEmpty)
    }

    // MARK: - whatIf

    @Test("whatIf: increaseSavings grows faster")
    func whatIfIncreaseSavings() {
        let baseline = NetWorthProjector.linearProjection(
            currentNetWorth: 100_000,
            annualSavings: 20_000,
            annualReturn: Decimal(string: "0.07")!,
            years: 10
        )
        let adjusted = NetWorthProjector.whatIf(
            currentNetWorth: 100_000,
            annualSavings: 20_000,
            annualReturn: Decimal(string: "0.07")!,
            years: 10,
            adjustment: .increaseSavings(10_000)
        )
        #expect(adjusted.last!.netWorth > baseline.last!.netWorth)
    }

    @Test("whatIf: payOffMortgage reduces initial net worth")
    func whatIfPayOffMortgage() {
        let adjusted = NetWorthProjector.whatIf(
            currentNetWorth: 500_000,
            annualSavings: 20_000,
            annualReturn: Decimal(string: "0.07")!,
            years: 10,
            adjustment: .payOffMortgage(200_000)
        )
        #expect(adjusted[0].netWorth == 300_000)
    }

    @Test("whatIf: sellRSUs increases initial net worth")
    func whatIfSellRSUs() {
        let adjusted = NetWorthProjector.whatIf(
            currentNetWorth: 100_000,
            annualSavings: 20_000,
            annualReturn: Decimal(string: "0.07")!,
            years: 10,
            adjustment: .sellRSUs(50_000)
        )
        #expect(adjusted[0].netWorth == 150_000)
    }

    @Test("whatIf: sabbatical reduces growth compared to baseline")
    func whatIfSabbatical() {
        let baseline = NetWorthProjector.linearProjection(
            currentNetWorth: 200_000,
            annualSavings: 40_000,
            annualReturn: Decimal(string: "0.07")!,
            years: 10
        )
        let adjusted = NetWorthProjector.whatIf(
            currentNetWorth: 200_000,
            annualSavings: 40_000,
            annualReturn: Decimal(string: "0.07")!,
            years: 10,
            adjustment: .sabbatical(months: 12)
        )
        #expect(adjusted.last!.netWorth < baseline.last!.netWorth)
    }
}

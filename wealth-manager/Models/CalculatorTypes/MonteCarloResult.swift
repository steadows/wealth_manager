import Foundation

nonisolated struct MonteCarloResult: Sendable {
    let percentile10: [ProjectionPoint]
    let percentile25: [ProjectionPoint]
    let median: [ProjectionPoint]
    let percentile75: [ProjectionPoint]
    let percentile90: [ProjectionPoint]
    let successRate: Decimal
}

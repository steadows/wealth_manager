import Foundation

nonisolated struct ScenarioResult: Sendable, Equatable {
    let label: String
    let points: [ProjectionPoint]
    let finalNetWorth: Decimal
}

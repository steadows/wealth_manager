import Foundation

nonisolated struct ProjectionPoint: Sendable, Equatable {
    let year: Int
    let netWorth: Decimal
    let assets: Decimal
    let liabilities: Decimal
}

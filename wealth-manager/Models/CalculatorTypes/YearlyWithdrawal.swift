import Foundation

nonisolated struct YearlyWithdrawal: Sendable, Equatable {
    let year: Int
    let withdrawalAmount: Decimal
    let adjustedForInflation: Decimal
    let remainingPortfolio: Decimal
}

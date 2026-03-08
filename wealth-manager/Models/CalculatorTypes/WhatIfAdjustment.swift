import Foundation

nonisolated enum WhatIfAdjustment: Sendable {
    case increaseSavings(Decimal)
    case payOffMortgage(Decimal)
    case sabbatical(months: Int)
    case sellRSUs(Decimal)
}

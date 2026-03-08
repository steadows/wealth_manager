import Foundation
import SwiftData

@Model
final class InvestmentHolding {
    @Attribute(.unique) var id: UUID
    var account: Account
    var securityName: String
    var tickerSymbol: String?
    var quantity: Decimal
    var costBasis: Decimal?
    var currentPrice: Decimal
    @Transient var currentValue: Decimal { quantity * currentPrice }
    var holdingType: HoldingType
    var assetClass: AssetClass
    var lastPriceUpdate: Date

    var gainLoss: Decimal? {
        guard let basis = costBasis else { return nil }
        return currentValue - (basis * quantity)
    }

    var gainLossPercent: Decimal? {
        guard let basis = costBasis, basis != 0 else { return nil }
        let totalCost = basis * quantity
        guard totalCost != 0 else { return nil }
        return (currentValue - totalCost) / totalCost
    }

    init(
        id: UUID = UUID(),
        account: Account,
        securityName: String,
        tickerSymbol: String? = nil,
        quantity: Decimal,
        costBasis: Decimal? = nil,
        currentPrice: Decimal,
        holdingType: HoldingType,
        assetClass: AssetClass,
        lastPriceUpdate: Date = Date()
    ) {
        self.id = id
        self.account = account
        self.securityName = securityName
        self.tickerSymbol = tickerSymbol
        self.quantity = quantity
        self.costBasis = costBasis
        self.currentPrice = currentPrice
        self.holdingType = holdingType
        self.assetClass = assetClass
        self.lastPriceUpdate = lastPriceUpdate
    }
}

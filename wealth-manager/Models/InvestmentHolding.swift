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
    var holdingTypeRawValue: String

    @Transient var holdingType: HoldingType {
        get { HoldingType(rawValue: holdingTypeRawValue) ?? .other }
        set { holdingTypeRawValue = newValue.rawValue }
    }

    var assetClassRawValue: String

    @Transient var assetClass: AssetClass {
        get { AssetClass(rawValue: assetClassRawValue) ?? .alternative }
        set { assetClassRawValue = newValue.rawValue }
    }
    var purchaseDate: Date?
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
        purchaseDate: Date? = nil,
        lastPriceUpdate: Date = Date()
    ) {
        self.id = id
        self.account = account
        self.securityName = securityName
        self.tickerSymbol = tickerSymbol
        self.quantity = quantity
        self.costBasis = costBasis
        self.currentPrice = currentPrice
        self.holdingTypeRawValue = holdingType.rawValue
        self.assetClassRawValue = assetClass.rawValue
        self.purchaseDate = purchaseDate
        self.lastPriceUpdate = lastPriceUpdate
    }
}

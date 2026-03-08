import Foundation
import SwiftData

@Model
final class NetWorthSnapshot {
    @Attribute(.unique) var id: UUID
    var date: Date
    var totalAssets: Decimal
    var totalLiabilities: Decimal

    @Transient var netWorth: Decimal { totalAssets - totalLiabilities }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        totalAssets: Decimal,
        totalLiabilities: Decimal
    ) {
        self.id = id
        self.date = date
        self.totalAssets = totalAssets
        self.totalLiabilities = totalLiabilities
    }
}

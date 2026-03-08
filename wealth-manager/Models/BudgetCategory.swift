import Foundation
import SwiftData

@Model
final class BudgetCategory {
    @Attribute(.unique) var id: UUID
    var category: TransactionCategory
    var monthlyLimit: Decimal
    var month: Int
    var year: Int
    var createdAt: Date
    var updatedAt: Date

    /// Placeholder: actual computation requires a transactions query via the repository layer.
    var percentUsed: Decimal {
        0
    }

    var isOverBudget: Bool {
        percentUsed > 1
    }

    init(
        id: UUID = UUID(),
        category: TransactionCategory,
        monthlyLimit: Decimal,
        month: Int,
        year: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.category = category
        self.monthlyLimit = monthlyLimit
        self.month = month
        self.year = year
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

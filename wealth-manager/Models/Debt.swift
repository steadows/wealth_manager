import Foundation
import SwiftData

@Model
final class Debt {
    @Attribute(.unique) var id: UUID
    var account: Account?
    var debtName: String
    var debtType: DebtType
    var originalBalance: Decimal
    var currentBalance: Decimal
    var interestRate: Decimal
    var minimumPayment: Decimal
    var payoffDate: Date?
    var isFixedRate: Bool
    var createdAt: Date
    var updatedAt: Date

    var monthlyInterest: Decimal {
        currentBalance * interestRate / 12
    }

    var payoffProgress: Decimal {
        guard originalBalance != 0 else { return 1 }
        return 1 - currentBalance / originalBalance
    }

    init(
        id: UUID = UUID(),
        account: Account? = nil,
        debtName: String,
        debtType: DebtType,
        originalBalance: Decimal,
        currentBalance: Decimal,
        interestRate: Decimal,
        minimumPayment: Decimal,
        payoffDate: Date? = nil,
        isFixedRate: Bool,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.account = account
        self.debtName = debtName
        self.debtType = debtType
        self.originalBalance = originalBalance
        self.currentBalance = currentBalance
        self.interestRate = interestRate
        self.minimumPayment = minimumPayment
        self.payoffDate = payoffDate
        self.isFixedRate = isFixedRate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

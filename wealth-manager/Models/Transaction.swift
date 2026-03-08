import Foundation
import SwiftData

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var plaidTransactionId: String?
    var account: Account
    var amount: Decimal
    var date: Date
    var merchantName: String?
    var category: TransactionCategory
    var subcategory: String?
    var note: String?
    var isRecurring: Bool = false
    var isPending: Bool = false
    var createdAt: Date

    init(
        id: UUID = UUID(),
        plaidTransactionId: String? = nil,
        account: Account,
        amount: Decimal,
        date: Date,
        merchantName: String? = nil,
        category: TransactionCategory,
        subcategory: String? = nil,
        note: String? = nil,
        isRecurring: Bool = false,
        isPending: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.plaidTransactionId = plaidTransactionId
        self.account = account
        self.amount = amount
        self.date = date
        self.merchantName = merchantName
        self.category = category
        self.subcategory = subcategory
        self.note = note
        self.isRecurring = isRecurring
        self.isPending = isPending
        self.createdAt = createdAt
    }
}

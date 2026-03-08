import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var plaidAccountId: String?
    var institutionName: String
    var accountName: String
    var accountType: AccountType
    var currentBalance: Decimal
    var availableBalance: Decimal?
    var currency: String = "USD"
    var isManual: Bool
    var isHidden: Bool = false
    var lastSyncedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Transaction.account)
    var transactions: [Transaction] = []

    @Relationship(deleteRule: .cascade, inverse: \InvestmentHolding.account)
    var holdings: [InvestmentHolding] = []

    var isAsset: Bool {
        switch accountType {
        case .checking, .savings, .investment, .retirement:
            return true
        default:
            return false
        }
    }

    var isLiability: Bool {
        switch accountType {
        case .creditCard, .loan:
            return true
        default:
            return false
        }
    }

    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: currentBalance as NSDecimalNumber) ?? "$0.00"
    }

    init(
        id: UUID = UUID(),
        plaidAccountId: String? = nil,
        institutionName: String,
        accountName: String,
        accountType: AccountType,
        currentBalance: Decimal,
        availableBalance: Decimal? = nil,
        currency: String = "USD",
        isManual: Bool,
        isHidden: Bool = false,
        lastSyncedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        transactions: [Transaction] = [],
        holdings: [InvestmentHolding] = []
    ) {
        self.id = id
        self.plaidAccountId = plaidAccountId
        self.institutionName = institutionName
        self.accountName = accountName
        self.accountType = accountType
        self.currentBalance = currentBalance
        self.availableBalance = availableBalance
        self.currency = currency
        self.isManual = isManual
        self.isHidden = isHidden
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.transactions = transactions
        self.holdings = holdings
    }
}

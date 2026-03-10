import Foundation
import SwiftData

@ModelActor
actor SwiftDataAccountRepository: AccountRepository {

    func fetchAll() async throws -> [Account] {
        let descriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.institutionName)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchById(_ id: UUID) async throws -> Account? {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchByType(_ type: AccountType) async throws -> [Account] {
        let rawType = type.rawValue
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.accountTypeRawValue == rawType },
            sortBy: [SortDescriptor(\.institutionName)]
        )
        return try modelContext.fetch(descriptor)
    }

    func create(_ account: Account) async throws {
        modelContext.insert(account)
        try modelContext.save()
    }

    func update(_ account: Account) async throws {
        try modelContext.save()
    }

    func delete(_ account: Account) async throws {
        modelContext.delete(account)
        try modelContext.save()
    }

    func upsert(_ account: Account) async throws {
        let id = account.id
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.id == id }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.institutionName = account.institutionName
            existing.accountName = account.accountName
            existing.accountTypeRawValue = account.accountTypeRawValue
            existing.currentBalance = account.currentBalance
            existing.availableBalance = account.availableBalance
            existing.currency = account.currency
            existing.isManual = account.isManual
            existing.isHidden = account.isHidden
            existing.lastSyncedAt = account.lastSyncedAt
            existing.updatedAt = account.updatedAt
        } else {
            modelContext.insert(account)
        }
        try modelContext.save()
    }

    func totalAssets() async throws -> Decimal {
        let assetTypes: Set<String> = [
            AccountType.checking.rawValue,
            AccountType.savings.rawValue,
            AccountType.investment.rawValue,
            AccountType.retirement.rawValue
        ]
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { assetTypes.contains($0.accountTypeRawValue) }
        )
        let accounts = try modelContext.fetch(descriptor)
        return accounts.reduce(Decimal.zero) { $0 + $1.currentBalance }
    }

    func totalLiabilities() async throws -> Decimal {
        let liabilityTypes: Set<String> = [
            AccountType.creditCard.rawValue,
            AccountType.loan.rawValue
        ]
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { liabilityTypes.contains($0.accountTypeRawValue) }
        )
        let accounts = try modelContext.fetch(descriptor)
        return accounts.reduce(Decimal.zero) { $0 + $1.currentBalance }
    }
}

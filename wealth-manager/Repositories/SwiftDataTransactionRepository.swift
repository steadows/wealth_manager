import Foundation
import SwiftData

@ModelActor
actor SwiftDataTransactionRepository: TransactionRepository {

    func fetchAll() async throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchById(_ id: UUID) async throws -> Transaction? {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchByAccount(_ accountId: UUID) async throws -> [Transaction] {
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.account.id == accountId },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByDateRange(_ range: ClosedRange<Date>) async throws -> [Transaction] {
        let start = range.lowerBound
        let end = range.upperBound
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.date >= start && $0.date <= end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByCategory(_ category: TransactionCategory) async throws -> [Transaction] {
        let rawCategory = category.rawValue
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.categoryRawValue == rawCategory },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchRecent(limit: Int) async throws -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    func fetchByAccount(_ accountId: UUID, limit: Int, offset: Int) async throws -> [Transaction] {
        var descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.account.id == accountId },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return try modelContext.fetch(descriptor)
    }

    func create(_ transaction: Transaction) async throws {
        modelContext.insert(transaction)
        try modelContext.save()
    }

    func update(_ transaction: Transaction) async throws {
        try modelContext.save()
    }

    func delete(_ transaction: Transaction) async throws {
        modelContext.delete(transaction)
        try modelContext.save()
    }
}

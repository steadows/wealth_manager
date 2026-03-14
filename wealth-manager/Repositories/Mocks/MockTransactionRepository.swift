import Foundation

final class MockTransactionRepository: TransactionRepository {
    var items: [Transaction] = []

    func fetchAll() async throws -> [Transaction] {
        items
    }

    func fetchById(_ id: UUID) async throws -> Transaction? {
        items.first { $0.id == id }
    }

    func fetchByAccount(_ accountId: UUID) async throws -> [Transaction] {
        items.filter { $0.account.id == accountId }
    }

    func fetchByDateRange(_ range: ClosedRange<Date>) async throws -> [Transaction] {
        items.filter { range.contains($0.date) }
    }

    func fetchByCategory(_ category: TransactionCategory) async throws -> [Transaction] {
        items.filter { $0.category == category }
    }

    func fetchRecent(limit: Int) async throws -> [Transaction] {
        Array(
            items
                .sorted { $0.date > $1.date }
                .prefix(limit)
        )
    }

    func fetchByAccount(_ accountId: UUID, limit: Int, offset: Int) async throws -> [Transaction] {
        let filtered = items
            .filter { $0.account.id == accountId }
            .sorted { $0.date > $1.date }
        let start = min(offset, filtered.count)
        let end = min(start + limit, filtered.count)
        return Array(filtered[start..<end])
    }

    func create(_ transaction: Transaction) async throws {
        items.append(transaction)
    }

    func update(_ transaction: Transaction) async throws {
        guard let index = items.firstIndex(where: { $0.id == transaction.id }) else {
            throw RepositoryError.notFound(transaction.id)
        }
        items[index] = transaction
    }

    func delete(_ transaction: Transaction) async throws {
        items.removeAll { $0.id == transaction.id }
    }
}

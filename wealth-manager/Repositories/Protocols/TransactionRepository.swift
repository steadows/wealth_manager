import Foundation

protocol TransactionRepository {
    func fetchAll() async throws -> [Transaction]
    func fetchById(_ id: UUID) async throws -> Transaction?
    func fetchByAccount(_ accountId: UUID) async throws -> [Transaction]
    func fetchByDateRange(_ range: ClosedRange<Date>) async throws -> [Transaction]
    func fetchByCategory(_ category: TransactionCategory) async throws -> [Transaction]
    func fetchRecent(limit: Int) async throws -> [Transaction]
    func create(_ transaction: Transaction) async throws
    func update(_ transaction: Transaction) async throws
    func delete(_ transaction: Transaction) async throws

    /// Fetches a page of transactions for an account, sorted by date descending.
    /// - Parameters:
    ///   - accountId: The account to fetch transactions for.
    ///   - limit: Maximum number of transactions to return.
    ///   - offset: Number of transactions to skip.
    /// - Returns: A page of transactions.
    func fetchByAccount(_ accountId: UUID, limit: Int, offset: Int) async throws -> [Transaction]
}

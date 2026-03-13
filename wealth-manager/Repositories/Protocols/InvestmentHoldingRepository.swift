import Foundation

protocol InvestmentHoldingRepository {
    /// Fetches all investment holdings across all accounts.
    func fetchAll() async throws -> [InvestmentHolding]

    /// Fetches all holdings belonging to a specific account.
    func fetchByAccountId(_ accountId: UUID) async throws -> [InvestmentHolding]

    /// Creates a new holding record.
    func create(_ holding: InvestmentHolding) async throws

    /// Updates an existing holding record.
    func update(_ holding: InvestmentHolding) async throws

    /// Deletes a holding record.
    func delete(_ holding: InvestmentHolding) async throws
}

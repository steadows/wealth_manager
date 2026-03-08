import Foundation

protocol DebtRepository {
    func fetchAll() async throws -> [Debt]
    func fetchById(_ id: UUID) async throws -> Debt?
    func create(_ debt: Debt) async throws
    func update(_ debt: Debt) async throws
    func delete(_ debt: Debt) async throws
    func totalDebt() async throws -> Decimal
}

import Foundation

protocol GoalRepository {
    func fetchAll() async throws -> [FinancialGoal]
    func fetchById(_ id: UUID) async throws -> FinancialGoal?
    func fetchActive() async throws -> [FinancialGoal]
    func create(_ goal: FinancialGoal) async throws
    func update(_ goal: FinancialGoal) async throws
    func delete(_ goal: FinancialGoal) async throws
}

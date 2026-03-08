import Foundation

final class MockGoalRepository: GoalRepository {
    var items: [FinancialGoal] = []

    func fetchAll() async throws -> [FinancialGoal] {
        items
    }

    func fetchById(_ id: UUID) async throws -> FinancialGoal? {
        items.first { $0.id == id }
    }

    func fetchActive() async throws -> [FinancialGoal] {
        items.filter { $0.isActive }
    }

    func create(_ goal: FinancialGoal) async throws {
        items.append(goal)
    }

    func update(_ goal: FinancialGoal) async throws {
        guard let index = items.firstIndex(where: { $0.id == goal.id }) else {
            throw RepositoryError.notFound(goal.id)
        }
        items[index] = goal
    }

    func delete(_ goal: FinancialGoal) async throws {
        items.removeAll { $0.id == goal.id }
    }
}

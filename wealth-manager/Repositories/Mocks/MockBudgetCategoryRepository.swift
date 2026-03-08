import Foundation

final class MockBudgetCategoryRepository: BudgetCategoryRepository {
    var items: [BudgetCategory] = []

    func fetchAll() async throws -> [BudgetCategory] {
        items
    }

    func fetchForMonth(month: Int, year: Int) async throws -> [BudgetCategory] {
        items.filter { $0.month == month && $0.year == year }
    }

    func create(_ budget: BudgetCategory) async throws {
        let isDuplicate = items.contains {
            $0.category == budget.category && $0.month == budget.month && $0.year == budget.year
        }
        if isDuplicate {
            throw RepositoryError.duplicateBudgetCategory
        }
        items.append(budget)
    }

    func update(_ budget: BudgetCategory) async throws {
        guard let index = items.firstIndex(where: { $0.id == budget.id }) else {
            throw RepositoryError.notFound(budget.id)
        }
        items[index] = budget
    }

    func delete(_ budget: BudgetCategory) async throws {
        items.removeAll { $0.id == budget.id }
    }
}

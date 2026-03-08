import Foundation

protocol BudgetCategoryRepository {
    func fetchAll() async throws -> [BudgetCategory]
    func fetchForMonth(month: Int, year: Int) async throws -> [BudgetCategory]
    func create(_ budget: BudgetCategory) async throws
    func update(_ budget: BudgetCategory) async throws
    func delete(_ budget: BudgetCategory) async throws
}

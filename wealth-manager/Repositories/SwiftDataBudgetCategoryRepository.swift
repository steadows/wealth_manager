import Foundation
import SwiftData

@ModelActor
actor SwiftDataBudgetCategoryRepository: BudgetCategoryRepository {

    func fetchAll() async throws -> [BudgetCategory] {
        let descriptor = FetchDescriptor<BudgetCategory>(
            sortBy: [SortDescriptor(\.year), SortDescriptor(\.month)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchForMonth(month: Int, year: Int) async throws -> [BudgetCategory] {
        let descriptor = FetchDescriptor<BudgetCategory>(
            predicate: #Predicate { $0.month == month && $0.year == year }
        )
        return try modelContext.fetch(descriptor)
    }

    func create(_ budget: BudgetCategory) async throws {
        let month = budget.month
        let year = budget.year
        let existing = try modelContext.fetch(
            FetchDescriptor<BudgetCategory>(
                predicate: #Predicate { $0.month == month && $0.year == year }
            )
        )
        if existing.contains(where: { $0.categoryRawValue == budget.categoryRawValue }) {
            throw RepositoryError.duplicateBudgetCategory
        }
        modelContext.insert(budget)
        try modelContext.save()
    }

    func update(_ budget: BudgetCategory) async throws {
        try modelContext.save()
    }

    func delete(_ budget: BudgetCategory) async throws {
        modelContext.delete(budget)
        try modelContext.save()
    }
}

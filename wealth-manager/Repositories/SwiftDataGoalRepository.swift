import Foundation
import SwiftData

@ModelActor
actor SwiftDataGoalRepository: GoalRepository {

    func fetchAll() async throws -> [FinancialGoal] {
        let descriptor = FetchDescriptor<FinancialGoal>(
            sortBy: [SortDescriptor(\.priority)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchById(_ id: UUID) async throws -> FinancialGoal? {
        let descriptor = FetchDescriptor<FinancialGoal>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchActive() async throws -> [FinancialGoal] {
        let descriptor = FetchDescriptor<FinancialGoal>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.priority)]
        )
        return try modelContext.fetch(descriptor)
    }

    func create(_ goal: FinancialGoal) async throws {
        modelContext.insert(goal)
        try modelContext.save()
    }

    func update(_ goal: FinancialGoal) async throws {
        try modelContext.save()
    }

    func delete(_ goal: FinancialGoal) async throws {
        modelContext.delete(goal)
        try modelContext.save()
    }
}

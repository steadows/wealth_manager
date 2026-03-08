import Foundation
import SwiftData

@ModelActor
actor SwiftDataDebtRepository: DebtRepository {

    func fetchAll() async throws -> [Debt] {
        let descriptor = FetchDescriptor<Debt>(
            sortBy: [SortDescriptor(\.debtName)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchById(_ id: UUID) async throws -> Debt? {
        let descriptor = FetchDescriptor<Debt>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func create(_ debt: Debt) async throws {
        modelContext.insert(debt)
        try modelContext.save()
    }

    func update(_ debt: Debt) async throws {
        try modelContext.save()
    }

    func delete(_ debt: Debt) async throws {
        modelContext.delete(debt)
        try modelContext.save()
    }

    func totalDebt() async throws -> Decimal {
        let descriptor = FetchDescriptor<Debt>()
        let debts = try modelContext.fetch(descriptor)
        return debts.reduce(Decimal.zero) { $0 + $1.currentBalance }
    }
}

import Foundation

final class MockDebtRepository: DebtRepository {
    var items: [Debt] = []

    func fetchAll() async throws -> [Debt] {
        items
    }

    func fetchById(_ id: UUID) async throws -> Debt? {
        items.first { $0.id == id }
    }

    func create(_ debt: Debt) async throws {
        items.append(debt)
    }

    func update(_ debt: Debt) async throws {
        guard let index = items.firstIndex(where: { $0.id == debt.id }) else {
            throw RepositoryError.notFound(debt.id)
        }
        items[index] = debt
    }

    func delete(_ debt: Debt) async throws {
        items.removeAll { $0.id == debt.id }
    }

    func totalDebt() async throws -> Decimal {
        items.reduce(Decimal.zero) { $0 + $1.currentBalance }
    }
}

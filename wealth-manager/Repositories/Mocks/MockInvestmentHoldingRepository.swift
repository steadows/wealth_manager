import Foundation

final class MockInvestmentHoldingRepository: InvestmentHoldingRepository {
    var items: [InvestmentHolding] = []

    func fetchAll() async throws -> [InvestmentHolding] {
        items
    }

    func fetchByAccountId(_ accountId: UUID) async throws -> [InvestmentHolding] {
        items.filter { $0.account.id == accountId }
    }

    func create(_ holding: InvestmentHolding) async throws {
        items.append(holding)
    }

    func update(_ holding: InvestmentHolding) async throws {
        guard let index = items.firstIndex(where: { $0.id == holding.id }) else {
            throw RepositoryError.notFound(holding.id)
        }
        items[index] = holding
    }

    func delete(_ holding: InvestmentHolding) async throws {
        items.removeAll { $0.id == holding.id }
    }
}

import Foundation

final class MockAccountRepository: AccountRepository {
    var items: [Account] = []

    func fetchAll() async throws -> [Account] {
        items
    }

    func fetchById(_ id: UUID) async throws -> Account? {
        items.first { $0.id == id }
    }

    func fetchByType(_ type: AccountType) async throws -> [Account] {
        items.filter { $0.accountType == type }
    }

    func create(_ account: Account) async throws {
        items.append(account)
    }

    func update(_ account: Account) async throws {
        guard let index = items.firstIndex(where: { $0.id == account.id }) else {
            throw RepositoryError.notFound(account.id)
        }
        items[index] = account
    }

    func delete(_ account: Account) async throws {
        items.removeAll { $0.id == account.id }
    }

    func totalAssets() async throws -> Decimal {
        items
            .filter { $0.isAsset }
            .reduce(Decimal.zero) { $0 + $1.currentBalance }
    }

    func totalLiabilities() async throws -> Decimal {
        items
            .filter { $0.isLiability }
            .reduce(Decimal.zero) { $0 + $1.currentBalance }
    }
}

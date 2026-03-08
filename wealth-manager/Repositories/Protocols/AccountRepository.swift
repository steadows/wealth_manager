import Foundation

protocol AccountRepository {
    func fetchAll() async throws -> [Account]
    func fetchById(_ id: UUID) async throws -> Account?
    func fetchByType(_ type: AccountType) async throws -> [Account]
    func create(_ account: Account) async throws
    func update(_ account: Account) async throws
    func delete(_ account: Account) async throws
    func totalAssets() async throws -> Decimal
    func totalLiabilities() async throws -> Decimal
}

import Testing
import Foundation

@testable import wealth_manager

// MARK: - PaginatedTransactionTests

@Suite("Paginated Transaction Loading")
struct PaginatedTransactionTests {

    // MARK: - Test Helpers

    private func makeAccount(id: UUID = UUID()) -> Account {
        Account(
            id: id,
            institutionName: "Test Bank",
            accountName: "Checking",
            accountType: .checking,
            currentBalance: 5000,
            isManual: true
        )
    }

    private func makeTransaction(
        account: Account,
        date: Date = Date(),
        amount: Decimal = 50,
        merchantName: String = "Test Merchant"
    ) -> Transaction {
        Transaction(
            id: UUID(),
            account: account,
            amount: amount,
            date: date,
            merchantName: merchantName,
            category: .food
        )
    }

    private func makeMockRepo(account: Account, count: Int) -> MockTransactionRepository {
        let repo = MockTransactionRepository()
        let calendar = Calendar.current
        let baseDate = Date()
        repo.items = (0..<count).map { i in
            let date = calendar.date(byAdding: .day, value: -i, to: baseDate)!
            return makeTransaction(
                account: account,
                date: date,
                amount: Decimal(10 + i),
                merchantName: "Merchant \(i)"
            )
        }
        return repo
    }

    // MARK: - Paginated Fetch Tests

    @Test("fetchByAccount with limit returns correct page size")
    func fetchWithLimitReturnsCorrectSize() async throws {
        let account = makeAccount()
        let repo = makeMockRepo(account: account, count: 50)

        let page = try await repo.fetchByAccount(account.id, limit: 20, offset: 0)

        #expect(page.count == 20)
    }

    @Test("fetchByAccount with offset skips correct number of items")
    func fetchWithOffsetSkipsCorrectly() async throws {
        let account = makeAccount()
        let repo = makeMockRepo(account: account, count: 50)

        let page1 = try await repo.fetchByAccount(account.id, limit: 10, offset: 0)
        let page2 = try await repo.fetchByAccount(account.id, limit: 10, offset: 10)

        // Pages should not overlap
        let page1Ids = Set(page1.map(\.id))
        let page2Ids = Set(page2.map(\.id))
        #expect(page1Ids.isDisjoint(with: page2Ids))
    }

    @Test("fetchByAccount returns empty when offset exceeds count")
    func fetchWithExcessiveOffsetReturnsEmpty() async throws {
        let account = makeAccount()
        let repo = makeMockRepo(account: account, count: 10)

        let page = try await repo.fetchByAccount(account.id, limit: 20, offset: 100)

        #expect(page.isEmpty)
    }

    @Test("fetchByAccount returns remaining items when limit exceeds available")
    func fetchReturnsRemainingWhenLimitExceeds() async throws {
        let account = makeAccount()
        let repo = makeMockRepo(account: account, count: 5)

        let page = try await repo.fetchByAccount(account.id, limit: 20, offset: 0)

        #expect(page.count == 5)
    }

    @Test("fetchByAccount returns items sorted by date descending")
    func fetchReturnsSortedByDateDesc() async throws {
        let account = makeAccount()
        let repo = makeMockRepo(account: account, count: 20)

        let page = try await repo.fetchByAccount(account.id, limit: 10, offset: 0)

        for i in 0..<(page.count - 1) {
            #expect(page[i].date >= page[i + 1].date)
        }
    }

    @Test("fetchByAccount filters to correct account only")
    func fetchFiltersToCorrectAccount() async throws {
        let account1 = makeAccount()
        let account2 = makeAccount()
        let repo = MockTransactionRepository()
        repo.items = [
            makeTransaction(account: account1, merchantName: "A1"),
            makeTransaction(account: account2, merchantName: "A2"),
            makeTransaction(account: account1, merchantName: "A3"),
        ]

        let page = try await repo.fetchByAccount(account1.id, limit: 10, offset: 0)

        #expect(page.count == 2)
        #expect(page.allSatisfy { $0.account.id == account1.id })
    }
}

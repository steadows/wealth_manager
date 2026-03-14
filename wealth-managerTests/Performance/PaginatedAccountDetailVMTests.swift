import Testing
import Foundation

@testable import wealth_manager

// MARK: - PaginatedAccountDetailVMTests

@Suite("AccountDetailViewModel Pagination")
struct PaginatedAccountDetailVMTests {

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

    // MARK: - Initial Load

    @Test("loadTransactions loads first page with page size limit")
    func loadTransactionsLoadsFirstPage() async {
        let account = makeAccount()
        let repo = makeMockRepo(account: account, count: 100)
        let vm = AccountDetailViewModel(account: account, transactionRepo: repo)

        await vm.loadTransactions()

        #expect(vm.transactions.count <= AccountDetailViewModel.pageSize)
        #expect(!vm.isLoading)
    }

    @Test("loadTransactions with fewer items than page size loads all")
    func loadTransactionsLoadsAllWhenFewer() async {
        let account = makeAccount()
        let repo = makeMockRepo(account: account, count: 5)
        let vm = AccountDetailViewModel(account: account, transactionRepo: repo)

        await vm.loadTransactions()

        #expect(vm.transactions.count == 5)
        #expect(!vm.hasMorePages)
    }

    // MARK: - Load More

    @Test("loadMoreTransactions appends next page")
    func loadMoreAppendsNextPage() async {
        let account = makeAccount()
        let repo = makeMockRepo(account: account, count: 100)
        let vm = AccountDetailViewModel(account: account, transactionRepo: repo)

        await vm.loadTransactions()
        let firstPageCount = vm.transactions.count

        await vm.loadMoreTransactions()

        #expect(vm.transactions.count > firstPageCount)
    }

    @Test("loadMoreTransactions sets hasMorePages to false when exhausted")
    func loadMoreSetsNoMorePagesWhenExhausted() async {
        let account = makeAccount()
        let pageSize = AccountDetailViewModel.pageSize
        let repo = makeMockRepo(account: account, count: pageSize + 3)
        let vm = AccountDetailViewModel(account: account, transactionRepo: repo)

        await vm.loadTransactions()
        #expect(vm.hasMorePages)

        await vm.loadMoreTransactions()
        #expect(!vm.hasMorePages)
    }

    @Test("loadMoreTransactions does nothing when no more pages")
    func loadMoreDoesNothingWhenExhausted() async {
        let account = makeAccount()
        let repo = makeMockRepo(account: account, count: 5)
        let vm = AccountDetailViewModel(account: account, transactionRepo: repo)

        await vm.loadTransactions()
        let count = vm.transactions.count
        #expect(!vm.hasMorePages)

        await vm.loadMoreTransactions()
        #expect(vm.transactions.count == count)
    }

    @Test("loadMoreTransactions does not duplicate items")
    func loadMoreDoesNotDuplicate() async {
        let account = makeAccount()
        let repo = makeMockRepo(account: account, count: 100)
        let vm = AccountDetailViewModel(account: account, transactionRepo: repo)

        await vm.loadTransactions()
        await vm.loadMoreTransactions()

        let ids = vm.transactions.map(\.id)
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }
}

import Foundation

/// ViewModel for the account detail view with transactions.
/// Supports paginated loading via `loadMoreTransactions()`.
@Observable
final class AccountDetailViewModel {

    // MARK: - Constants

    /// Number of transactions to load per page.
    static let pageSize: Int = 50

    // MARK: - Published State

    var account: Account
    var transactions: [Transaction] = []
    var searchText: String = ""
    var selectedCategory: TransactionCategory?
    var isLoading: Bool = false
    var hasMorePages: Bool = true
    var error: Error?

    // MARK: - Private State

    private var currentOffset: Int = 0

    // MARK: - Dependencies

    private let transactionRepo: TransactionRepository

    // MARK: - Init

    init(account: Account, transactionRepo: TransactionRepository) {
        self.account = account
        self.transactionRepo = transactionRepo
    }

    // MARK: - Computed

    /// Transactions filtered by search text and selected category.
    var filteredTransactions: [Transaction] {
        var result = transactions

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { txn in
                (txn.merchantName?.lowercased().contains(query) ?? false)
                    || (txn.note?.lowercased().contains(query) ?? false)
                    || txn.category.displayName.lowercased().contains(query)
            }
        }

        return result
    }

    // MARK: - Actions

    /// Loads the first page of transactions for the current account.
    func loadTransactions() async {
        isLoading = true
        error = nil
        currentOffset = 0
        transactions = []

        do {
            let page = try await transactionRepo.fetchByAccount(
                account.id,
                limit: Self.pageSize,
                offset: 0
            )
            transactions = page
            currentOffset = page.count
            hasMorePages = page.count >= Self.pageSize
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Loads the next page of transactions and appends to the existing list.
    func loadMoreTransactions() async {
        guard hasMorePages, !isLoading else { return }
        isLoading = true

        do {
            let page = try await transactionRepo.fetchByAccount(
                account.id,
                limit: Self.pageSize,
                offset: currentOffset
            )
            transactions.append(contentsOf: page)
            currentOffset += page.count
            hasMorePages = page.count >= Self.pageSize
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Filters transactions by category.
    func filterByCategory(_ category: TransactionCategory?) {
        selectedCategory = category
    }

    /// Clears all filters.
    func clearFilters() {
        searchText = ""
        selectedCategory = nil
    }
}

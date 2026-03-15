import Foundation

/// ViewModel for the account detail view with transactions.
/// Supports paginated loading via `loadMoreTransactions()`.
/// Falls back to fetching from the backend API when the local
/// SwiftData store has no transactions for the account.
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
    private let apiClient: APIClientProtocol?

    // MARK: - Init

    init(
        account: Account,
        transactionRepo: TransactionRepository,
        apiClient: APIClientProtocol? = nil
    ) {
        self.account = account
        self.transactionRepo = transactionRepo
        self.apiClient = apiClient
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
    ///
    /// Fetches from backend API if available, falls back to local SwiftData.
    func loadTransactions() async {
        isLoading = true
        error = nil
        currentOffset = 0
        transactions = []

        do {
            if let client = apiClient {
                // Fetch from backend API
                let response: TransactionListResponseDTO = try await client.request(
                    .listTransactions(accountId: account.id, limit: Self.pageSize, offset: 0)
                )
                let fetched = response.transactions.map { dto in
                    let category = TransactionCategory(rawValue: dto.category) ?? .other
                    return Transaction(
                        id: dto.id,
                        plaidTransactionId: dto.plaidTransactionId,
                        account: account,
                        amount: dto.amount,
                        date: dto.date,
                        merchantName: dto.merchantName,
                        category: category,
                        subcategory: dto.subcategory,
                        note: dto.note,
                        isRecurring: dto.isRecurring,
                        isPending: dto.isPending,
                        createdAt: dto.createdAt
                    )
                }
                transactions = fetched
                currentOffset = fetched.count
                hasMorePages = fetched.count >= Self.pageSize
            } else {
                // Fallback to local SwiftData
                let page = try await transactionRepo.fetchByAccount(
                    account.id,
                    limit: Self.pageSize,
                    offset: 0
                )
                transactions = page
                currentOffset = page.count
                hasMorePages = page.count >= Self.pageSize
            }
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

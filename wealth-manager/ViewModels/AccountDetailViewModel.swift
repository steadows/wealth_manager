import Foundation

/// ViewModel for the account detail view with transactions.
@Observable
final class AccountDetailViewModel {

    // MARK: - Published State

    var account: Account
    var transactions: [Transaction] = []
    var searchText: String = ""
    var selectedCategory: TransactionCategory?
    var isLoading: Bool = false
    var error: Error?

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

    /// Loads transactions for the current account.
    func loadTransactions() async {
        isLoading = true
        error = nil

        do {
            transactions = try await transactionRepo.fetchByAccount(account.id)
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

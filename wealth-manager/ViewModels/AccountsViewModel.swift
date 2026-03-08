import Foundation

/// ViewModel for the accounts list content column.
@Observable
final class AccountsViewModel {

    // MARK: - Published State

    var accounts: [Account] = []
    var searchText: String = ""
    var isLoading: Bool = false
    var error: Error?

    // MARK: - Dependencies

    private let accountRepo: AccountRepository

    // MARK: - Init

    init(accountRepo: AccountRepository) {
        self.accountRepo = accountRepo
    }

    // MARK: - Computed

    /// Accounts filtered by the current search text.
    var filteredAccounts: [Account] {
        guard !searchText.isEmpty else { return accounts }
        let query = searchText.lowercased()
        return accounts.filter {
            $0.accountName.lowercased().contains(query)
                || $0.institutionName.lowercased().contains(query)
        }
    }

    /// Totals grouped by account type for section headers.
    var sectionTotals: [AccountType: Decimal] {
        Dictionary(
            grouping: filteredAccounts,
            by: { $0.accountType }
        ).mapValues { group in
            group.reduce(Decimal.zero) { $0 + $1.currentBalance }
        }
    }

    // MARK: - Actions

    /// Loads all accounts from the repository.
    func loadAccounts() async {
        isLoading = true
        error = nil

        do {
            accounts = try await accountRepo.fetchAll()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Adds a new account via the repository.
    func addAccount(_ account: Account) async throws {
        try await accountRepo.create(account)
        await loadAccounts()
    }

    /// Toggles the hidden state of an account.
    func toggleHidden(_ account: Account) async throws {
        // SwiftData @Model objects are reference types — toggle in place and save
        account.isHidden = !account.isHidden
        account.updatedAt = Date()
        try await accountRepo.update(account)
        await loadAccounts()
    }

    /// Deletes an account via the repository.
    func deleteAccount(_ account: Account) async throws {
        try await accountRepo.delete(account)
        await loadAccounts()
    }
}

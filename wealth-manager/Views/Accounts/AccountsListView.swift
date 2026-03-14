import SwiftUI

/// Content (middle) column showing all accounts grouped by type.
struct AccountsListView: View {

    @Bindable var viewModel: AccountsViewModel
    @Binding var selection: Account?

    @State private var showingAddSheet = false

    // MARK: - Sorted Section Keys

    /// Deterministic section ordering based on `AccountType.allCases`.
    private var sortedSectionKeys: [AccountType] {
        AccountType.allCases.filter { groupedAndFiltered[$0] != nil }
    }

    /// Grouped accounts further narrowed by the active search text.
    private var groupedAndFiltered: [AccountType: [Account]] {
        Dictionary(grouping: viewModel.filteredAccounts) { $0.accountType }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading accounts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredAccounts.isEmpty {
                emptyState
            } else {
                accountList
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search accounts")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingAddSheet) {
            AddAccountView { newAccount in
                Task {
                    do {
                        try await viewModel.addAccount(newAccount)
                    } catch {
                        viewModel.error = error
                    }
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred.")
        }
        .task {
            await viewModel.loadAccounts()
        }
    }

    // MARK: - Subviews

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAddSheet = true
            } label: {
                Label("Add Account", systemImage: "plus")
            }
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "banknote",
            title: "No Accounts",
            description: "Add your first account to start tracking your finances.",
            actionTitle: "Add Account"
        ) {
            showingAddSheet = true
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var accountList: some View {
        List(selection: $selection) {
            ForEach(sortedSectionKeys) { accountType in
                accountSection(for: accountType)
            }
        }
        .listStyle(.sidebar)
    }

    private func accountSection(for type: AccountType) -> some View {
        Section {
            if let accounts = groupedAndFiltered[type] {
                ForEach(accounts, id: \.id) { account in
                    accountRow(account)
                        .tag(account)
                        .contextMenu { contextMenu(for: account) }
                }
            }
        } header: {
            sectionHeader(for: type)
        }
    }

    private func sectionHeader(for type: AccountType) -> some View {
        HStack {
            Text(type.displayName)
                .font(.headline)
                .foregroundStyle(WMColors.textPrimary)
            Spacer()
            Text(formattedCurrency(viewModel.sectionTotals[type] ?? 0))
                .font(.subheadline)
                .foregroundStyle(WMColors.textMuted)
        }
    }

    private func accountRow(_ account: Account) -> some View {
        HStack(spacing: 12) {
            institutionIcon(for: account)

            VStack(alignment: .leading, spacing: 2) {
                Text(account.accountName)
                    .font(.body)
                    .foregroundStyle(WMColors.textPrimary)
                Text(account.institutionName)
                    .font(.caption)
                    .foregroundStyle(WMColors.textMuted)
            }

            Spacer()

            Text(formattedCurrency(account.currentBalance))
                .font(.body.monospacedDigit())
                .foregroundStyle(balanceColor(for: account))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(account.accountName) at \(account.institutionName), balance \(formattedCurrency(account.currentBalance))")
    }

    private func institutionIcon(for account: Account) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(WMColors.glassBg)
                .frame(width: 32, height: 32)
            Text(String(account.institutionName.prefix(1)).uppercased())
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WMColors.primary)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func contextMenu(for account: Account) -> some View {
        Button {
            selection = account
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Button {
            Task {
                do {
                    try await viewModel.toggleHidden(account)
                } catch {
                    viewModel.error = error
                }
            }
        } label: {
            Label(
                account.isHidden ? "Show" : "Hide",
                systemImage: account.isHidden ? "eye" : "eye.slash"
            )
        }

        Divider()

        Button(role: .destructive) {
            Task {
                do {
                    try await viewModel.deleteAccount(account)
                } catch {
                    viewModel.error = error
                }
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Helpers

    private func balanceColor(for account: Account) -> Color {
        if account.isLiability {
            return WMColors.negative
        }
        return account.currentBalance >= 0 ? WMColors.positive : WMColors.negative
    }

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()

    private func formattedCurrency(_ amount: Decimal) -> String {
        Self.currencyFormatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

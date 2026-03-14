import SwiftUI

/// Detail (right) column showing account info, transactions table, and analytics.
struct AccountDetailView: View {

    @Bindable var viewModel: AccountDetailViewModel

    @State private var selectedTab: DetailTab = .transactions
    @State private var sortOrder = [KeyPathComparator(\Transaction.date, order: .reverse)]

    // MARK: - Tab

    enum DetailTab: String, CaseIterable, Identifiable {
        case transactions = "Transactions"
        case analytics = "Analytics"

        var id: String { rawValue }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            accountHeader
            tabPicker
            tabContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            await viewModel.loadTransactions()
        }
    }

    // MARK: - Header

    private var accountHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.account.accountName)
                        .font(.title2.bold())
                        .foregroundStyle(WMColors.textPrimary)

                    Text(viewModel.account.institutionName)
                        .font(.subheadline)
                        .foregroundStyle(WMColors.textMuted)
                }

                Spacer()

                accountTypeBadge
            }

            Text(formattedCurrency(viewModel.account.currentBalance))
                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(WMColors.textPrimary)

            if let lastSynced = viewModel.account.lastSyncedAt {
                Text("Last synced \(lastSynced, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(WMColors.textMuted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .padding([.horizontal, .top], 16)
    }

    private var accountTypeBadge: some View {
        Text(viewModel.account.accountType.displayName)
            .font(.caption.bold())
            .foregroundStyle(WMColors.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(WMColors.primary.opacity(0.15))
            .clipShape(Capsule())
            .accessibilityLabel("Account type: \(viewModel.account.accountType.displayName)")
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(DetailTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .transactions:
            transactionsTab
        case .analytics:
            analyticsPlaceholder
        }
    }

    // MARK: - Transactions Tab

    private var transactionsTab: some View {
        VStack(spacing: 8) {
            searchAndFilters
            transactionsTable
        }
        .padding(.horizontal, 16)
    }

    private var searchAndFilters: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(WMColors.textMuted)
                TextField("Search transactions", text: $viewModel.searchText)
                    .textFieldStyle(.plain)

                if !viewModel.searchText.isEmpty || viewModel.selectedCategory != nil {
                    Button("Clear") {
                        viewModel.clearFilters()
                    }
                    .font(.caption)
                    .foregroundStyle(WMColors.primary)
                }
            }
            .padding(8)
            .glassCard(cornerRadius: 8)

            categoryChips
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                categoryChip(label: "All", category: nil)
                ForEach(TransactionCategory.allCases) { category in
                    categoryChip(label: category.displayName, category: category)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func categoryChip(label: String, category: TransactionCategory?) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            viewModel.filterByCategory(category)
        } label: {
            Text(label)
                .font(.caption)
                .foregroundStyle(isSelected ? WMColors.textPrimary : WMColors.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? WMColors.primary.opacity(0.3) : WMColors.glassBg)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter: \(label)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Double tap to filter transactions by \(label)")
    }

    private var transactionsTable: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading transactions...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredTransactions.isEmpty {
                transactionsEmptyState
            } else {
                transactionTableContent
            }
        }
    }

    private var transactionsEmptyState: some View {
        EmptyStateView(
            icon: "list.bullet.rectangle",
            title: "No Transactions",
            description: "Transactions will appear here once imported or added.",
            actionTitle: nil,
            action: nil
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var transactionTableContent: some View {
        Group {
            #if os(macOS)
            Table(sortedTransactions, sortOrder: $sortOrder) {
                TableColumn("Date", value: \.date) { txn in
                    Text(txn.date, format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(WMColors.textPrimary)
                }
                .width(min: 70, ideal: 90)

                TableColumn("Merchant") { txn in
                    Text(txn.merchantDisplayName)
                        .foregroundStyle(WMColors.textPrimary)
                        .lineLimit(1)
                }
                .width(min: 120, ideal: 180)

                TableColumn("Category") { txn in
                    Text(txn.category.displayName)
                        .font(.caption)
                        .foregroundStyle(WMColors.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(WMColors.primary.opacity(0.12))
                        .clipShape(Capsule())
                }
                .width(min: 100, ideal: 130)

                TableColumn("Amount") { txn in
                    Text(formattedCurrency(txn.amount))
                        .foregroundStyle(txn.amount >= 0 ? WMColors.positive : WMColors.negative)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 80, ideal: 110)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))

            if viewModel.hasMorePages {
                loadMoreButton
            }
            #else
            List {
                ForEach(sortedTransactions, id: \.id) { txn in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(txn.merchantDisplayName)
                                .foregroundStyle(WMColors.textPrimary)
                                .lineLimit(1)
                            Text(txn.date, format: .dateTime.month(.abbreviated).day())
                                .font(.caption)
                                .foregroundStyle(WMColors.textMuted)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formattedCurrency(txn.amount))
                                .foregroundStyle(txn.amount >= 0 ? WMColors.positive : WMColors.negative)
                                .monospacedDigit()
                            Text(txn.category.displayName)
                                .font(.caption)
                                .foregroundStyle(WMColors.primary)
                        }
                    }
                }

                if viewModel.hasMorePages {
                    loadMoreButton
                }
            }
            .listStyle(.plain)
            #endif
        }
    }

    /// Button shown at the bottom of the transaction list to load more items.
    private var loadMoreButton: some View {
        Button {
            Task { await viewModel.loadMoreTransactions() }
        } label: {
            HStack {
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Load More")
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.primary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Load more transactions")
    }

    /// Transactions sorted according to the current table sort order.
    private var sortedTransactions: [Transaction] {
        viewModel.filteredTransactions.sorted(using: sortOrder)
    }

    // MARK: - Analytics Placeholder

    private var analyticsPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundStyle(WMColors.textMuted)
                .accessibilityHidden(true)
            Text("Spending breakdown coming in Sprint 3")
                .font(.title3)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analytics: Spending breakdown coming soon")
    }

    // MARK: - Helpers

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }()

    private func formattedCurrency(_ amount: Decimal) -> String {
        let fmt = Self.currencyFormatter.copy() as! NumberFormatter
        fmt.currencyCode = viewModel.account.currency
        return fmt.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Transaction Helpers

private extension Transaction {
    /// Display name for the merchant column, falling back to note or "Unknown".
    var merchantDisplayName: String {
        merchantName ?? note ?? "Unknown"
    }
}

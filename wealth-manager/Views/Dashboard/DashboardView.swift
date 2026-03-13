import SwiftUI
import SwiftData

/// Main dashboard detail pane displaying net worth, health score,
/// recent transactions, active goals, and AI insights.
struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                heroSection
                quickActionsRow
                contentGrid
                aiInsightSection
            }
            .padding(24)
        }
        .background(WMColors.background)
        .task {
            await viewModel.loadDashboard()
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        HStack(spacing: 24) {
            netWorthCard
            healthScoreCard
        }
    }

    private var netWorthCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Net Worth")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textMuted)

            CurrencyText(
                amount: viewModel.netWorth,
                font: WMTypography.heroNumber
            )

            netWorthChangeRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
    }

    private var netWorthChangeRow: some View {
        HStack(spacing: 4) {
            Image(systemName: changeArrowIcon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(changeColor)

            CurrencyText(
                amount: viewModel.netWorthChange,
                showSign: true,
                font: WMTypography.caption
            )

            Text("vs last snapshot")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
        }
    }

    private var changeArrowIcon: String {
        viewModel.netWorthChange >= 0 ? "arrow.up.right" : "arrow.down.right"
    }

    private var changeColor: Color {
        viewModel.netWorthChange >= 0 ? WMColors.positive : WMColors.negative
    }

    private var healthScoreCard: some View {
        VStack(spacing: 8) {
            Text("Health Score")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textMuted)

            ProgressRing(
                progress: Double(viewModel.healthScore) / 100.0,
                size: 80,
                lineWidth: 8
            )
        }
        .frame(width: 160)
        .padding(20)
        .glassCard()
    }

    // MARK: - Quick Actions

    private var quickActionsRow: some View {
        HStack(spacing: 12) {
            GlassButton(label: "Add Account", icon: "plus.circle") {
                // Placeholder action
            }

            GlassButton(label: "Refresh", icon: "arrow.clockwise") {
                Task {
                    await viewModel.loadDashboard()
                }
            }

            Spacer()
        }
    }

    // MARK: - Content Grid

    private var contentGrid: some View {
        HStack(alignment: .top, spacing: 20) {
            recentTransactionsSection
            activeGoalsSection
        }
    }

    // MARK: - Recent Transactions

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Transactions")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            if viewModel.recentTransactions.isEmpty {
                EmptyStateView(
                    icon: "creditcard",
                    title: "No Transactions",
                    description: "Transactions will appear here once accounts are connected."
                )
                .frame(minHeight: 200)
            } else {
                transactionsTable
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
    }

    private var transactionsTable: some View {
        Group {
            #if os(macOS)
            Table(viewModel.recentTransactions) {
                TableColumn("Date") { transaction in
                    Text(transaction.date, style: .date)
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textPrimary)
                }
                .width(min: 80, ideal: 100)

                TableColumn("Merchant") { transaction in
                    Text(transaction.merchantName ?? "Unknown")
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.textPrimary)
                }
                .width(min: 100, ideal: 160)

                TableColumn("Category") { transaction in
                    GlassPill(text: transaction.category.displayName)
                }
                .width(min: 90, ideal: 120)

                TableColumn("Amount") { transaction in
                    CurrencyText(
                        amount: transaction.amount,
                        showSign: true,
                        font: WMTypography.body
                    )
                }
                .width(min: 80, ideal: 100)
            }
            #else
            LazyVStack(spacing: 8) {
                ForEach(viewModel.recentTransactions, id: \.id) { transaction in
                    transactionRow(transaction)
                }
            }
            #endif
        }
        .frame(minHeight: 200)
    }

    #if os(iOS)
    private func transactionRow(_ transaction: Transaction) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchantName ?? "Unknown")
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
                Text(transaction.date, style: .date)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                CurrencyText(
                    amount: transaction.amount,
                    showSign: true,
                    font: WMTypography.body
                )
                GlassPill(text: transaction.category.displayName)
            }
        }
        .padding(.vertical, 4)
    }
    #endif

    // MARK: - Active Goals

    private var activeGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Goals")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            if viewModel.activeGoals.isEmpty {
                EmptyStateView(
                    icon: "target",
                    title: "No Goals Yet",
                    description: "Set financial goals to track your progress."
                )
                .frame(minHeight: 200)
            } else {
                goalsList
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
    }

    private var goalsList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.activeGoals, id: \.id) { goal in
                goalRow(goal)
            }
        }
    }

    private func goalRow(_ goal: FinancialGoal) -> some View {
        HStack(spacing: 12) {
            ProgressRing(
                progress: NSDecimalNumber(decimal: goal.progressPercent).doubleValue,
                size: 40,
                lineWidth: 4
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.goalName)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)

                HStack(spacing: 4) {
                    CurrencyText(amount: goal.currentAmount, font: WMTypography.caption)
                    Text("of")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                    CurrencyText(amount: goal.targetAmount, font: WMTypography.caption)
                }
            }

            Spacer()

            if goal.isOnTrack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(WMColors.positive)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(WMColors.negative)
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 10)
    }

    // MARK: - AI Insight

    private var aiInsightSection: some View {
        AIInsightCard(
            message: "Welcome to Wealth Manager. Connect your accounts to get personalized financial insights powered by AI."
        )
    }
}

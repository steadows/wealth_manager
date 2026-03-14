import SwiftUI

/// Detail view displaying monthly budget overview with category breakdown.
struct BudgetView: View {
    @Bindable var viewModel: BudgetViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                monthSelector
                summaryBar
                aiInsight
                categoryGrid
                chartPlaceholder
            }
            .padding()
        }
        .task {
            await viewModel.loadBudget(for: viewModel.selectedMonth)
        }
    }

    // MARK: - Month Selector

    private var monthSelector: some View {
        HStack(spacing: 16) {
            Button {
                Task { await viewModel.previousMonth() }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(WMColors.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            GlassPill(text: viewModel.selectedMonthName, isSelected: true)
                .accessibilityLabel("Selected month: \(viewModel.selectedMonthName)")

            Button {
                Task { await viewModel.nextMonth() }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(WMColors.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
        }
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        VStack(spacing: 12) {
            HStack {
                summaryItem(label: "Income", amount: viewModel.totalIncome, color: WMColors.positive)
                Spacer()
                summaryItem(label: "Spent", amount: viewModel.totalSpent, color: WMColors.negative)
                Spacer()
                summaryItem(
                    label: "Remaining",
                    amount: viewModel.remaining,
                    color: viewModel.remaining >= 0 ? WMColors.positive : WMColors.negative
                )
            }

            budgetProgressBar
        }
        .padding(16)
        .glassCard()
    }

    private func summaryItem(label: String, amount: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            CurrencyText(amount: amount, font: WMTypography.subheading)
        }
    }

    private var budgetProgressBar: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let spentRatio = viewModel.totalIncome > 0
                ? min(
                    NSDecimalNumber(decimal: viewModel.totalSpent / viewModel.totalIncome).doubleValue,
                    1.0
                )
                : 0.0
            let isOverBudget = viewModel.totalSpent > viewModel.totalIncome

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(WMColors.glassBg)
                    .frame(height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: isOverBudget
                                ? [WMColors.negative, WMColors.negative.opacity(0.7)]
                                : [WMColors.primary, WMColors.secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: totalWidth * spentRatio, height: 8)
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Budget usage: \(Int(budgetUsagePercent))%\(viewModel.totalSpent > viewModel.totalIncome ? ", over budget" : "")")
    }

    /// Budget usage as a percentage for accessibility.
    private var budgetUsagePercent: Double {
        viewModel.totalIncome > 0
            ? NSDecimalNumber(decimal: viewModel.totalSpent / viewModel.totalIncome * 100).doubleValue
            : 0.0
    }

    // MARK: - AI Insight

    private var aiInsight: some View {
        AIInsightCard(message: "Budget analysis available after account linking")
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else if viewModel.categories.isEmpty {
                EmptyStateView(
                    icon: "chart.pie",
                    title: "No Budget Categories",
                    description: "Budget categories will appear here once you set up your monthly budget."
                )
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.categories) { summary in
                        categoryCard(summary)
                    }
                }
            }
        }
    }

    private func categoryCard(_ summary: BudgetCategorySummary) -> some View {
        let isOver = summary.percentUsed > 1.0

        return VStack(spacing: 12) {
            HStack {
                ProgressRing(
                    progress: summary.percentUsed,
                    size: 40,
                    lineWidth: 4,
                    threshold: 1.0
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: iconForCategory(summary.category))
                            .font(.system(size: 12))
                            .foregroundStyle(WMColors.primary)
                        Text(summary.category.displayName)
                            .font(WMTypography.subheading)
                            .foregroundStyle(WMColors.textPrimary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 2) {
                        CurrencyText(amount: summary.spent, font: WMTypography.caption)
                        Text("/")
                            .font(WMTypography.caption)
                            .foregroundStyle(WMColors.textMuted)
                        CurrencyText(amount: summary.budgetLimit, font: WMTypography.caption)
                    }
                }

                Spacer()

                trendArrow(summary.trend)
            }
        }
        .padding(14)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isOver ? WMColors.negative.opacity(0.5) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: isOver ? WMColors.negative.opacity(0.2) : Color.clear,
            radius: 8
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(summary.category.displayName) budget\(isOver ? ", over budget" : "")")
    }

    private func trendArrow(_ trend: BudgetCategorySummary.Trend) -> some View {
        Group {
            switch trend {
            case .up:
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(WMColors.negative)
            case .down:
                Image(systemName: "arrow.down.right")
                    .foregroundStyle(WMColors.positive)
            case .flat:
                Image(systemName: "arrow.right")
                    .foregroundStyle(WMColors.textMuted)
            }
        }
        .font(.system(size: 14, weight: .medium))
        .accessibilityLabel("Trend: \(trendDescription(trend))")
    }

    private func trendDescription(_ trend: BudgetCategorySummary.Trend) -> String {
        switch trend {
        case .up: "spending increasing"
        case .down: "spending decreasing"
        case .flat: "spending stable"
        }
    }

    // MARK: - Chart Placeholder

    private var chartPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 32))
                .foregroundStyle(WMColors.textMuted)

            Text("Spending Trend")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            Text("Chart coming in Sprint 3")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard()
    }

    // MARK: - Category Icons

    /// Maps transaction categories to SF Symbol names.
    private func iconForCategory(_ category: TransactionCategory) -> String {
        switch category {
        case .income: "dollarsign.circle"
        case .housing: "house.fill"
        case .transportation: "car.fill"
        case .food: "fork.knife"
        case .utilities: "bolt.fill"
        case .healthcare: "heart.fill"
        case .entertainment: "tv.fill"
        case .shopping: "bag.fill"
        case .education: "graduationcap.fill"
        case .personalCare: "sparkles"
        case .travel: "airplane"
        case .gifts: "gift.fill"
        case .fees: "banknote"
        case .transfer: "arrow.left.arrow.right"
        case .other: "ellipsis.circle"
        }
    }
}

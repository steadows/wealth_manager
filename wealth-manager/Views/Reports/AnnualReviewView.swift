import SwiftUI

// MARK: - AnnualReviewView

/// Year-end comprehensive financial analysis report.
struct AnnualReviewView: View {
    @State var viewModel: AnnualReviewViewModel

    /// Range of selectable years: last 5 years up to previous calendar year.
    private var availableYears: [Int] {
        let previousYear = Calendar.current.component(.year, from: Date()) - 1
        return (0..<5).map { previousYear - $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                yearPicker
                if viewModel.isLoading {
                    ProgressView("Generating annual review...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let review = viewModel.review {
                    narrativeSection(review: review)
                    netWorthSection(review: review)
                    incomeSpendingSection(review: review)
                    topCategoriesSection(review: review)
                    goalProgressSection(review: review)
                    actionItemsSection(review: review)
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                } else {
                    generatePromptView
                }
            }
            .padding(24)
        }
        .background(WMColors.background)
        .navigationTitle("Annual Review \(viewModel.selectedYear)")
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
        HStack {
            Text("Year")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            Spacer()
            Picker("Year", selection: Binding(
                get: { viewModel.selectedYear },
                set: { viewModel.selectYear($0) }
            )) {
                ForEach(availableYears, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.menu)
        }
        .padding(16)
        .background(WMColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Generate Prompt

    private var generatePromptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundStyle(WMColors.secondary)
            Text("Generate your \(viewModel.selectedYear) annual review")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
                .multilineTextAlignment(.center)
            Button("Generate Review") {
                Task { await viewModel.generateReview() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding(24)
    }

    // MARK: - Narrative

    private func narrativeSection(review: AnnualReviewDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Year in Review")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            Text(review.narrative)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(WMColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Net Worth

    private func netWorthSection(review: AnnualReviewDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Net Worth")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            HStack(spacing: 0) {
                netWorthStat(label: "Starting", value: review.startingNetWorth)
                Spacer()
                netWorthStat(label: "Ending", value: review.endingNetWorth)
                Spacer()
                netWorthChangeStat(change: review.netWorthChange)
            }
        }
        .padding(16)
        .background(WMColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func netWorthStat(label: String, value: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            Text(value, format: .currency(code: "USD"))
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
        }
    }

    private func netWorthChangeStat(change: Decimal) -> some View {
        let isPositive = change >= 0
        return VStack(alignment: .leading, spacing: 4) {
            Text("Change")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                    .font(.caption)
                Text(change, format: .currency(code: "USD"))
                    .font(WMTypography.body)
            }
            .foregroundStyle(isPositive ? WMColors.positive : WMColors.negative)
        }
    }

    // MARK: - Income & Spending

    private func incomeSpendingSection(review: AnnualReviewDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Income & Spending")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Income")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                    Text(review.totalIncome, format: .currency(code: "USD"))
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.positive)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Spending")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                    Text(review.totalSpending, format: .currency(code: "USD"))
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.negative)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Savings Rate")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                    Text(review.savingsRate, format: .percent.precision(.fractionLength(1)))
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.textPrimary)
                }
            }
        }
        .padding(16)
        .background(WMColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Top Categories

    private func topCategoriesSection(review: AnnualReviewDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Top Spending Categories")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            ForEach(Array(review.topCategories.enumerated()), id: \.offset) { _, category in
                CategoryRow(category: category)
            }
        }
    }

    // MARK: - Goal Progress

    private func goalProgressSection(review: AnnualReviewDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Goal Progress")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            ForEach(Array(review.goalProgress.enumerated()), id: \.offset) { _, goal in
                GoalProgressRow(goal: goal)
            }
        }
    }

    // MARK: - Action Items

    private func actionItemsSection(review: AnnualReviewDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Action Items for Next Year")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            ForEach(Array(review.actionItems.enumerated()), id: \.offset) { _, item in
                Label(item, systemImage: "arrow.right.circle")
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(WMColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(WMColors.negative)
            Text(message)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await viewModel.generateReview() }
            }
            .buttonStyle(.bordered)
        }
        .padding(24)
    }
}

// MARK: - CategoryRow

private struct CategoryRow: View {
    let category: CategorySummary

    var body: some View {
        HStack {
            Text(category.name)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
            Spacer()
            Text(category.amount, format: .currency(code: "USD"))
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(WMColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - GoalProgressRow

private struct GoalProgressRow: View {
    let goal: GoalProgressSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(goal.name)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
                Spacer()
                Image(systemName: goal.onTrack ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(goal.onTrack ? WMColors.positive : WMColors.negative)
            }
            ProgressView(value: NSDecimalNumber(decimal: goal.progressPercent).doubleValue)
                .tint(goal.onTrack ? WMColors.positive : WMColors.secondary)
            Text("\(goal.progressPercent, format: .percent.precision(.fractionLength(0))) complete")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
        }
        .padding(12)
        .background(WMColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

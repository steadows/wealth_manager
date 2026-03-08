import Foundation

/// Summary model for a budget category with spending data.
struct BudgetCategorySummary: Identifiable {
    let id: UUID
    let category: TransactionCategory
    let budgetLimit: Decimal
    let spent: Decimal
    let trend: Trend

    enum Trend {
        case up, down, flat
    }

    /// Fraction of budget used (spent / limit).
    var percentUsed: Double {
        guard budgetLimit > 0 else { return 0 }
        return NSDecimalNumber(decimal: spent / budgetLimit).doubleValue
    }
}

/// ViewModel for the monthly budget view.
@Observable
final class BudgetViewModel {

    // MARK: - Published State

    var categories: [BudgetCategorySummary] = []
    var totalIncome: Decimal = 0
    var totalSpent: Decimal = 0
    var selectedMonth: Date = Date()
    var isLoading: Bool = false
    var error: Error?

    // MARK: - Dependencies

    private let budgetRepo: BudgetCategoryRepository
    private let transactionRepo: TransactionRepository

    // MARK: - Init

    init(budgetRepo: BudgetCategoryRepository, transactionRepo: TransactionRepository) {
        self.budgetRepo = budgetRepo
        self.transactionRepo = transactionRepo
    }

    // MARK: - Computed

    /// Remaining budget for the month.
    var remaining: Decimal {
        totalIncome - totalSpent
    }

    /// Human-readable name for the selected month.
    var selectedMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonth)
    }

    // MARK: - Actions

    /// Loads budget data for the given month.
    func loadBudget(for date: Date) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)

        do {
            let budgetCategories = try await budgetRepo.fetchForMonth(month: month, year: year)

            let monthRange = monthDateRange(for: date)
            let transactions = try await transactionRepo.fetchByDateRange(monthRange)

            // Single-pass aggregation: O(n) instead of O(k * n)
            var spentByCategory: [TransactionCategory: Decimal] = [:]
            var incomeTotal: Decimal = 0
            var spendingTotal: Decimal = 0

            for txn in transactions {
                if txn.category == .income {
                    incomeTotal += txn.amount
                } else {
                    let absAmount = abs(txn.amount)
                    spendingTotal += absAmount
                    spentByCategory[txn.category, default: .zero] += absAmount
                }
            }

            totalIncome = incomeTotal
            totalSpent = spendingTotal

            categories = budgetCategories.map { budget in
                BudgetCategorySummary(
                    id: budget.id,
                    category: budget.category,
                    budgetLimit: budget.monthlyLimit,
                    spent: spentByCategory[budget.category, default: .zero],
                    trend: .flat
                )
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Navigate to the previous month.
    func previousMonth() async {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = newDate
            await loadBudget(for: selectedMonth)
        }
    }

    /// Navigate to the next month.
    func nextMonth() async {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = newDate
            await loadBudget(for: selectedMonth)
        }
    }

    // MARK: - Private

    /// Returns the date range for the entire month containing the given date.
    private func monthDateRange(for date: Date) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        ) ?? date
        let end = calendar.date(
            byAdding: DateComponents(month: 1, second: -1),
            to: start
        ) ?? date
        return start...end
    }
}

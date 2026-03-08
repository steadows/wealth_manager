import Foundation

/// ViewModel for the main Dashboard, orchestrating data from multiple repositories.
@Observable
final class DashboardViewModel {

    // MARK: - Published State

    var netWorth: Decimal = 0
    var totalAssets: Decimal = 0
    var totalLiabilities: Decimal = 0
    var netWorthChange: Decimal = 0
    var healthScore: Int = 0
    var recentTransactions: [Transaction] = []
    var activeGoals: [FinancialGoal] = []
    var isLoading: Bool = false
    var error: Error?

    // MARK: - Dependencies

    private let accountRepo: AccountRepository
    private let transactionRepo: TransactionRepository
    private let snapshotRepo: SnapshotRepository
    private let healthScoreRepo: HealthScoreRepository
    private let goalRepo: GoalRepository

    // MARK: - Init

    init(
        accountRepo: AccountRepository,
        transactionRepo: TransactionRepository,
        snapshotRepo: SnapshotRepository,
        healthScoreRepo: HealthScoreRepository,
        goalRepo: GoalRepository
    ) {
        self.accountRepo = accountRepo
        self.transactionRepo = transactionRepo
        self.snapshotRepo = snapshotRepo
        self.healthScoreRepo = healthScoreRepo
        self.goalRepo = goalRepo
    }

    // MARK: - Data Loading

    /// Fetches all dashboard data from repositories.
    func loadDashboard() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let assets = try await accountRepo.totalAssets()
            let liabilities = try await accountRepo.totalLiabilities()
            let transactions = try await transactionRepo.fetchRecent(limit: 10)
            let latestScore = try await healthScoreRepo.fetchLatest()
            let goals = try await goalRepo.fetchActive()
            let latestSnapshot = try await snapshotRepo.fetchLatest()

            totalAssets = assets
            totalLiabilities = liabilities
            netWorth = assets - liabilities
            recentTransactions = transactions
            healthScore = latestScore?.overallScore ?? 0
            activeGoals = goals

            if let previousNetWorth = latestSnapshot?.netWorth {
                netWorthChange = netWorth - previousNetWorth
            } else {
                netWorthChange = 0
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }
}

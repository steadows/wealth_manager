import Foundation
import Testing

@testable import wealth_manager

// MARK: - Test Data Helpers

/// Builds a test Account with sensible defaults.
private func makeAccount(
    id: UUID = UUID(),
    type: AccountType = .checking,
    balance: Decimal = 1000,
    institutionName: String = "Test Bank",
    accountName: String = "Test Account"
) -> Account {
    Account(
        id: id,
        institutionName: institutionName,
        accountName: accountName,
        accountType: type,
        currentBalance: balance,
        isManual: true
    )
}

/// Builds a test Transaction with sensible defaults.
private func makeTransaction(
    id: UUID = UUID(),
    account: Account,
    amount: Decimal = 50,
    date: Date = Date(),
    category: TransactionCategory = .food,
    merchantName: String? = "Test Merchant"
) -> Transaction {
    Transaction(
        id: id,
        account: account,
        amount: amount,
        date: date,
        merchantName: merchantName,
        category: category
    )
}

/// Builds a test Debt with sensible defaults.
private func makeDebt(
    id: UUID = UUID(),
    name: String = "Test Debt",
    type: DebtType = .creditCard,
    originalBalance: Decimal = 5000,
    currentBalance: Decimal = 3000,
    interestRate: Decimal = Decimal(string: "0.18")!,
    minimumPayment: Decimal = 100
) -> Debt {
    Debt(
        id: id,
        debtName: name,
        debtType: type,
        originalBalance: originalBalance,
        currentBalance: currentBalance,
        interestRate: interestRate,
        minimumPayment: minimumPayment,
        isFixedRate: true
    )
}

/// Builds a test FinancialGoal with sensible defaults.
private func makeGoal(
    id: UUID = UUID(),
    name: String = "Test Goal",
    type: GoalType = .emergencyFund,
    targetAmount: Decimal = 10000,
    currentAmount: Decimal = 2000,
    priority: Int = 1,
    isActive: Bool = true
) -> FinancialGoal {
    FinancialGoal(
        id: id,
        goalName: name,
        goalType: type,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        priority: priority,
        isActive: isActive
    )
}

/// Builds a test UserProfile with sensible defaults.
private func makeProfile(
    id: UUID = UUID(),
    annualIncome: Decimal? = 85000,
    monthlyExpenses: Decimal? = 4000
) -> UserProfile {
    UserProfile(
        id: id,
        annualIncome: annualIncome,
        monthlyExpenses: monthlyExpenses
    )
}

/// Builds a test NetWorthSnapshot with sensible defaults.
private func makeSnapshot(
    id: UUID = UUID(),
    date: Date = Date(),
    totalAssets: Decimal = 100000,
    totalLiabilities: Decimal = 30000
) -> NetWorthSnapshot {
    NetWorthSnapshot(
        id: id,
        date: date,
        totalAssets: totalAssets,
        totalLiabilities: totalLiabilities
    )
}

/// Builds a test BudgetCategory with sensible defaults.
private func makeBudgetCategory(
    id: UUID = UUID(),
    category: TransactionCategory = .food,
    monthlyLimit: Decimal = 500,
    month: Int = 3,
    year: Int = 2026
) -> BudgetCategory {
    BudgetCategory(
        id: id,
        category: category,
        monthlyLimit: monthlyLimit,
        month: month,
        year: year
    )
}

/// Builds a test FinancialHealthScore with sensible defaults.
private func makeHealthScore(
    id: UUID = UUID(),
    date: Date = Date(),
    overallScore: Int = 75,
    savingsScore: Int = 80,
    debtScore: Int = 70,
    investmentScore: Int = 65,
    emergencyFundScore: Int = 85,
    insuranceScore: Int = 60
) -> FinancialHealthScore {
    FinancialHealthScore(
        id: id,
        date: date,
        overallScore: overallScore,
        savingsScore: savingsScore,
        debtScore: debtScore,
        investmentScore: investmentScore,
        emergencyFundScore: emergencyFundScore,
        insuranceScore: insuranceScore
    )
}

/// Returns a Date offset from the reference date by the given number of days.
private func dateOffset(days: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: days, to: Date())!
}

// MARK: - MockAccountRepositoryTests

@Suite("MockAccountRepository")
struct MockAccountRepositoryTests {

    @Test("fetchAll returns all inserted accounts")
    func fetchAllReturnsAllAccounts() async throws {
        let repo = MockAccountRepository()
        let a1 = makeAccount(type: .checking, balance: 500)
        let a2 = makeAccount(type: .savings, balance: 1500)
        try await repo.create(a1)
        try await repo.create(a2)

        let all = try await repo.fetchAll()
        #expect(all.count == 2)
    }

    @Test("fetchById returns correct account")
    func fetchByIdReturnsCorrectAccount() async throws {
        let repo = MockAccountRepository()
        let id = UUID()
        let account = makeAccount(id: id, type: .checking, balance: 250)
        try await repo.create(account)

        let fetched = try await repo.fetchById(id)
        #expect(fetched != nil)
        #expect(fetched?.id == id)
        #expect(fetched?.currentBalance == 250)
    }

    @Test("fetchById returns nil for unknown ID")
    func fetchByIdReturnsNilForUnknownId() async throws {
        let repo = MockAccountRepository()
        try await repo.create(makeAccount())

        let result = try await repo.fetchById(UUID())
        #expect(result == nil)
    }

    @Test("fetchByType filters correctly")
    func fetchByTypeFilters() async throws {
        let repo = MockAccountRepository()
        try await repo.create(makeAccount(type: .checking, balance: 100))
        try await repo.create(makeAccount(type: .savings, balance: 200))
        try await repo.create(makeAccount(type: .checking, balance: 300))
        try await repo.create(makeAccount(type: .creditCard, balance: 400))

        let checkingAccounts = try await repo.fetchByType(.checking)
        #expect(checkingAccounts.count == 2)

        let savingsAccounts = try await repo.fetchByType(.savings)
        #expect(savingsAccounts.count == 1)

        let creditCardAccounts = try await repo.fetchByType(.creditCard)
        #expect(creditCardAccounts.count == 1)
    }

    @Test("create adds account to storage")
    func createAddsAccount() async throws {
        let repo = MockAccountRepository()
        #expect(try await repo.fetchAll().isEmpty)

        let account = makeAccount()
        try await repo.create(account)

        let all = try await repo.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.id == account.id)
    }

    @Test("update modifies existing account")
    func updateModifiesAccount() async throws {
        let repo = MockAccountRepository()
        let id = UUID()
        let original = makeAccount(id: id, balance: 500)
        try await repo.create(original)

        let updated = makeAccount(id: id, balance: 750, accountName: "Updated")
        try await repo.update(updated)

        let fetched = try await repo.fetchById(id)
        #expect(fetched?.currentBalance == 750)
        #expect(fetched?.accountName == "Updated")
    }

    @Test("delete removes account from storage")
    func deleteRemovesAccount() async throws {
        let repo = MockAccountRepository()
        let account = makeAccount()
        try await repo.create(account)
        #expect(try await repo.fetchAll().count == 1)

        try await repo.delete(account)
        #expect(try await repo.fetchAll().isEmpty)
    }

    @Test("totalAssets sums asset account balances correctly")
    func totalAssetsSumsCorrectly() async throws {
        let repo = MockAccountRepository()
        try await repo.create(makeAccount(type: .checking, balance: 1000))
        try await repo.create(makeAccount(type: .savings, balance: 2000))
        try await repo.create(makeAccount(type: .investment, balance: 5000))
        try await repo.create(makeAccount(type: .creditCard, balance: 3000))

        let assets = try await repo.totalAssets()
        #expect(assets == 8000)
    }

    @Test("totalLiabilities sums liability account balances correctly")
    func totalLiabilitiesSumsCorrectly() async throws {
        let repo = MockAccountRepository()
        try await repo.create(makeAccount(type: .checking, balance: 1000))
        try await repo.create(makeAccount(type: .creditCard, balance: 3000))
        try await repo.create(makeAccount(type: .loan, balance: 15000))

        let liabilities = try await repo.totalLiabilities()
        #expect(liabilities == 18000)
    }

    @Test("empty repo returns empty arrays and zero totals")
    func emptyRepoDefaults() async throws {
        let repo = MockAccountRepository()

        #expect(try await repo.fetchAll().isEmpty)
        #expect(try await repo.totalAssets() == 0)
        #expect(try await repo.totalLiabilities() == 0)
    }
}

// MARK: - MockTransactionRepositoryTests

@Suite("MockTransactionRepository")
struct MockTransactionRepositoryTests {

    @Test("fetchAll returns all transactions")
    func fetchAllReturns() async throws {
        let repo = MockTransactionRepository()
        let account = makeAccount()
        try await repo.create(makeTransaction(account: account, amount: 10))
        try await repo.create(makeTransaction(account: account, amount: 20))
        try await repo.create(makeTransaction(account: account, amount: 30))

        let all = try await repo.fetchAll()
        #expect(all.count == 3)
    }

    @Test("fetchById returns correct transaction")
    func fetchByIdReturnsCorrect() async throws {
        let repo = MockTransactionRepository()
        let account = makeAccount()
        let id = UUID()
        let txn = makeTransaction(id: id, account: account, amount: 42)
        try await repo.create(txn)

        let fetched = try await repo.fetchById(id)
        #expect(fetched != nil)
        #expect(fetched?.amount == 42)
    }

    @Test("fetchByAccount filters by account ID")
    func fetchByAccountFilters() async throws {
        let repo = MockTransactionRepository()
        let account1 = makeAccount()
        let account2 = makeAccount()
        try await repo.create(makeTransaction(account: account1, amount: 10))
        try await repo.create(makeTransaction(account: account1, amount: 20))
        try await repo.create(makeTransaction(account: account2, amount: 30))

        let forAccount1 = try await repo.fetchByAccount(account1.id)
        #expect(forAccount1.count == 2)

        let forAccount2 = try await repo.fetchByAccount(account2.id)
        #expect(forAccount2.count == 1)
    }

    @Test("fetchByDateRange returns transactions within range")
    func fetchByDateRangeFilters() async throws {
        let repo = MockTransactionRepository()
        let account = makeAccount()
        let pastDate = dateOffset(days: -10)
        let midDate = dateOffset(days: -5)
        let futureDate = dateOffset(days: 10)

        try await repo.create(makeTransaction(account: account, amount: 10, date: pastDate))
        try await repo.create(makeTransaction(account: account, amount: 20, date: midDate))
        try await repo.create(makeTransaction(account: account, amount: 30, date: futureDate))

        let rangeStart = dateOffset(days: -7)
        let rangeEnd = dateOffset(days: -3)
        let filtered = try await repo.fetchByDateRange(rangeStart...rangeEnd)
        #expect(filtered.count == 1)
        #expect(filtered.first?.amount == 20)
    }

    @Test("fetchByCategory filters correctly")
    func fetchByCategoryFilters() async throws {
        let repo = MockTransactionRepository()
        let account = makeAccount()
        try await repo.create(makeTransaction(account: account, category: .food))
        try await repo.create(makeTransaction(account: account, category: .food))
        try await repo.create(makeTransaction(account: account, category: .entertainment))

        let food = try await repo.fetchByCategory(.food)
        #expect(food.count == 2)

        let entertainment = try await repo.fetchByCategory(.entertainment)
        #expect(entertainment.count == 1)
    }

    @Test("fetchRecent returns limited results sorted by date")
    func fetchRecentReturnsLimitedSorted() async throws {
        let repo = MockTransactionRepository()
        let account = makeAccount()
        try await repo.create(makeTransaction(account: account, amount: 10, date: dateOffset(days: -3)))
        try await repo.create(makeTransaction(account: account, amount: 30, date: dateOffset(days: -1)))
        try await repo.create(makeTransaction(account: account, amount: 20, date: dateOffset(days: -2)))
        try await repo.create(makeTransaction(account: account, amount: 40, date: dateOffset(days: 0)))

        let recent = try await repo.fetchRecent(limit: 2)
        #expect(recent.count == 2)
        // Most recent first
        #expect(recent[0].amount == 40)
        #expect(recent[1].amount == 30)
    }

    @Test("CRUD operations work")
    func crudOperations() async throws {
        let repo = MockTransactionRepository()
        let account = makeAccount()
        let id = UUID()

        // Create
        let txn = makeTransaction(id: id, account: account, amount: 100)
        try await repo.create(txn)
        #expect(try await repo.fetchAll().count == 1)

        // Update
        let updatedTxn = makeTransaction(id: id, account: account, amount: 200)
        try await repo.update(updatedTxn)
        let fetched = try await repo.fetchById(id)
        #expect(fetched?.amount == 200)

        // Delete
        try await repo.delete(updatedTxn)
        #expect(try await repo.fetchAll().isEmpty)
    }
}

// MARK: - MockDebtRepositoryTests

@Suite("MockDebtRepository")
struct MockDebtRepositoryTests {

    @Test("CRUD operations work")
    func crudOperations() async throws {
        let repo = MockDebtRepository()
        let id = UUID()

        // Create
        let debt = makeDebt(id: id, currentBalance: 3000)
        try await repo.create(debt)
        #expect(try await repo.fetchAll().count == 1)

        // Read
        let fetched = try await repo.fetchById(id)
        #expect(fetched != nil)
        #expect(fetched?.currentBalance == 3000)

        // Update
        let updatedDebt = makeDebt(id: id, currentBalance: 2500)
        try await repo.update(updatedDebt)
        let refetched = try await repo.fetchById(id)
        #expect(refetched?.currentBalance == 2500)

        // Delete
        try await repo.delete(updatedDebt)
        #expect(try await repo.fetchAll().isEmpty)
    }

    @Test("totalDebt sums correctly")
    func totalDebtSums() async throws {
        let repo = MockDebtRepository()
        try await repo.create(makeDebt(currentBalance: 1000))
        try await repo.create(makeDebt(currentBalance: 2500))
        try await repo.create(makeDebt(currentBalance: 500))

        let total = try await repo.totalDebt()
        #expect(total == 4000)
    }

    @Test("empty repo returns zero total")
    func emptyRepoReturnsZero() async throws {
        let repo = MockDebtRepository()
        let total = try await repo.totalDebt()
        #expect(total == 0)
    }
}

// MARK: - MockGoalRepositoryTests

@Suite("MockGoalRepository")
struct MockGoalRepositoryTests {

    @Test("CRUD operations work")
    func crudOperations() async throws {
        let repo = MockGoalRepository()
        let id = UUID()

        // Create
        let goal = makeGoal(id: id, name: "Emergency Fund", targetAmount: 10000)
        try await repo.create(goal)
        #expect(try await repo.fetchAll().count == 1)

        // Read
        let fetched = try await repo.fetchById(id)
        #expect(fetched != nil)
        #expect(fetched?.goalName == "Emergency Fund")

        // Update
        let updatedGoal = makeGoal(id: id, name: "Bigger Emergency Fund", targetAmount: 15000)
        try await repo.update(updatedGoal)
        let refetched = try await repo.fetchById(id)
        #expect(refetched?.goalName == "Bigger Emergency Fund")
        #expect(refetched?.targetAmount == 15000)

        // Delete
        try await repo.delete(updatedGoal)
        #expect(try await repo.fetchAll().isEmpty)
    }

    @Test("fetchActive returns only active goals")
    func fetchActiveReturnsOnlyActive() async throws {
        let repo = MockGoalRepository()
        try await repo.create(makeGoal(name: "Active 1", isActive: true))
        try await repo.create(makeGoal(name: "Active 2", isActive: true))
        try await repo.create(makeGoal(name: "Inactive", isActive: false))

        let active = try await repo.fetchActive()
        #expect(active.count == 2)
        for goal in active {
            #expect(goal.isActive == true)
        }
    }

    @Test("inactive goals are excluded from fetchActive")
    func inactiveExcludedFromFetchActive() async throws {
        let repo = MockGoalRepository()
        try await repo.create(makeGoal(name: "Done", isActive: false))
        try await repo.create(makeGoal(name: "Also Done", isActive: false))

        let active = try await repo.fetchActive()
        #expect(active.isEmpty)

        // But fetchAll still returns them
        let all = try await repo.fetchAll()
        #expect(all.count == 2)
    }
}

// MARK: - MockUserProfileRepositoryTests

@Suite("MockUserProfileRepository")
struct MockUserProfileRepositoryTests {

    @Test("fetch returns nil initially")
    func fetchReturnsNilInitially() async throws {
        let repo = MockUserProfileRepository()
        let profile = try await repo.fetch()
        #expect(profile == nil)
    }

    @Test("createOrUpdate creates profile")
    func createOrUpdateCreates() async throws {
        let repo = MockUserProfileRepository()
        let profile = makeProfile(annualIncome: 100000)
        try await repo.createOrUpdate(profile)

        let fetched = try await repo.fetch()
        #expect(fetched != nil)
        #expect(fetched?.annualIncome == 100000)
    }

    @Test("createOrUpdate updates existing profile")
    func createOrUpdateUpdates() async throws {
        let repo = MockUserProfileRepository()
        let original = makeProfile(annualIncome: 80000)
        try await repo.createOrUpdate(original)

        let updated = makeProfile(annualIncome: 95000)
        try await repo.createOrUpdate(updated)

        let fetched = try await repo.fetch()
        #expect(fetched != nil)
        #expect(fetched?.annualIncome == 95000)
    }

    @Test("fetch returns the profile after create")
    func fetchReturnsAfterCreate() async throws {
        let repo = MockUserProfileRepository()
        let id = UUID()
        let profile = makeProfile(id: id, annualIncome: 120000, monthlyExpenses: 5000)
        try await repo.createOrUpdate(profile)

        let fetched = try await repo.fetch()
        #expect(fetched?.id == id)
        #expect(fetched?.annualIncome == 120000)
        #expect(fetched?.monthlyExpenses == 5000)
    }
}

// MARK: - MockSnapshotRepositoryTests

@Suite("MockSnapshotRepository")
struct MockSnapshotRepositoryTests {

    @Test("fetchAll returns all snapshots")
    func fetchAllReturns() async throws {
        let repo = MockSnapshotRepository()
        try await repo.create(makeSnapshot(date: dateOffset(days: -2)))
        try await repo.create(makeSnapshot(date: dateOffset(days: -1)))
        try await repo.create(makeSnapshot(date: dateOffset(days: 0)))

        let all = try await repo.fetchAll()
        #expect(all.count == 3)
    }

    @Test("fetchByDateRange filters correctly")
    func fetchByDateRangeFilters() async throws {
        let repo = MockSnapshotRepository()
        try await repo.create(makeSnapshot(date: dateOffset(days: -30), totalAssets: 90000, totalLiabilities: 30000))
        try await repo.create(makeSnapshot(date: dateOffset(days: -10), totalAssets: 95000, totalLiabilities: 30000))
        try await repo.create(makeSnapshot(date: dateOffset(days: -5), totalAssets: 98000, totalLiabilities: 30000))
        try await repo.create(makeSnapshot(date: dateOffset(days: 0), totalAssets: 100000, totalLiabilities: 30000))

        let rangeStart = dateOffset(days: -12)
        let rangeEnd = dateOffset(days: -4)
        let filtered = try await repo.fetchByDateRange(rangeStart...rangeEnd)
        #expect(filtered.count == 2)
    }

    @Test("fetchLatest returns most recent snapshot")
    func fetchLatestReturnsMostRecent() async throws {
        let repo = MockSnapshotRepository()
        try await repo.create(makeSnapshot(date: dateOffset(days: -10), totalAssets: 90000, totalLiabilities: 30000))
        try await repo.create(makeSnapshot(date: dateOffset(days: -5), totalAssets: 95000, totalLiabilities: 30000))
        try await repo.create(makeSnapshot(date: dateOffset(days: -1), totalAssets: 100000, totalLiabilities: 30000))

        let latest = try await repo.fetchLatest()
        #expect(latest != nil)
        #expect(latest?.netWorth == 70000)
    }

    @Test("fetchLatest returns nil when empty")
    func fetchLatestReturnsNilWhenEmpty() async throws {
        let repo = MockSnapshotRepository()
        let latest = try await repo.fetchLatest()
        #expect(latest == nil)
    }
}

// MARK: - MockBudgetCategoryRepositoryTests

@Suite("MockBudgetCategoryRepository")
struct MockBudgetCategoryRepositoryTests {

    @Test("CRUD operations work")
    func crudOperations() async throws {
        let repo = MockBudgetCategoryRepository()
        let id = UUID()

        // Create
        let budget = makeBudgetCategory(id: id, category: .food, monthlyLimit: 600)
        try await repo.create(budget)
        #expect(try await repo.fetchAll().count == 1)

        // Update
        let updatedBudget = makeBudgetCategory(id: id, category: .food, monthlyLimit: 700)
        try await repo.update(updatedBudget)
        let all = try await repo.fetchAll()
        #expect(all.first?.monthlyLimit == 700)

        // Delete
        try await repo.delete(updatedBudget)
        #expect(try await repo.fetchAll().isEmpty)
    }

    @Test("fetchForMonth filters by month and year correctly")
    func fetchForMonthFilters() async throws {
        let repo = MockBudgetCategoryRepository()
        try await repo.create(makeBudgetCategory(category: .food, month: 3, year: 2026))
        try await repo.create(makeBudgetCategory(category: .entertainment, month: 3, year: 2026))
        try await repo.create(makeBudgetCategory(category: .food, month: 4, year: 2026))
        try await repo.create(makeBudgetCategory(category: .food, month: 3, year: 2025))

        let march2026 = try await repo.fetchForMonth(month: 3, year: 2026)
        #expect(march2026.count == 2)

        let april2026 = try await repo.fetchForMonth(month: 4, year: 2026)
        #expect(april2026.count == 1)

        let march2025 = try await repo.fetchForMonth(month: 3, year: 2025)
        #expect(march2025.count == 1)

        let noResults = try await repo.fetchForMonth(month: 12, year: 2024)
        #expect(noResults.isEmpty)
    }
}

// MARK: - MockHealthScoreRepositoryTests

@Suite("MockHealthScoreRepository")
struct MockHealthScoreRepositoryTests {

    @Test("fetchLatest returns most recent score")
    func fetchLatestReturnsMostRecent() async throws {
        let repo = MockHealthScoreRepository()
        try await repo.create(makeHealthScore(date: dateOffset(days: -10), overallScore: 60))
        try await repo.create(makeHealthScore(date: dateOffset(days: -5), overallScore: 70))
        try await repo.create(makeHealthScore(date: dateOffset(days: -1), overallScore: 80))

        let latest = try await repo.fetchLatest()
        #expect(latest != nil)
        #expect(latest?.overallScore == 80)
    }

    @Test("fetchByDateRange filters correctly")
    func fetchByDateRangeFilters() async throws {
        let repo = MockHealthScoreRepository()
        try await repo.create(makeHealthScore(date: dateOffset(days: -30), overallScore: 55))
        try await repo.create(makeHealthScore(date: dateOffset(days: -10), overallScore: 65))
        try await repo.create(makeHealthScore(date: dateOffset(days: -5), overallScore: 70))
        try await repo.create(makeHealthScore(date: dateOffset(days: 0), overallScore: 80))

        let rangeStart = dateOffset(days: -12)
        let rangeEnd = dateOffset(days: -4)
        let filtered = try await repo.fetchByDateRange(rangeStart...rangeEnd)
        #expect(filtered.count == 2)
    }

    @Test("create adds score")
    func createAddsScore() async throws {
        let repo = MockHealthScoreRepository()
        let score = makeHealthScore(
            overallScore: 90,
            savingsScore: 95,
            debtScore: 85,
            investmentScore: 88,
            emergencyFundScore: 92,
            insuranceScore: 80
        )
        try await repo.create(score)

        let latest = try await repo.fetchLatest()
        #expect(latest != nil)
        #expect(latest?.overallScore == 90)
        #expect(latest?.savingsScore == 95)
        #expect(latest?.debtScore == 85)
    }

    @Test("fetchLatest returns nil when empty")
    func fetchLatestReturnsNilWhenEmpty() async throws {
        let repo = MockHealthScoreRepository()
        let latest = try await repo.fetchLatest()
        #expect(latest == nil)
    }
}

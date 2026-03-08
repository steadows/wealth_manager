import Testing
import Foundation
@testable import wealth_manager

// MARK: - Test Helpers

/// Creates a minimal Account for use as a dependency in other model tests.
private func makeAccount(
    accountType: AccountType = .checking,
    balance: Decimal = 1000
) -> Account {
    Account(
        institutionName: "Test Bank",
        accountName: "Test Account",
        accountType: accountType,
        currentBalance: balance,
        isManual: true
    )
}

// MARK: - AccountTests

@Suite("Account Model")
struct AccountTests {

    @Test("isAsset returns true for checking")
    func isAssetChecking() {
        let account = makeAccount(accountType: .checking)
        #expect(account.isAsset == true)
    }

    @Test("isAsset returns true for savings")
    func isAssetSavings() {
        let account = makeAccount(accountType: .savings)
        #expect(account.isAsset == true)
    }

    @Test("isAsset returns true for investment")
    func isAssetInvestment() {
        let account = makeAccount(accountType: .investment)
        #expect(account.isAsset == true)
    }

    @Test("isAsset returns true for retirement")
    func isAssetRetirement() {
        let account = makeAccount(accountType: .retirement)
        #expect(account.isAsset == true)
    }

    @Test("isAsset returns false for creditCard")
    func isAssetCreditCard() {
        let account = makeAccount(accountType: .creditCard)
        #expect(account.isAsset == false)
    }

    @Test("isAsset returns false for loan")
    func isAssetLoan() {
        let account = makeAccount(accountType: .loan)
        #expect(account.isAsset == false)
    }

    @Test("isAsset returns false for other")
    func isAssetOther() {
        let account = makeAccount(accountType: .other)
        #expect(account.isAsset == false)
    }

    @Test("isLiability returns true for creditCard")
    func isLiabilityCreditCard() {
        let account = makeAccount(accountType: .creditCard)
        #expect(account.isLiability == true)
    }

    @Test("isLiability returns true for loan")
    func isLiabilityLoan() {
        let account = makeAccount(accountType: .loan)
        #expect(account.isLiability == true)
    }

    @Test("isLiability returns false for checking")
    func isLiabilityChecking() {
        let account = makeAccount(accountType: .checking)
        #expect(account.isLiability == false)
    }

    @Test("isLiability returns false for savings")
    func isLiabilitySavings() {
        let account = makeAccount(accountType: .savings)
        #expect(account.isLiability == false)
    }

    @Test("isLiability returns false for investment")
    func isLiabilityInvestment() {
        let account = makeAccount(accountType: .investment)
        #expect(account.isLiability == false)
    }

    @Test("isLiability returns false for retirement")
    func isLiabilityRetirement() {
        let account = makeAccount(accountType: .retirement)
        #expect(account.isLiability == false)
    }

    @Test("isLiability returns false for other")
    func isLiabilityOther() {
        let account = makeAccount(accountType: .other)
        #expect(account.isLiability == false)
    }

    @Test("formattedBalance formats USD correctly")
    func formattedBalanceUSD() {
        let account = makeAccount(balance: Decimal(string: "1234.56")!)
        #expect(account.formattedBalance == "$1,234.56")
    }

    @Test("Default initializer sets reasonable defaults")
    func defaultInitializerDefaults() {
        let before = Date()
        let account = Account(
            institutionName: "Bank",
            accountName: "Checking",
            accountType: .checking,
            currentBalance: 500,
            isManual: false
        )
        let after = Date()

        #expect(account.currency == "USD")
        #expect(account.isHidden == false)
        #expect(account.plaidAccountId == nil)
        #expect(account.availableBalance == nil)
        #expect(account.lastSyncedAt == nil)
        #expect(account.transactions.isEmpty)
        #expect(account.holdings.isEmpty)
        #expect(account.createdAt >= before)
        #expect(account.createdAt <= after)
        #expect(account.updatedAt >= before)
        #expect(account.updatedAt <= after)
    }
}

// MARK: - TransactionTests

@Suite("Transaction Model")
struct TransactionTests {

    @Test("Init stores all values correctly")
    func initStoresValues() {
        let account = makeAccount()
        let id = UUID()
        let date = Date()
        let transaction = Transaction(
            id: id,
            plaidTransactionId: "plaid_123",
            account: account,
            amount: Decimal(string: "42.99")!,
            date: date,
            merchantName: "Coffee Shop",
            category: .food,
            subcategory: "Coffee",
            note: "Morning latte",
            isRecurring: true,
            isPending: true,
            createdAt: date
        )

        #expect(transaction.id == id)
        #expect(transaction.plaidTransactionId == "plaid_123")
        #expect(transaction.amount == Decimal(string: "42.99")!)
        #expect(transaction.date == date)
        #expect(transaction.merchantName == "Coffee Shop")
        #expect(transaction.category == .food)
        #expect(transaction.subcategory == "Coffee")
        #expect(transaction.note == "Morning latte")
        #expect(transaction.isRecurring == true)
        #expect(transaction.isPending == true)
    }

    @Test("Default isPending is false")
    func defaultIsPending() {
        let account = makeAccount()
        let transaction = Transaction(
            account: account,
            amount: 10,
            date: Date(),
            category: .food
        )
        #expect(transaction.isPending == false)
    }

    @Test("Default isRecurring is false")
    func defaultIsRecurring() {
        let account = makeAccount()
        let transaction = Transaction(
            account: account,
            amount: 10,
            date: Date(),
            category: .food
        )
        #expect(transaction.isRecurring == false)
    }
}

// MARK: - InvestmentHoldingTests

@Suite("InvestmentHolding Model")
struct InvestmentHoldingTests {

    @Test("gainLoss computed correctly with costBasis")
    func gainLossWithCostBasis() {
        let account = makeAccount(accountType: .investment)
        let holding = InvestmentHolding(
            account: account,
            securityName: "AAPL",
            tickerSymbol: "AAPL",
            quantity: 10,
            costBasis: 100,
            currentPrice: 120,
            holdingType: .stock,
            assetClass: .usEquity
        )
        // gainLoss = currentValue - (costBasis * quantity) = 1200 - (100 * 10) = 200
        #expect(holding.gainLoss == 200)
    }

    @Test("gainLoss returns nil when costBasis is nil")
    func gainLossNilCostBasis() {
        let account = makeAccount(accountType: .investment)
        let holding = InvestmentHolding(
            account: account,
            securityName: "AAPL",
            quantity: 10,
            costBasis: nil,
            currentPrice: 120,
            holdingType: .stock,
            assetClass: .usEquity
        )
        #expect(holding.gainLoss == nil)
    }

    @Test("gainLossPercent computed correctly")
    func gainLossPercentWithCostBasis() {
        let account = makeAccount(accountType: .investment)
        let holding = InvestmentHolding(
            account: account,
            securityName: "AAPL",
            tickerSymbol: "AAPL",
            quantity: 10,
            costBasis: 100,
            currentPrice: 120,
            holdingType: .stock,
            assetClass: .usEquity
        )
        // gainLossPercent = (1200 - 1000) / 1000 = 0.2
        let expected: Decimal = Decimal(string: "0.2")!
        #expect(holding.gainLossPercent == expected)
    }

    @Test("gainLossPercent returns nil when costBasis is nil")
    func gainLossPercentNilCostBasis() {
        let account = makeAccount(accountType: .investment)
        let holding = InvestmentHolding(
            account: account,
            securityName: "AAPL",
            quantity: 10,
            costBasis: nil,
            currentPrice: 120,
            holdingType: .stock,
            assetClass: .usEquity
        )
        #expect(holding.gainLossPercent == nil)
    }

    @Test("gainLossPercent returns nil when costBasis is zero")
    func gainLossPercentZeroCostBasis() {
        let account = makeAccount(accountType: .investment)
        let holding = InvestmentHolding(
            account: account,
            securityName: "AAPL",
            quantity: 10,
            costBasis: 0,
            currentPrice: 120,
            holdingType: .stock,
            assetClass: .usEquity
        )
        #expect(holding.gainLossPercent == nil)
    }
}

// MARK: - DebtTests

@Suite("Debt Model")
struct DebtTests {

    @Test("monthlyInterest computes correctly")
    func monthlyInterestCalculation() {
        let debt = Debt(
            debtName: "Car Loan",
            debtType: .auto,
            originalBalance: 20000,
            currentBalance: 10000,
            interestRate: Decimal(string: "0.06")!,
            minimumPayment: 300,
            isFixedRate: true
        )
        // monthlyInterest = 10000 * 0.06 / 12 = 50
        #expect(debt.monthlyInterest == 50)
    }

    @Test("payoffProgress computes correctly")
    func payoffProgressCalculation() {
        let debt = Debt(
            debtName: "Car Loan",
            debtType: .auto,
            originalBalance: 20000,
            currentBalance: 15000,
            interestRate: Decimal(string: "0.06")!,
            minimumPayment: 300,
            isFixedRate: true
        )
        // payoffProgress = 1 - 15000/20000 = 1 - 0.75 = 0.25
        #expect(debt.payoffProgress == Decimal(string: "0.25")!)
    }

    @Test("payoffProgress handles zero originalBalance without crashing")
    func payoffProgressZeroOriginal() {
        let debt = Debt(
            debtName: "Mystery Debt",
            debtType: .other,
            originalBalance: 0,
            currentBalance: 0,
            interestRate: 0,
            minimumPayment: 0,
            isFixedRate: true
        )
        // guard originalBalance != 0 else { return 1 }
        #expect(debt.payoffProgress == 1)
    }

    @Test("payoffProgress is zero when no payments made")
    func payoffProgressNoPayments() {
        let debt = Debt(
            debtName: "Student Loan",
            debtType: .student,
            originalBalance: 50000,
            currentBalance: 50000,
            interestRate: Decimal(string: "0.05")!,
            minimumPayment: 400,
            isFixedRate: true
        )
        // payoffProgress = 1 - 50000/50000 = 0
        #expect(debt.payoffProgress == 0)
    }
}

// MARK: - FinancialGoalTests

@Suite("FinancialGoal Model")
struct FinancialGoalTests {

    @Test("progressPercent computes correctly")
    func progressPercentCalculation() {
        let goal = FinancialGoal(
            goalName: "Emergency Fund",
            goalType: .emergencyFund,
            targetAmount: 20000,
            currentAmount: 5000,
            priority: 1
        )
        // progressPercent = 5000 / 20000 = 0.25
        #expect(goal.progressPercent == Decimal(string: "0.25")!)
    }

    @Test("progressPercent returns zero when targetAmount is zero")
    func progressPercentZeroTarget() {
        let goal = FinancialGoal(
            goalName: "Zero Goal",
            goalType: .custom,
            targetAmount: 0,
            currentAmount: 100,
            priority: 1
        )
        #expect(goal.progressPercent == 0)
    }

    @Test("remainingAmount computes correctly")
    func remainingAmountCalculation() {
        let goal = FinancialGoal(
            goalName: "House Down Payment",
            goalType: .homePurchase,
            targetAmount: 60000,
            currentAmount: 15000,
            priority: 2
        )
        // remainingAmount = 60000 - 15000 = 45000
        #expect(goal.remainingAmount == 45000)
    }

    @Test("isOnTrack returns true when no targetDate set")
    func isOnTrackNoTargetDate() {
        let goal = FinancialGoal(
            goalName: "Savings",
            goalType: .emergencyFund,
            targetAmount: 10000,
            currentAmount: 1000,
            targetDate: nil,
            priority: 1
        )
        #expect(goal.isOnTrack == true)
    }

    @Test("isOnTrack returns true when already reached target")
    func isOnTrackAlreadyReached() {
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let goal = FinancialGoal(
            goalName: "Done Goal",
            goalType: .custom,
            targetAmount: 1000,
            currentAmount: 1000,
            targetDate: pastDate,
            monthlyContribution: 100,
            priority: 1
        )
        #expect(goal.isOnTrack == true)
    }

    @Test("isOnTrack with monthlyContribution projects correctly - on track")
    func isOnTrackWithContributionOnTrack() {
        // Target: 10000, current: 5000, need 5000 more
        // Give 24 months and 500/month contribution = 12000 additional, so on track
        let futureDate = Calendar.current.date(byAdding: .month, value: 24, to: Date())!
        let goal = FinancialGoal(
            goalName: "Vacation",
            goalType: .travel,
            targetAmount: 10000,
            currentAmount: 5000,
            targetDate: futureDate,
            monthlyContribution: 500,
            priority: 3
        )
        #expect(goal.isOnTrack == true)
    }

    @Test("isOnTrack with monthlyContribution projects correctly - not on track")
    func isOnTrackWithContributionNotOnTrack() {
        // Target: 100000, current: 5000, need 95000 more
        // Give 6 months and 500/month contribution = 3000 additional
        // projected = 5000 + 3000 = 8000 < 100000
        let futureDate = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
        let goal = FinancialGoal(
            goalName: "House",
            goalType: .homePurchase,
            targetAmount: 100000,
            currentAmount: 5000,
            targetDate: futureDate,
            monthlyContribution: 500,
            priority: 1
        )
        #expect(goal.isOnTrack == false)
    }

    @Test("isOnTrack returns false when target date passed and not reached")
    func isOnTrackPastDateNotReached() {
        let pastDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        let goal = FinancialGoal(
            goalName: "Late Goal",
            goalType: .custom,
            targetAmount: 10000,
            currentAmount: 1000,
            targetDate: pastDate,
            monthlyContribution: 500,
            priority: 1
        )
        #expect(goal.isOnTrack == false)
    }

    @Test("isOnTrack with targetDate but no contribution and not reached")
    func isOnTrackNoContributionNotReached() {
        let futureDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        let goal = FinancialGoal(
            goalName: "Wishful",
            goalType: .custom,
            targetAmount: 50000,
            currentAmount: 100,
            targetDate: futureDate,
            monthlyContribution: nil,
            priority: 1
        )
        #expect(goal.isOnTrack == false)
    }
}

// MARK: - UserProfileTests

@Suite("UserProfile Model")
struct UserProfileTests {

    @Test("age returns nil when dateOfBirth is nil")
    func ageNilDOB() {
        let profile = UserProfile(dateOfBirth: nil)
        #expect(profile.age == nil)
    }

    @Test("age computes correctly from known birth date")
    func ageComputesCorrectly() {
        // Use a date exactly 30 years ago to get a deterministic result
        let calendar = Calendar.current
        let thirtyYearsAgo = calendar.date(byAdding: .year, value: -30, to: Date())!
        let profile = UserProfile(dateOfBirth: thirtyYearsAgo)
        #expect(profile.age == 30)
    }

    @Test("yearsToRetirement returns nil when dateOfBirth is nil")
    func yearsToRetirementNilDOB() {
        let profile = UserProfile(dateOfBirth: nil)
        #expect(profile.yearsToRetirement == nil)
    }

    @Test("yearsToRetirement computes correctly")
    func yearsToRetirementCalculation() {
        let calendar = Calendar.current
        let fortyYearsAgo = calendar.date(byAdding: .year, value: -40, to: Date())!
        let profile = UserProfile(
            dateOfBirth: fortyYearsAgo,
            retirementAge: 65
        )
        // age = 40, retirementAge = 65, yearsToRetirement = 25
        #expect(profile.yearsToRetirement == 25)
    }

    @Test("yearsToRetirement clamps to zero when past retirement age")
    func yearsToRetirementPastRetirement() {
        let calendar = Calendar.current
        let seventyYearsAgo = calendar.date(byAdding: .year, value: -70, to: Date())!
        let profile = UserProfile(
            dateOfBirth: seventyYearsAgo,
            retirementAge: 65
        )
        // age = 70, retirementAge = 65, max(0, 65 - 70) = 0
        #expect(profile.yearsToRetirement == 0)
    }

    @Test("householdIncome returns annualIncome when no spouse")
    func householdIncomeNoSpouse() {
        let profile = UserProfile(
            annualIncome: 100000,
            hasSpouse: false
        )
        #expect(profile.householdIncome == 100000)
    }

    @Test("householdIncome sums spouse income when hasSpouse is true")
    func householdIncomeWithSpouse() {
        let profile = UserProfile(
            annualIncome: 100000,
            hasSpouse: true,
            spouseIncome: 80000
        )
        #expect(profile.householdIncome == 180000)
    }

    @Test("householdIncome returns annualIncome when hasSpouse but spouseIncome is nil")
    func householdIncomeSpouseNoIncome() {
        let profile = UserProfile(
            annualIncome: 100000,
            hasSpouse: true,
            spouseIncome: nil
        )
        // hasSpouse is true but spouseIncome is nil, so the if-let fails
        // and it falls through to return income alone
        #expect(profile.householdIncome == 100000)
    }

    @Test("householdIncome returns nil when annualIncome is nil")
    func householdIncomeNilIncome() {
        let profile = UserProfile(annualIncome: nil)
        #expect(profile.householdIncome == nil)
    }

    @Test("Default initializer sets expected defaults")
    func defaultInitializer() {
        let profile = UserProfile()
        #expect(profile.filingStatus == .single)
        #expect(profile.retirementAge == 65)
        #expect(profile.riskTolerance == .moderate)
        #expect(profile.dependents == 0)
        #expect(profile.hasSpouse == false)
    }
}

// MARK: - NetWorthSnapshotTests

@Suite("NetWorthSnapshot Model")
struct NetWorthSnapshotTests {

    @Test("Init stores values correctly")
    func initStoresValues() {
        let id = UUID()
        let date = Date()
        let snapshot = NetWorthSnapshot(
            id: id,
            date: date,
            totalAssets: 500000,
            totalLiabilities: 200000
        )

        #expect(snapshot.id == id)
        #expect(snapshot.date == date)
        #expect(snapshot.totalAssets == 500000)
        #expect(snapshot.totalLiabilities == 200000)
        #expect(snapshot.netWorth == 300000)
    }

    @Test("netWorth is computed from totalAssets - totalLiabilities")
    func netWorthIsComputed() {
        let snapshot = NetWorthSnapshot(
            totalAssets: 100000,
            totalLiabilities: 40000
        )
        #expect(snapshot.netWorth == 60000)
    }
}

// MARK: - FinancialHealthScoreTests

@Suite("FinancialHealthScore Model")
struct FinancialHealthScoreTests {

    @Test("Init stores all score values")
    func initStoresScores() {
        let id = UUID()
        let date = Date()
        let score = FinancialHealthScore(
            id: id,
            date: date,
            overallScore: 85,
            savingsScore: 90,
            debtScore: 70,
            investmentScore: 80,
            emergencyFundScore: 95,
            insuranceScore: 60
        )

        #expect(score.id == id)
        #expect(score.date == date)
        #expect(score.overallScore == 85)
        #expect(score.savingsScore == 90)
        #expect(score.debtScore == 70)
        #expect(score.investmentScore == 80)
        #expect(score.emergencyFundScore == 95)
        #expect(score.insuranceScore == 60)
    }

    @Test("Scores at boundary values (0 and 100)")
    func scoresBoundaryValues() {
        let minScore = FinancialHealthScore(
            overallScore: 0,
            savingsScore: 0,
            debtScore: 0,
            investmentScore: 0,
            emergencyFundScore: 0,
            insuranceScore: 0
        )

        #expect(minScore.overallScore == 0)
        #expect(minScore.savingsScore == 0)
        #expect(minScore.debtScore == 0)
        #expect(minScore.investmentScore == 0)
        #expect(minScore.emergencyFundScore == 0)
        #expect(minScore.insuranceScore == 0)

        let maxScore = FinancialHealthScore(
            overallScore: 100,
            savingsScore: 100,
            debtScore: 100,
            investmentScore: 100,
            emergencyFundScore: 100,
            insuranceScore: 100
        )

        #expect(maxScore.overallScore == 100)
        #expect(maxScore.savingsScore == 100)
        #expect(maxScore.debtScore == 100)
        #expect(maxScore.investmentScore == 100)
        #expect(maxScore.emergencyFundScore == 100)
        #expect(maxScore.insuranceScore == 100)
    }
}

// MARK: - BudgetCategoryTests

@Suite("BudgetCategory Model")
struct BudgetCategoryTests {

    @Test("Init stores values correctly")
    func initStoresValues() {
        let id = UUID()
        let budget = BudgetCategory(
            id: id,
            category: .food,
            monthlyLimit: 500,
            month: 3,
            year: 2026
        )

        #expect(budget.id == id)
        #expect(budget.category == .food)
        #expect(budget.monthlyLimit == 500)
        #expect(budget.month == 3)
        #expect(budget.year == 2026)
    }

    @Test("isOverBudget returns false when percentUsed is placeholder zero")
    func isOverBudgetPlaceholder() {
        // percentUsed is a placeholder returning 0, so isOverBudget (percentUsed > 1) is false
        let budget = BudgetCategory(
            category: .entertainment,
            monthlyLimit: 200,
            month: 6,
            year: 2026
        )
        #expect(budget.percentUsed == 0)
        #expect(budget.isOverBudget == false)
    }

    @Test("Default createdAt and updatedAt are set")
    func defaultDates() {
        let before = Date()
        let budget = BudgetCategory(
            category: .housing,
            monthlyLimit: 2000,
            month: 1,
            year: 2026
        )
        let after = Date()

        #expect(budget.createdAt >= before)
        #expect(budget.createdAt <= after)
        #expect(budget.updatedAt >= before)
        #expect(budget.updatedAt <= after)
    }
}

// MARK: - EnumTests

@Suite("Enum Definitions")
struct EnumTests {

    // MARK: AccountType

    @Test("AccountType has 7 cases")
    func accountTypeCaseCount() {
        #expect(AccountType.allCases.count == 7)
    }

    @Test("AccountType rawValues for Codable")
    func accountTypeRawValues() {
        #expect(AccountType.checking.rawValue == "checking")
        #expect(AccountType.savings.rawValue == "savings")
        #expect(AccountType.creditCard.rawValue == "creditCard")
        #expect(AccountType.investment.rawValue == "investment")
        #expect(AccountType.loan.rawValue == "loan")
        #expect(AccountType.retirement.rawValue == "retirement")
        #expect(AccountType.other.rawValue == "other")
    }

    @Test("AccountType displayName values")
    func accountTypeDisplayNames() {
        #expect(AccountType.checking.displayName == "Checking")
        #expect(AccountType.creditCard.displayName == "Credit Card")
        #expect(AccountType.retirement.displayName == "Retirement")
    }

    // MARK: TransactionCategory

    @Test("TransactionCategory has 15 cases")
    func transactionCategoryCaseCount() {
        #expect(TransactionCategory.allCases.count == 15)
    }

    @Test("TransactionCategory rawValues for Codable")
    func transactionCategoryRawValues() {
        #expect(TransactionCategory.income.rawValue == "income")
        #expect(TransactionCategory.personalCare.rawValue == "personalCare")
        #expect(TransactionCategory.transfer.rawValue == "transfer")
    }

    @Test("TransactionCategory displayName values")
    func transactionCategoryDisplayNames() {
        #expect(TransactionCategory.personalCare.displayName == "Personal Care")
        #expect(TransactionCategory.food.displayName == "Food")
        #expect(TransactionCategory.healthcare.displayName == "Healthcare")
    }

    // MARK: DebtType

    @Test("DebtType has 7 cases")
    func debtTypeCaseCount() {
        #expect(DebtType.allCases.count == 7)
    }

    @Test("DebtType rawValues for Codable")
    func debtTypeRawValues() {
        #expect(DebtType.mortgage.rawValue == "mortgage")
        #expect(DebtType.auto.rawValue == "auto")
        #expect(DebtType.creditCard.rawValue == "creditCard")
    }

    @Test("DebtType displayName values")
    func debtTypeDisplayNames() {
        #expect(DebtType.mortgage.displayName == "Mortgage")
        #expect(DebtType.creditCard.displayName == "Credit Card")
        #expect(DebtType.student.displayName == "Student")
    }

    // MARK: GoalType

    @Test("GoalType has 8 cases")
    func goalTypeCaseCount() {
        #expect(GoalType.allCases.count == 8)
    }

    @Test("GoalType rawValues for Codable")
    func goalTypeRawValues() {
        #expect(GoalType.retirement.rawValue == "retirement")
        #expect(GoalType.emergencyFund.rawValue == "emergencyFund")
        #expect(GoalType.homePurchase.rawValue == "homePurchase")
        #expect(GoalType.custom.rawValue == "custom")
    }

    @Test("GoalType displayName values")
    func goalTypeDisplayNames() {
        #expect(GoalType.emergencyFund.displayName == "Emergency Fund")
        #expect(GoalType.homePurchase.displayName == "Home Purchase")
        #expect(GoalType.debtPayoff.displayName == "Debt Payoff")
    }

    // MARK: FilingStatus

    @Test("FilingStatus has 4 cases")
    func filingStatusCaseCount() {
        #expect(FilingStatus.allCases.count == 4)
    }

    @Test("FilingStatus rawValues for Codable")
    func filingStatusRawValues() {
        #expect(FilingStatus.single.rawValue == "single")
        #expect(FilingStatus.marriedJoint.rawValue == "marriedJoint")
        #expect(FilingStatus.marriedSeparate.rawValue == "marriedSeparate")
        #expect(FilingStatus.headOfHousehold.rawValue == "headOfHousehold")
    }

    @Test("FilingStatus displayName values")
    func filingStatusDisplayNames() {
        #expect(FilingStatus.single.displayName == "Single")
        #expect(FilingStatus.marriedJoint.displayName == "Married Filing Jointly")
        #expect(FilingStatus.marriedSeparate.displayName == "Married Filing Separately")
        #expect(FilingStatus.headOfHousehold.displayName == "Head of Household")
    }

    // MARK: RiskTolerance

    @Test("RiskTolerance has 3 cases")
    func riskToleranceCaseCount() {
        #expect(RiskTolerance.allCases.count == 3)
    }

    @Test("RiskTolerance rawValues for Codable")
    func riskToleranceRawValues() {
        #expect(RiskTolerance.conservative.rawValue == "conservative")
        #expect(RiskTolerance.moderate.rawValue == "moderate")
        #expect(RiskTolerance.aggressive.rawValue == "aggressive")
    }

    @Test("RiskTolerance displayName values")
    func riskToleranceDisplayNames() {
        #expect(RiskTolerance.conservative.displayName == "Conservative")
        #expect(RiskTolerance.moderate.displayName == "Moderate")
        #expect(RiskTolerance.aggressive.displayName == "Aggressive")
    }

    // MARK: HoldingType

    @Test("HoldingType has 8 cases")
    func holdingTypeCaseCount() {
        #expect(HoldingType.allCases.count == 8)
    }

    @Test("HoldingType rawValues for Codable")
    func holdingTypeRawValues() {
        #expect(HoldingType.stock.rawValue == "stock")
        #expect(HoldingType.etf.rawValue == "etf")
        #expect(HoldingType.mutualFund.rawValue == "mutualFund")
        #expect(HoldingType.crypto.rawValue == "crypto")
        #expect(HoldingType.reit.rawValue == "reit")
    }

    @Test("HoldingType displayName values")
    func holdingTypeDisplayNames() {
        #expect(HoldingType.etf.displayName == "ETF")
        #expect(HoldingType.mutualFund.displayName == "Mutual Fund")
        #expect(HoldingType.reit.displayName == "REIT")
    }

    // MARK: AssetClass

    @Test("AssetClass has 7 cases")
    func assetClassCaseCount() {
        #expect(AssetClass.allCases.count == 7)
    }

    @Test("AssetClass rawValues for Codable")
    func assetClassRawValues() {
        #expect(AssetClass.usEquity.rawValue == "usEquity")
        #expect(AssetClass.intlEquity.rawValue == "intlEquity")
        #expect(AssetClass.fixedIncome.rawValue == "fixedIncome")
        #expect(AssetClass.realEstate.rawValue == "realEstate")
        #expect(AssetClass.alternative.rawValue == "alternative")
    }

    @Test("AssetClass displayName values")
    func assetClassDisplayNames() {
        #expect(AssetClass.usEquity.displayName == "US Equity")
        #expect(AssetClass.intlEquity.displayName == "International Equity")
        #expect(AssetClass.fixedIncome.displayName == "Fixed Income")
        #expect(AssetClass.realEstate.displayName == "Real Estate")
    }
}

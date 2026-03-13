import Foundation
import Observation

// MARK: - RetirementViewModel

/// ViewModel for the Retirement Planning screens.
/// Aggregates FIRE analysis, contribution limits, RMD projections,
/// and Social Security claiming estimates from RetirementCalculator.
@Observable
final class RetirementViewModel {

    // MARK: - Published State

    var readinessScore: Int = 0
    var yearsToFIRE: Int?
    var fireNumber: Decimal = 0
    var retirementAge: Int = 65
    var contributionLimits: (traditional401k: Decimal, catchUp401k: Decimal, ira: Decimal, catchUpIra: Decimal)?
    var projectedRMD: Decimal = 0
    /// Maps claiming age (62–70) to estimated monthly Social Security benefit.
    var socialSecurityEstimates: [Int: Decimal] = [:]
    var isLoading: Bool = false
    var error: Error?

    // MARK: - Dependencies

    private let accountRepo: any AccountRepository
    private let profileRepo: any UserProfileRepository

    // MARK: - Constants

    private static let defaultAnnualIncome: Decimal = 75_000
    private static let defaultMonthlyExpenses: Decimal = 4_000
    private static let defaultExpectedReturn: Decimal = Decimal(string: "0.07")!
    /// Estimated Social Security FRA benefit as a fraction of annual income.
    private static let estimatedSSFraction: Decimal = Decimal(string: "0.30")!

    // MARK: - Init

    /// Creates a `RetirementViewModel` with the given repository dependencies.
    ///
    /// - Parameters:
    ///   - accountRepo: Repository for account balance data.
    ///   - profileRepo: Repository for user profile data.
    init(accountRepo: any AccountRepository, profileRepo: any UserProfileRepository) {
        self.accountRepo = accountRepo
        self.profileRepo = profileRepo
    }

    // MARK: - Data Loading

    /// Loads all retirement planning data: readiness score, FIRE analysis,
    /// contribution limits, RMD projection, and Social Security estimates.
    func loadRetirementData() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let assets = try await accountRepo.totalAssets()
            let liabilities = try await accountRepo.totalLiabilities()
            let portfolio = max(assets - liabilities, 0)

            let profile = try await profileRepo.fetch()

            let income = profile?.annualIncome ?? Self.defaultAnnualIncome
            let monthlyExp = profile?.monthlyExpenses ?? Self.defaultMonthlyExpenses
            let annualExpenses = monthlyExp * 12
            let age = profile?.age ?? 40
            let plannedRetirementAge = profile?.retirementAge ?? 65
            let yearsUntilRetirement = max(plannedRetirementAge - age, 0)

            let annualContribution = max(income - annualExpenses, 0)

            retirementAge = plannedRetirementAge

            // FIRE number and years to FIRE
            let fire = RetirementCalculator.fireNumber(annualExpenses: annualExpenses)
            fireNumber = fire

            yearsToFIRE = RetirementCalculator.yearsToFIRE(
                currentPortfolio: portfolio,
                annualContribution: annualContribution,
                annualExpenses: annualExpenses,
                expectedReturn: Self.defaultExpectedReturn
            )

            // Readiness score
            readinessScore = RetirementCalculator.readinessScore(
                currentPortfolio: portfolio,
                annualContribution: annualContribution,
                yearsToRetirement: yearsUntilRetirement,
                annualExpensesInRetirement: annualExpenses,
                expectedReturn: Self.defaultExpectedReturn,
                socialSecurityBenefit: nil
            )

            // Contribution limits for current age
            contributionLimits = RetirementCalculator.contributionLimits(
                age: age,
                year: Calendar.current.component(.year, from: Date())
            )

            // Projected RMD — uses current portfolio as a rough estimate
            projectedRMD = RetirementCalculator.requiredMinimumDistribution(
                accountBalance: portfolio,
                age: age
            )

            // Social Security estimates for claiming ages 62–70
            let fraMonthlyBenefit = income * Self.estimatedSSFraction / 12
            var estimates: [Int: Decimal] = [:]
            for claimingAge in 62...70 {
                estimates[claimingAge] = RetirementCalculator.socialSecurityEstimate(
                    fullRetirementBenefit: fraMonthlyBenefit,
                    claimingAge: claimingAge
                )
            }
            socialSecurityEstimates = estimates

        } catch {
            self.error = error
        }

        isLoading = false
    }
}

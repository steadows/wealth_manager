import Foundation
import Observation

// MARK: - InsuranceViewModel

/// ViewModel for the Insurance Dashboard: life insurance gap, emergency fund
/// adequacy, disability coverage gap, and estate planning checklist.
@Observable
final class InsuranceViewModel {

    // MARK: - Published State

    var lifeInsuranceGap: Decimal = 0
    var lifeInsuranceTotalNeed: Decimal = 0
    var emergencyFundMonthsCovered: Decimal = 0
    var emergencyFundShortfall: Decimal = 0
    var disabilityCoverageGap: Decimal = 0
    var estatePlanningChecklist: [(item: String, isComplete: Bool, priority: String)] = []
    var isLoading: Bool = false
    var error: Error?

    // MARK: - Private Estate Planning Flags

    private var estateFlags: EstateFlags = EstateFlags()

    // MARK: - Dependencies

    private let accountRepo: any AccountRepository
    private let profileRepo: any UserProfileRepository

    // MARK: - Init

    /// Creates the view model with injected repositories.
    ///
    /// - Parameters:
    ///   - accountRepo: Repository providing account balances for liquid savings.
    ///   - profileRepo: Repository providing the user profile for income and expenses.
    init(
        accountRepo: any AccountRepository,
        profileRepo: any UserProfileRepository
    ) {
        self.accountRepo = accountRepo
        self.profileRepo = profileRepo
        // Build initial checklist with all-false defaults
        estatePlanningChecklist = InsuranceCalculator.estatePlanningChecklist(
            hasWill: false,
            hasTrust: false,
            hasPOA: false,
            hasHealthcareDirective: false,
            hasBeneficiariesUpdated: false
        )
    }

    // MARK: - Data Loading

    /// Loads insurance data from repositories and recomputes all insurance metrics.
    func loadInsuranceData() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let accounts = try await accountRepo.fetchAll()
            let profile = try await profileRepo.fetch()

            let liquidSavings = accounts
                .filter { $0.accountType == .savings || $0.accountType == .checking }
                .reduce(Decimal.zero) { $0 + $1.currentBalance }

            if let profile {
                computeInsuranceMetrics(profile: profile, liquidSavings: liquidSavings)
            } else {
                resetMetrics()
            }

            rebuildChecklist()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Updates estate planning flags and rebuilds the checklist.
    ///
    /// - Parameters:
    ///   - hasWill: Whether the user has a valid will.
    ///   - hasTrust: Whether the user has an established trust.
    ///   - hasPOA: Whether the user has a power of attorney.
    ///   - hasHealthcareDirective: Whether the user has a healthcare directive.
    ///   - hasBeneficiariesUpdated: Whether beneficiaries are up to date.
    func updateEstatePlanning(
        hasWill: Bool,
        hasTrust: Bool,
        hasPOA: Bool,
        hasHealthcareDirective: Bool,
        hasBeneficiariesUpdated: Bool
    ) {
        estateFlags = EstateFlags(
            hasWill: hasWill,
            hasTrust: hasTrust,
            hasPOA: hasPOA,
            hasHealthcareDirective: hasHealthcareDirective,
            hasBeneficiariesUpdated: hasBeneficiariesUpdated
        )
        rebuildChecklist()
    }

    // MARK: - Private Helpers

    private func computeInsuranceMetrics(profile: UserProfile, liquidSavings: Decimal) {
        // Emergency fund
        let monthlyExpenses = profile.monthlyExpenses ?? 0
        let efResult = InsuranceCalculator.emergencyFundAdequacy(
            liquidSavings: liquidSavings,
            monthlyExpenses: monthlyExpenses
        )
        emergencyFundMonthsCovered = efResult.monthsCovered
        emergencyFundShortfall = efResult.shortfall

        // Life insurance (DIME simplified: income replacement = dependents * 4 years)
        let annualIncome = profile.annualIncome ?? 0
        let yearsToReplace = max(profile.dependents * 4, 0)
        let liResult = InsuranceCalculator.lifeInsuranceNeed(
            totalDebt: 0,
            annualIncome: annualIncome,
            yearsToReplace: yearsToReplace,
            mortgageBalance: 0,
            educationCosts: 0,
            existingCoverage: 0
        )
        lifeInsuranceTotalNeed = liResult.totalNeed
        lifeInsuranceGap = liResult.gap

        // Disability coverage
        let disResult = InsuranceCalculator.disabilityCoverageGap(
            annualIncome: annualIncome,
            existingCoverage: 0
        )
        disabilityCoverageGap = disResult.gap
    }

    private func resetMetrics() {
        lifeInsuranceTotalNeed = 0
        lifeInsuranceGap = 0
        emergencyFundMonthsCovered = 0
        emergencyFundShortfall = 0
        disabilityCoverageGap = 0
    }

    private func rebuildChecklist() {
        estatePlanningChecklist = InsuranceCalculator.estatePlanningChecklist(
            hasWill: estateFlags.hasWill,
            hasTrust: estateFlags.hasTrust,
            hasPOA: estateFlags.hasPOA,
            hasHealthcareDirective: estateFlags.hasHealthcareDirective,
            hasBeneficiariesUpdated: estateFlags.hasBeneficiariesUpdated
        )
    }
}

// MARK: - EstateFlags

/// Value type capturing estate planning boolean flags.
private struct EstateFlags {
    var hasWill: Bool = false
    var hasTrust: Bool = false
    var hasPOA: Bool = false
    var hasHealthcareDirective: Bool = false
    var hasBeneficiariesUpdated: Bool = false
}

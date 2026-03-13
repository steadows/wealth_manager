import Foundation
import Observation

// MARK: - TaxViewModel

/// ViewModel for the Tax Intelligence screens.
///
/// Loads profile and holding data, then delegates all tax calculations
/// to `TaxCalculator` static methods. All monetary values use `Decimal`.
@Observable
final class TaxViewModel {

    // MARK: - Published State

    /// Estimated total federal tax for the current year.
    var estimatedAnnualTax: Decimal = 0

    /// Effective (average) federal tax rate: tax / taxable income.
    var effectiveTaxRate: Decimal = 0

    /// Marginal federal tax rate (bracket rate on the last dollar earned).
    var marginalTaxRate: Decimal = 0

    /// Holdings with unrealized losses suitable for tax-loss harvesting.
    var harvestingOpportunities: [(
        holding: InvestmentHolding,
        unrealizedLoss: Decimal,
        estimatedTaxSavings: Decimal
    )] = []

    /// Asset placement suggestions to reduce tax drag.
    var assetLocationSuggestions: [AssetLocationSuggestion] = []

    /// Roth conversion opportunity for the current year, if any.
    var rothConversionOpportunity: (
        suggestedConversionAmount: Decimal,
        marginalRate: Decimal,
        reason: String
    )? = nil

    /// Applicable standard deduction for the profile's filing status.
    var standardDeduction: Decimal = 0

    /// True while an async data load is in progress.
    var isLoading: Bool = false

    /// Non-nil when a data load fails.
    var error: Error?

    // MARK: - Dependencies

    private let accountRepo: any AccountRepository
    private let profileRepo: any UserProfileRepository
    private let holdingRepo: any InvestmentHoldingRepository

    // MARK: - Init

    /// Initializes the ViewModel with injected repository dependencies.
    ///
    /// - Parameters:
    ///   - accountRepo: Repository for `Account` records.
    ///   - profileRepo: Repository for the user's `UserProfile`.
    ///   - holdingRepo: Repository for `InvestmentHolding` records.
    init(
        accountRepo: any AccountRepository,
        profileRepo: any UserProfileRepository,
        holdingRepo: any InvestmentHoldingRepository
    ) {
        self.accountRepo = accountRepo
        self.profileRepo = profileRepo
        self.holdingRepo = holdingRepo
    }

    // MARK: - Data Loading

    /// Loads all tax-related data and populates published state.
    ///
    /// Fetches the user profile, accounts, and holdings, then computes tax
    /// estimates, harvesting opportunities, asset location suggestions, and
    /// the Roth conversion opportunity using `TaxCalculator`.
    func loadTaxData() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let profile = try await profileRepo.fetch()
            let accounts = try await accountRepo.fetchAll()
            let holdings = try await holdingRepo.fetchAll()

            populateTaxData(profile: profile, accounts: accounts, holdings: holdings)
        } catch {
            self.error = error
        }
    }

    // MARK: - Private Helpers

    /// Computes all tax-derived values from fetched data.
    private func populateTaxData(
        profile: UserProfile?,
        accounts: [Account],
        holdings: [InvestmentHolding]
    ) {
        guard let profile, let income = profile.annualIncome else {
            resetToDefaults()
            return
        }

        let filingStatus = profile.filingStatus
        let currentYear = Calendar.current.component(.year, from: Date())

        // Standard deduction
        let deduction = TaxCalculator.standardDeduction(
            filingStatus: filingStatus,
            year: currentYear
        )
        standardDeduction = deduction

        // Estimated annual tax (using standard deduction)
        estimatedAnnualTax = TaxCalculator.estimatedAnnualTax(
            salary: income,
            capitalGains: 0,
            dividends: 0,
            filingStatus: filingStatus,
            deductions: deduction
        )

        // Marginal & effective rates
        let taxableIncome = max(income - deduction, 0)
        let rates = TaxCalculator.taxRates(
            taxableIncome: taxableIncome,
            filingStatus: filingStatus
        )
        marginalTaxRate = rates.marginal
        effectiveTaxRate = rates.effective

        // Tax-loss harvesting opportunities
        harvestingOpportunities = TaxCalculator.harvestingOpportunities(holdings: holdings)

        // Asset location suggestions
        let taxableIds = Set(
            accounts
                .filter { $0.accountType == .investment || $0.accountType == .checking || $0.accountType == .savings }
                .map(\.id)
        )
        let taxAdvantagedIds = Set(
            accounts
                .filter { $0.accountType == .retirement }
                .map(\.id)
        )
        assetLocationSuggestions = TaxCalculator.assetLocationRecommendation(
            holdings: holdings,
            taxableAccountIds: taxableIds,
            taxAdvantagedAccountIds: taxAdvantagedIds
        )

        // Roth conversion opportunity
        // Use a representative traditional IRA balance (sum of retirement account balances)
        let traditionalIRABalance = accounts
            .filter { $0.accountType == .retirement }
            .reduce(Decimal.zero) { $0 + $1.currentBalance }

        let conversionResult = TaxCalculator.rothConversionOpportunity(
            currentTaxableIncome: taxableIncome,
            filingStatus: filingStatus,
            traditionalIRABalance: traditionalIRABalance
        )
        rothConversionOpportunity = conversionResult
    }

    /// Resets all computed state to zero / empty defaults.
    private func resetToDefaults() {
        estimatedAnnualTax = 0
        effectiveTaxRate = 0
        marginalTaxRate = 0
        standardDeduction = 0
        harvestingOpportunities = []
        assetLocationSuggestions = []
        rothConversionOpportunity = nil
    }
}

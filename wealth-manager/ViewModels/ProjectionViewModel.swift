import Foundation
import Observation

// MARK: - ProjectionViewModel

/// ViewModel for the Projection screen: multi-scenario projections, Monte Carlo, FIRE result.
@Observable
final class ProjectionViewModel {

    // MARK: - Published State

    var currentNetWorth: Decimal = 0
    var scenarios: [ScenarioResult] = []
    var monteCarloResult: MonteCarloResult?
    var fireResult: RetirementCalculator.FIREResult?
    var projectionYears: Int = 30
    var isLoading: Bool = false
    var error: Error?

    // MARK: - Dependencies

    private let projectionService: ProjectionService
    private let accountRepo: any AccountRepository
    private let profileRepo: any UserProfileRepository

    // MARK: - Init

    init(
        projectionService: ProjectionService,
        accountRepo: any AccountRepository,
        profileRepo: any UserProfileRepository
    ) {
        self.projectionService = projectionService
        self.accountRepo = accountRepo
        self.profileRepo = profileRepo
    }

    // MARK: - Data Loading

    /// Loads multi-scenario projections, Monte Carlo simulation, and FIRE analysis.
    func loadProjections() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            // Compute current net worth from accounts
            let assets = try await accountRepo.totalAssets()
            let liabilities = try await accountRepo.totalLiabilities()
            currentNetWorth = assets - liabilities

            // Get profile for assumptions
            let profile = try await profileRepo.fetch() ?? defaultProfile()

            // Multi-scenario projection
            scenarios = await projectionService.netWorthProjection(
                profile: profile,
                currentNetWorth: currentNetWorth,
                years: projectionYears
            )

            // Monte Carlo
            let annualSavings = estimateAnnualSavings(from: profile)
            monteCarloResult = NetWorthProjector.monteCarlo(
                currentNetWorth: currentNetWorth,
                annualSavings: annualSavings,
                years: projectionYears
            )

            // FIRE result
            let annualContribution = annualSavings
            fireResult = await projectionService.retirementReadiness(
                profile: profile,
                portfolio: max(currentNetWorth, 0),
                annualContribution: annualContribution
            )
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Private Helpers

    private func defaultProfile() -> UserProfile {
        UserProfile(
            annualIncome: 75_000,
            monthlyExpenses: nil,
            riskTolerance: .moderate
        )
    }

    private func estimateAnnualSavings(from profile: UserProfile) -> Decimal {
        let income = profile.annualIncome ?? 75_000
        let monthlyExpenses = profile.monthlyExpenses ?? (income / 12 * Decimal(string: "0.70")!)
        let annualExpenses = monthlyExpenses * 12
        return max(income - annualExpenses, 0)
    }
}

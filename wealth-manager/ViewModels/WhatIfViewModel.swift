import Foundation
import Observation

// MARK: - WhatIfViewModel

/// ViewModel for the What-If screen: baseline vs adjusted projection comparison.
@Observable
final class WhatIfViewModel {

    // MARK: - Published State

    var currentNetWorth: Decimal = 0
    var baselinePoints: [ProjectionPoint] = []
    var adjustedPoints: [ProjectionPoint] = []
    var impactAmount: Decimal = 0
    var projectionYears: Int = 20
    var isLoading: Bool = false
    var error: Error?

    // MARK: - Dependencies

    private let accountRepo: any AccountRepository
    private let profileRepo: any UserProfileRepository

    // MARK: - Derived

    private var annualSavings: Decimal = 0
    private var annualReturn: Decimal = Decimal(string: "0.07")!

    // MARK: - Init

    init(
        accountRepo: any AccountRepository,
        profileRepo: any UserProfileRepository
    ) {
        self.accountRepo = accountRepo
        self.profileRepo = profileRepo
    }

    // MARK: - Baseline

    /// Loads baseline projection from current accounts and profile.
    func loadBaseline() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            let assets = try await accountRepo.totalAssets()
            let liabilities = try await accountRepo.totalLiabilities()
            currentNetWorth = assets - liabilities

            let profile = try await profileRepo.fetch()
            annualSavings = estimateAnnualSavings(from: profile)
            annualReturn = returnForRiskTolerance(profile?.riskTolerance ?? .moderate)

            baselinePoints = NetWorthProjector.linearProjection(
                currentNetWorth: currentNetWorth,
                annualSavings: annualSavings,
                annualReturn: annualReturn,
                years: projectionYears
            )

            // Clear any previous adjustment
            adjustedPoints = []
            impactAmount = 0
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - What-If

    /// Applies a what-if adjustment and computes the adjusted projection.
    func applyAdjustment(_ adjustment: WhatIfAdjustment) async {
        adjustedPoints = NetWorthProjector.whatIf(
            currentNetWorth: currentNetWorth,
            annualSavings: annualSavings,
            annualReturn: annualReturn,
            years: projectionYears,
            adjustment: adjustment
        )

        // Compute impact as difference in final net worth
        let baselineFinal = baselinePoints.last?.netWorth ?? 0
        let adjustedFinal = adjustedPoints.last?.netWorth ?? 0
        impactAmount = adjustedFinal - baselineFinal
    }

    /// Clears the current what-if adjustment.
    func clearAdjustment() {
        adjustedPoints = []
        impactAmount = 0
    }

    // MARK: - Private Helpers

    private func estimateAnnualSavings(from profile: UserProfile?) -> Decimal {
        let income = profile?.annualIncome ?? 75_000
        let monthlyExpenses = profile?.monthlyExpenses ?? (income / 12 * Decimal(string: "0.70")!)
        let annualExpenses = monthlyExpenses * 12
        return max(income - annualExpenses, 0)
    }

    private func returnForRiskTolerance(_ tolerance: RiskTolerance) -> Decimal {
        switch tolerance {
        case .conservative: return Decimal(string: "0.04")!
        case .moderate: return Decimal(string: "0.07")!
        case .aggressive: return Decimal(string: "0.10")!
        }
    }
}

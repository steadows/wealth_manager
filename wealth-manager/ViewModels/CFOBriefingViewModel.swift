import Foundation
import Observation

/// ViewModel for the CFO Briefing report view.
@Observable
final class CFOBriefingViewModel {

    // MARK: - State

    var briefing: CFOBriefingDTO?
    var healthScore: HealthScoreResponseDTO?
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let advisoryService: AdvisoryServiceProtocol

    // MARK: - Init

    init(advisoryService: AdvisoryServiceProtocol) {
        self.advisoryService = advisoryService
    }

    // MARK: - Actions

    /// Loads the CFO briefing for the given period.
    /// - Parameter period: "weekly" or "monthly"
    func loadBriefing(period: String) async {
        isLoading = true
        errorMessage = nil

        do {
            briefing = try await advisoryService.fetchBriefing(period: period)
        } catch {
            errorMessage = error.localizedDescription
            briefing = nil
        }

        isLoading = false
    }

    /// Loads the financial health score breakdown.
    func loadHealthScore() async {
        isLoading = true
        errorMessage = nil

        do {
            healthScore = try await advisoryService.fetchHealthScore()
        } catch {
            errorMessage = error.localizedDescription
            healthScore = nil
        }

        isLoading = false
    }
}

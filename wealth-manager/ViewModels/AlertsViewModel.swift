import Foundation
import Observation

/// ViewModel for the proactive alerts list.
@Observable
final class AlertsViewModel {

    // MARK: - State

    var alerts: [ProactiveAlertDTO] = []
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - Dependencies

    private let advisoryService: AdvisoryServiceProtocol

    // MARK: - Init

    init(advisoryService: AdvisoryServiceProtocol) {
        self.advisoryService = advisoryService
    }

    // MARK: - Actions

    /// Loads and sorts alerts from the backend.
    func loadAlerts() async {
        isLoading = true
        errorMessage = nil

        do {
            let raw = try await advisoryService.fetchAlerts()
            alerts = raw.sorted { $0.severity.sortOrder < $1.severity.sortOrder }
        } catch {
            errorMessage = error.localizedDescription
            alerts = []
        }

        isLoading = false
    }
}

import Testing
import Foundation

@testable import wealth_manager

// MARK: - Mock Advisory Service

/// In-test mock conforming to AdvisoryServiceProtocol.
final class MockAdvisoryService: AdvisoryServiceProtocol, @unchecked Sendable {
    var stubbedAlerts: [ProactiveAlertDTO] = []
    var stubbedBriefing: CFOBriefingDTO?
    var stubbedHealthScore: HealthScoreResponseDTO?
    var stubbedChatChunks: [String] = []
    var stubbedAnnualReview: AnnualReviewDTO?
    var shouldThrow: Error?

    // Captured call arguments for verification
    var capturedAnnualReviewYear: Int?

    func streamChat(message: String, conversationId: UUID?) -> AsyncThrowingStream<String, Error> {
        let chunks = stubbedChatChunks
        let error = shouldThrow
        return AsyncThrowingStream { continuation in
            if let error {
                continuation.finish(throwing: error)
                return
            }
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }

    func fetchBriefing(period: String) async throws -> CFOBriefingDTO {
        if let error = shouldThrow { throw error }
        return stubbedBriefing!
    }

    func fetchHealthScore() async throws -> HealthScoreResponseDTO {
        if let error = shouldThrow { throw error }
        return stubbedHealthScore!
    }

    func fetchAlerts() async throws -> [ProactiveAlertDTO] {
        if let error = shouldThrow { throw error }
        return stubbedAlerts
    }

    func fetchAnnualReview(year: Int) async throws -> AnnualReviewDTO {
        capturedAnnualReviewYear = year
        if let error = shouldThrow { throw error }
        return stubbedAnnualReview!
    }
}

// MARK: - Test Fixtures

extension ProactiveAlertDTO {
    static func make(
        id: UUID = UUID(),
        severity: AlertSeverity = .info,
        title: String = "Test Alert",
        message: String = "Test message",
        ruleName: String = "test_rule",
        createdAt: Date = Date()
    ) -> ProactiveAlertDTO {
        ProactiveAlertDTO(id: id, severity: severity, title: title,
                          message: message, ruleName: ruleName, createdAt: createdAt)
    }
}

// MARK: - AlertsViewModelTests

@Suite("AlertsViewModel")
struct AlertsViewModelTests {

    private func makeVM(service: MockAdvisoryService = MockAdvisoryService()) -> AlertsViewModel {
        AlertsViewModel(advisoryService: service)
    }

    // MARK: - Load Alerts

    @Test("loadAlerts: populates alerts on success")
    func loadAlertsPopulatesAlerts() async {
        let service = MockAdvisoryService()
        service.stubbedAlerts = [
            .make(severity: .warning, title: "Low Emergency Fund"),
            .make(severity: .info, title: "Portfolio Rebalance"),
        ]
        let vm = makeVM(service: service)

        await vm.loadAlerts()

        #expect(vm.alerts.count == 2)
        #expect(vm.errorMessage == nil)
    }

    @Test("loadAlerts: sorts by severity — action first, info last")
    func loadAlertsSortsBySeverity() async {
        let service = MockAdvisoryService()
        service.stubbedAlerts = [
            .make(severity: .info, title: "Info"),
            .make(severity: .action, title: "Urgent"),
            .make(severity: .warning, title: "Warning"),
        ]
        let vm = makeVM(service: service)

        await vm.loadAlerts()

        #expect(vm.alerts[0].severity == .action)
        #expect(vm.alerts[1].severity == .warning)
        #expect(vm.alerts[2].severity == .info)
    }

    @Test("loadAlerts: sets errorMessage on failure")
    func loadAlertsSetsErrorOnFailure() async {
        let service = MockAdvisoryService()
        service.shouldThrow = APIError.noData
        let vm = makeVM(service: service)

        await vm.loadAlerts()

        #expect(vm.errorMessage != nil)
        #expect(vm.alerts.isEmpty)
    }

    @Test("loadAlerts: isLoading is false after completion")
    func loadAlertsIsLoadingFalseAfter() async {
        let service = MockAdvisoryService()
        service.stubbedAlerts = []
        let vm = makeVM(service: service)

        await vm.loadAlerts()

        #expect(!vm.isLoading)
    }

    @Test("loadAlerts: empty list succeeds with no alerts")
    func loadAlertsHandlesEmpty() async {
        let service = MockAdvisoryService()
        service.stubbedAlerts = []
        let vm = makeVM(service: service)

        await vm.loadAlerts()

        #expect(vm.alerts.isEmpty)
        #expect(vm.errorMessage == nil)
    }
}

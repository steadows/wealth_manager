import Testing
import Foundation

@testable import wealth_manager

// MARK: - CFOBriefingViewModelTests

@Suite("CFOBriefingViewModel")
struct CFOBriefingViewModelTests {

    // MARK: - Fixtures

    private func makeBriefing(
        period: String = "weekly",
        healthScore: Int = 72,
        summary: String = "Your finances look solid.",
        insights: [BriefingInsightDTO] = [],
        actionItems: [String] = [],
        netWorthChange: Decimal = 1500
    ) -> CFOBriefingDTO {
        CFOBriefingDTO(
            period: period,
            generatedAt: Date(),
            healthScore: healthScore,
            summary: summary,
            insights: insights,
            actionItems: actionItems,
            goalProgress: [],
            netWorthChange: netWorthChange
        )
    }

    private func makeHealthScore(overall: Int = 80) -> HealthScoreResponseDTO {
        HealthScoreResponseDTO(
            overallScore: overall,
            savingsScore: 75,
            debtScore: 85,
            investmentScore: 78,
            emergencyFundScore: 60,
            narrative: "You have a healthy financial picture overall."
        )
    }

    private func makeVM(service: MockAdvisoryService = MockAdvisoryService()) -> CFOBriefingViewModel {
        CFOBriefingViewModel(advisoryService: service)
    }

    // MARK: - loadBriefing

    @Test("loadBriefing: populates briefing on success")
    func loadBriefingPopulatesBriefing() async {
        let service = MockAdvisoryService()
        service.stubbedBriefing = makeBriefing(healthScore: 72)
        let vm = makeVM(service: service)

        await vm.loadBriefing(period: "weekly")

        #expect(vm.briefing != nil)
        #expect(vm.briefing?.healthScore == 72)
        #expect(vm.briefing?.period == "weekly")
        #expect(vm.errorMessage == nil)
    }

    @Test("loadBriefing: sets errorMessage on failure")
    func loadBriefingSetsError() async {
        let service = MockAdvisoryService()
        service.shouldThrow = APIError.noData
        let vm = makeVM(service: service)

        await vm.loadBriefing(period: "weekly")

        #expect(vm.briefing == nil)
        #expect(vm.errorMessage != nil)
    }

    @Test("loadBriefing: isLoading false after completion")
    func loadBriefingIsLoadingFalseAfter() async {
        let service = MockAdvisoryService()
        service.stubbedBriefing = makeBriefing()
        let vm = makeVM(service: service)

        await vm.loadBriefing(period: "weekly")

        #expect(!vm.isLoading)
    }

    @Test("loadBriefing: captures insights list")
    func loadBriefingCapturesInsights() async {
        let insights = [
            BriefingInsightDTO(title: "Savings up", detail: "+$500 this week", impact: "positive"),
            BriefingInsightDTO(title: "Overspent dining", detail: "20% over budget", impact: "negative"),
        ]
        let service = MockAdvisoryService()
        service.stubbedBriefing = makeBriefing(insights: insights)
        let vm = makeVM(service: service)

        await vm.loadBriefing(period: "weekly")

        #expect(vm.briefing?.insights.count == 2)
        #expect(vm.briefing?.insights[0].impact == "positive")
    }

    // MARK: - loadHealthScore

    @Test("loadHealthScore: populates healthScore on success")
    func loadHealthScorePopulates() async {
        let service = MockAdvisoryService()
        service.stubbedHealthScore = makeHealthScore(overall: 80)
        let vm = makeVM(service: service)

        await vm.loadHealthScore()

        #expect(vm.healthScore != nil)
        #expect(vm.healthScore?.overallScore == 80)
        #expect(vm.healthScore?.savingsScore == 75)
        #expect(vm.errorMessage == nil)
    }

    @Test("loadHealthScore: sets errorMessage on failure")
    func loadHealthScoreSetsError() async {
        let service = MockAdvisoryService()
        service.shouldThrow = APIError.noData
        let vm = makeVM(service: service)

        await vm.loadHealthScore()

        #expect(vm.healthScore == nil)
        #expect(vm.errorMessage != nil)
    }
}

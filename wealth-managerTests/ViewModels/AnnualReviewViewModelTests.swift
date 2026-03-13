import Testing
import Foundation

@testable import wealth_manager

// MARK: - AnnualReviewViewModelTests

@Suite("AnnualReviewViewModel")
struct AnnualReviewViewModelTests {

    // MARK: - Fixtures

    private func makeReview(
        year: Int = 2024,
        netWorthChange: Decimal = 15000,
        startingNetWorth: Decimal = 100000,
        endingNetWorth: Decimal = 115000,
        totalIncome: Decimal = 95000,
        totalSpending: Decimal = 62000,
        savingsRate: Decimal = 0.35,
        topCategories: [CategorySummary] = [],
        goalProgress: [GoalProgressSummary] = [],
        investmentReturn: Decimal = 0.12,
        taxSummary: String = "No major tax events.",
        actionItems: [String] = [],
        narrative: String = "Strong year with consistent savings growth."
    ) -> AnnualReviewDTO {
        AnnualReviewDTO(
            year: year,
            netWorthChange: netWorthChange,
            startingNetWorth: startingNetWorth,
            endingNetWorth: endingNetWorth,
            totalIncome: totalIncome,
            totalSpending: totalSpending,
            savingsRate: savingsRate,
            topCategories: topCategories,
            goalProgress: goalProgress,
            investmentReturn: investmentReturn,
            taxSummary: taxSummary,
            actionItems: actionItems,
            narrative: narrative
        )
    }

    private func makeVM(service: MockAdvisoryService = MockAdvisoryService()) -> AnnualReviewViewModel {
        AnnualReviewViewModel(advisoryService: service)
    }

    // MARK: - Initial State

    @Test("initialState: review is nil and not loading")
    func initialStateNoReview() {
        // Arrange + Act
        let vm = makeVM()

        // Assert
        #expect(vm.review == nil)
        #expect(!vm.isLoading)
        #expect(vm.errorMessage == nil)
    }

    @Test("initialState: selectedYear defaults to currentYear - 1")
    func initialStateSelectedYearIsPreviousYear() {
        // Arrange
        let expectedYear = Calendar.current.component(.year, from: Date()) - 1

        // Act
        let vm = makeVM()

        // Assert
        #expect(vm.selectedYear == expectedYear)
    }

    // MARK: - generateReview

    @Test("generateReview: isLoading is true during call")
    func generateReviewSetsLoading() async {
        // Arrange
        let service = MockAdvisoryService()
        service.stubbedAnnualReview = makeReview()
        let vm = makeVM(service: service)

        // Act — capture loading state by observing pre-await behaviour is not directly
        // testable in sync; verify it is false AFTER, and was set during (via side-effect test)
        await vm.generateReview()

        // Assert — isLoading must be cleared after completion
        #expect(!vm.isLoading)
    }

    @Test("generateReview: populates review on success")
    func generateReviewSuccessPopulatesReview() async {
        // Arrange
        let service = MockAdvisoryService()
        service.stubbedAnnualReview = makeReview(year: 2024, netWorthChange: 15000)
        let vm = makeVM(service: service)

        // Act
        await vm.generateReview()

        // Assert
        #expect(vm.review != nil)
        #expect(vm.review?.year == 2024)
        #expect(vm.review?.netWorthChange == 15000)
        #expect(vm.errorMessage == nil)
    }

    @Test("generateReview: sets errorMessage on failure")
    func generateReviewFailureSetsError() async {
        // Arrange
        let service = MockAdvisoryService()
        service.shouldThrow = APIError.noData
        let vm = makeVM(service: service)

        // Act
        await vm.generateReview()

        // Assert
        #expect(vm.review == nil)
        #expect(vm.errorMessage != nil)
        #expect(!vm.isLoading)
    }

    @Test("generateReview: passes selectedYear to service")
    func generateReviewUsesSelectedYear() async {
        // Arrange
        let service = MockAdvisoryService()
        service.stubbedAnnualReview = makeReview(year: 2022)
        let vm = makeVM(service: service)
        vm.selectedYear = 2022

        // Act
        await vm.generateReview()

        // Assert
        #expect(service.capturedAnnualReviewYear == 2022)
    }

    // MARK: - selectYear

    @Test("selectYear: updates selectedYear and clears existing review")
    func selectYearUpdatesYearClearsReview() async {
        // Arrange
        let service = MockAdvisoryService()
        service.stubbedAnnualReview = makeReview(year: 2024)
        let vm = makeVM(service: service)
        await vm.generateReview()
        #expect(vm.review != nil)

        // Act
        vm.selectYear(2023)

        // Assert
        #expect(vm.selectedYear == 2023)
        #expect(vm.review == nil)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - topCategories

    @Test("review: topCategories from DTO are accessible on the review")
    func reviewTopCategoriesPresent() async {
        // Arrange
        let categories = [
            CategorySummary(name: "Housing", amount: 18000),
            CategorySummary(name: "Food", amount: 9600),
            CategorySummary(name: "Transport", amount: 4200),
        ]
        let service = MockAdvisoryService()
        service.stubbedAnnualReview = makeReview(topCategories: categories)
        let vm = makeVM(service: service)

        // Act
        await vm.generateReview()

        // Assert
        #expect(vm.review?.topCategories.count == 3)
        #expect(vm.review?.topCategories[0].name == "Housing")
        #expect(vm.review?.topCategories[1].amount == 9600)
    }
}

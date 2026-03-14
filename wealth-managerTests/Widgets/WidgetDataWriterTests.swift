import Testing
import Foundation

@testable import wealth_manager

// MARK: - WidgetDataWriter Tests

@Suite("WidgetDataWriter")
struct WidgetDataWriterTests {

    // MARK: - Net Worth

    @Test("updateNetWorth computes positive change correctly")
    func updateNetWorthPositiveChange() throws {
        let mockStore = MockWidgetDataStore()
        let writer = WidgetDataWriter(store: mockStore)

        // Arrange
        let current: Decimal = 250000
        let previous: Decimal = 245000

        // Act
        try writer.updateNetWorth(currentNetWorth: current, previousNetWorth: previous)

        // Assert
        let saved = try #require(mockStore.savedNetWorthData)
        #expect(saved.netWorthDecimal == 250000)
        #expect(saved.dailyChangeDecimal == 5000)
        #expect(saved.isPositive == true)
    }

    @Test("updateNetWorth computes negative change correctly")
    func updateNetWorthNegativeChange() throws {
        let mockStore = MockWidgetDataStore()
        let writer = WidgetDataWriter(store: mockStore)

        // Arrange
        let current: Decimal = 245000
        let previous: Decimal = 250000

        // Act
        try writer.updateNetWorth(currentNetWorth: current, previousNetWorth: previous)

        // Assert
        let saved = try #require(mockStore.savedNetWorthData)
        #expect(saved.dailyChangeDecimal == -5000)
        #expect(saved.isPositive == false)
    }

    @Test("updateNetWorth computes change percent correctly")
    func updateNetWorthChangePercent() throws {
        let mockStore = MockWidgetDataStore()
        let writer = WidgetDataWriter(store: mockStore)

        // Arrange — $200 on $10,000 = 2%
        let current: Decimal = 10200
        let previous: Decimal = 10000

        // Act
        try writer.updateNetWorth(currentNetWorth: current, previousNetWorth: previous)

        // Assert
        let saved = try #require(mockStore.savedNetWorthData)
        #expect(saved.dailyChangePercentDecimal == Decimal(string: "0.02")!)
    }

    @Test("updateNetWorth handles zero previous net worth")
    func updateNetWorthZeroPrevious() throws {
        let mockStore = MockWidgetDataStore()
        let writer = WidgetDataWriter(store: mockStore)

        // Act
        try writer.updateNetWorth(currentNetWorth: 50000, previousNetWorth: 0)

        // Assert — change percent should be zero (avoid division by zero)
        let saved = try #require(mockStore.savedNetWorthData)
        #expect(saved.dailyChangePercentDecimal == Decimal.zero)
        #expect(saved.dailyChangeDecimal == 50000)
        #expect(saved.isPositive == true)
    }

    @Test("updateNetWorth handles zero change")
    func updateNetWorthNoChange() throws {
        let mockStore = MockWidgetDataStore()
        let writer = WidgetDataWriter(store: mockStore)

        // Act
        try writer.updateNetWorth(currentNetWorth: 100000, previousNetWorth: 100000)

        // Assert
        let saved = try #require(mockStore.savedNetWorthData)
        #expect(saved.dailyChangeDecimal == Decimal.zero)
        #expect(saved.dailyChangePercentDecimal == Decimal.zero)
        #expect(saved.isPositive == true)
    }

    // MARK: - Health Score

    @Test("updateHealthScore stores score and derives tier label")
    func updateHealthScoreStoresAndDerives() throws {
        let mockStore = MockWidgetDataStore()
        let writer = WidgetDataWriter(store: mockStore)

        // Act
        try writer.updateHealthScore(overallScore: 85)

        // Assert
        let saved = try #require(mockStore.savedHealthScoreData)
        #expect(saved.overallScore == 85)
        #expect(saved.scoreLabel == "Great")
    }

    @Test("updateHealthScore stores Excellent tier for 95")
    func updateHealthScoreExcellent() throws {
        let mockStore = MockWidgetDataStore()
        let writer = WidgetDataWriter(store: mockStore)

        try writer.updateHealthScore(overallScore: 95)

        let saved = try #require(mockStore.savedHealthScoreData)
        #expect(saved.scoreLabel == "Excellent")
    }

    @Test("updateHealthScore stores Needs Work tier for 30")
    func updateHealthScoreNeedsWork() throws {
        let mockStore = MockWidgetDataStore()
        let writer = WidgetDataWriter(store: mockStore)

        try writer.updateHealthScore(overallScore: 30)

        let saved = try #require(mockStore.savedHealthScoreData)
        #expect(saved.scoreLabel == "Needs Work")
    }

    // MARK: - Milestone

    @Test("updateMilestone stores goal data and computes progress")
    func updateMilestoneStoresAndComputesProgress() throws {
        let mockStore = MockWidgetDataStore()
        let writer = WidgetDataWriter(store: mockStore)

        // Arrange
        let targetDate = Date(timeIntervalSince1970: 1_800_000_000)

        // Act
        try writer.updateMilestone(
            goalName: "Emergency Fund",
            goalTypeRawValue: "emergencyFund",
            targetAmount: 20000,
            currentAmount: 5000,
            targetDate: targetDate
        )

        // Assert
        let saved = try #require(mockStore.savedMilestoneData)
        #expect(saved.goalName == "Emergency Fund")
        #expect(saved.goalTypeRawValue == "emergencyFund")
        #expect(saved.targetAmountDecimal == 20000)
        #expect(saved.currentAmountDecimal == 5000)
        #expect(saved.progressDouble == 0.25)
        #expect(saved.targetDate == targetDate)
    }

    @Test("updateMilestone handles zero target amount")
    func updateMilestoneZeroTarget() throws {
        let mockStore = MockWidgetDataStore()
        let writer = WidgetDataWriter(store: mockStore)

        // Act
        try writer.updateMilestone(
            goalName: "Empty Goal",
            goalTypeRawValue: "custom",
            targetAmount: 0,
            currentAmount: 100,
            targetDate: nil
        )

        // Assert — progress should be zero (avoid division by zero)
        let saved = try #require(mockStore.savedMilestoneData)
        #expect(saved.progressDouble == 0.0)
    }

    @Test("updateMilestone with nil target date")
    func updateMilestoneNilTargetDate() throws {
        let mockStore = MockWidgetDataStore()
        let writer = WidgetDataWriter(store: mockStore)

        try writer.updateMilestone(
            goalName: "Savings",
            goalTypeRawValue: "custom",
            targetAmount: 10000,
            currentAmount: 3000,
            targetDate: nil
        )

        let saved = try #require(mockStore.savedMilestoneData)
        #expect(saved.targetDate == nil)
    }
}

import Foundation
import WidgetKit

// MARK: - Protocol

/// Converts app domain models into widget DTOs and persists them.
protocol WidgetDataWriterProtocol: Sendable {
    /// Updates the net worth widget data from snapshot values.
    func updateNetWorth(
        currentNetWorth: Decimal,
        previousNetWorth: Decimal
    ) throws

    /// Updates the health score widget data.
    func updateHealthScore(overallScore: Int) throws

    /// Updates the milestone widget data from the closest active goal.
    func updateMilestone(
        goalName: String,
        goalTypeRawValue: String,
        targetAmount: Decimal,
        currentAmount: Decimal,
        targetDate: Date?
    ) throws

    /// Triggers WidgetKit to reload all widget timelines.
    func reloadAllTimelines()
}

// MARK: - Implementation

/// Writes widget-ready data to the shared App Group store and reloads timelines.
final class WidgetDataWriter: WidgetDataWriterProtocol, @unchecked Sendable {
    private let store: WidgetDataStoreProtocol

    /// Creates a writer backed by the given data store.
    /// - Parameter store: The shared data store. Defaults to `AppGroupWidgetDataStore()`.
    init(store: WidgetDataStoreProtocol = AppGroupWidgetDataStore()) {
        self.store = store
    }

    func updateNetWorth(
        currentNetWorth: Decimal,
        previousNetWorth: Decimal
    ) throws {
        let change = currentNetWorth - previousNetWorth
        let changePercent: Decimal = previousNetWorth != 0
            ? change / previousNetWorth
            : Decimal.zero

        let data = NetWorthWidgetData(
            netWorth: "\(currentNetWorth)",
            dailyChange: "\(change)",
            dailyChangePercent: "\(changePercent)",
            isPositive: change >= 0,
            lastUpdated: Date()
        )
        try store.saveNetWorthData(data)
    }

    func updateHealthScore(overallScore: Int) throws {
        let label = HealthScoreWidgetData.tierLabel(for: overallScore)
        let data = HealthScoreWidgetData(
            overallScore: overallScore,
            scoreLabel: label,
            lastUpdated: Date()
        )
        try store.saveHealthScoreData(data)
    }

    func updateMilestone(
        goalName: String,
        goalTypeRawValue: String,
        targetAmount: Decimal,
        currentAmount: Decimal,
        targetDate: Date?
    ) throws {
        let progress: Decimal = targetAmount != 0
            ? currentAmount / targetAmount
            : Decimal.zero

        let data = MilestoneWidgetData(
            goalName: goalName,
            goalTypeRawValue: goalTypeRawValue,
            targetAmount: "\(targetAmount)",
            currentAmount: "\(currentAmount)",
            progressPercent: "\(progress)",
            targetDate: targetDate,
            lastUpdated: Date()
        )
        try store.saveMilestoneData(data)
    }

    func reloadAllTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

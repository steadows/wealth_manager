import Testing
import Foundation

@testable import wealth_manager

// MARK: - Mock Store

/// In-memory mock implementation of WidgetDataStoreProtocol for testing.
final class MockWidgetDataStore: WidgetDataStoreProtocol, @unchecked Sendable {
    var savedNetWorthData: NetWorthWidgetData?
    var savedHealthScoreData: HealthScoreWidgetData?
    var savedMilestoneData: MilestoneWidgetData?
    var shouldThrow = false

    func saveNetWorthData(_ data: NetWorthWidgetData) throws {
        if shouldThrow { throw MockStoreError.saveFailed }
        savedNetWorthData = data
    }

    func loadNetWorthData() -> NetWorthWidgetData? {
        savedNetWorthData
    }

    func saveHealthScoreData(_ data: HealthScoreWidgetData) throws {
        if shouldThrow { throw MockStoreError.saveFailed }
        savedHealthScoreData = data
    }

    func loadHealthScoreData() -> HealthScoreWidgetData? {
        savedHealthScoreData
    }

    func saveMilestoneData(_ data: MilestoneWidgetData) throws {
        if shouldThrow { throw MockStoreError.saveFailed }
        savedMilestoneData = data
    }

    func loadMilestoneData() -> MilestoneWidgetData? {
        savedMilestoneData
    }

    enum MockStoreError: Error {
        case saveFailed
    }
}

// MARK: - AppGroupWidgetDataStore Tests

@Suite("AppGroupWidgetDataStore")
struct AppGroupWidgetDataStoreTests {

    /// Creates a fresh UserDefaults with a unique suite name for test isolation.
    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "test.widgets.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    @Test("save and load net worth data round-trips correctly")
    func netWorthRoundTrip() throws {
        let defaults = makeIsolatedDefaults()
        let store = AppGroupWidgetDataStore(defaults: defaults)

        let data = NetWorthWidgetData(
            netWorth: "350000",
            dailyChange: "2500",
            dailyChangePercent: "0.0072",
            isPositive: true,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try store.saveNetWorthData(data)
        let loaded = store.loadNetWorthData()

        #expect(loaded == data)
    }

    @Test("load net worth returns nil when no data saved")
    func netWorthReturnsNilWhenEmpty() {
        let defaults = makeIsolatedDefaults()
        let store = AppGroupWidgetDataStore(defaults: defaults)

        #expect(store.loadNetWorthData() == nil)
    }

    @Test("save and load health score data round-trips correctly")
    func healthScoreRoundTrip() throws {
        let defaults = makeIsolatedDefaults()
        let store = AppGroupWidgetDataStore(defaults: defaults)

        let data = HealthScoreWidgetData(
            overallScore: 82,
            scoreLabel: "Great",
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try store.saveHealthScoreData(data)
        let loaded = store.loadHealthScoreData()

        #expect(loaded == data)
    }

    @Test("load health score returns nil when no data saved")
    func healthScoreReturnsNilWhenEmpty() {
        let defaults = makeIsolatedDefaults()
        let store = AppGroupWidgetDataStore(defaults: defaults)

        #expect(store.loadHealthScoreData() == nil)
    }

    @Test("save and load milestone data round-trips correctly")
    func milestoneRoundTrip() throws {
        let defaults = makeIsolatedDefaults()
        let store = AppGroupWidgetDataStore(defaults: defaults)

        let data = MilestoneWidgetData(
            goalName: "House Down Payment",
            goalTypeRawValue: "homePurchase",
            targetAmount: "80000",
            currentAmount: "32000",
            progressPercent: "0.4",
            targetDate: Date(timeIntervalSince1970: 1_800_000_000),
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try store.saveMilestoneData(data)
        let loaded = store.loadMilestoneData()

        #expect(loaded == data)
    }

    @Test("load milestone returns nil when no data saved")
    func milestoneReturnsNilWhenEmpty() {
        let defaults = makeIsolatedDefaults()
        let store = AppGroupWidgetDataStore(defaults: defaults)

        #expect(store.loadMilestoneData() == nil)
    }

    @Test("saving overwrites previous data")
    func saveOverwritesPreviousData() throws {
        let defaults = makeIsolatedDefaults()
        let store = AppGroupWidgetDataStore(defaults: defaults)

        let first = HealthScoreWidgetData(
            overallScore: 60,
            scoreLabel: "Good",
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try store.saveHealthScoreData(first)

        let second = HealthScoreWidgetData(
            overallScore: 90,
            scoreLabel: "Excellent",
            lastUpdated: Date(timeIntervalSince1970: 1_700_001_000)
        )
        try store.saveHealthScoreData(second)

        let loaded = store.loadHealthScoreData()
        #expect(loaded == second)
    }
}

import Foundation
import WidgetKit

// MARK: - Protocol

/// Protocol for reading and writing widget data to a shared store.
/// The main app writes data; the widget extension reads it.
protocol WidgetDataStoreProtocol: Sendable {
    /// Saves net worth data for the widget.
    func saveNetWorthData(_ data: NetWorthWidgetData) throws
    /// Loads the most recent net worth data, or nil if none exists.
    func loadNetWorthData() -> NetWorthWidgetData?

    /// Saves health score data for the widget.
    func saveHealthScoreData(_ data: HealthScoreWidgetData) throws
    /// Loads the most recent health score data, or nil if none exists.
    func loadHealthScoreData() -> HealthScoreWidgetData?

    /// Saves milestone data for the widget.
    func saveMilestoneData(_ data: MilestoneWidgetData) throws
    /// Loads the most recent milestone data, or nil if none exists.
    func loadMilestoneData() -> MilestoneWidgetData?
}

// MARK: - UserDefaults Implementation

/// Shared UserDefaults-based store for widget data exchange via App Group.
///
/// Creates fresh `JSONEncoder`/`JSONDecoder` instances per method call to ensure
/// thread safety, since `JSONEncoder` and `JSONDecoder` are not thread-safe.
final class AppGroupWidgetDataStore: WidgetDataStoreProtocol, @unchecked Sendable {
    private let defaults: UserDefaults

    /// Creates a store backed by the given UserDefaults instance.
    /// - Parameter defaults: The UserDefaults to use. Pass nil to use the App Group suite.
    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: WidgetConstants.appGroupID)
            ?? .standard
    }

    // MARK: - Private Helpers

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - WidgetDataStoreProtocol

    func saveNetWorthData(_ data: NetWorthWidgetData) throws {
        let encoded = try makeEncoder().encode(data)
        defaults.set(encoded, forKey: WidgetConstants.netWorthKey)
    }

    func loadNetWorthData() -> NetWorthWidgetData? {
        guard let data = defaults.data(forKey: WidgetConstants.netWorthKey) else { return nil }
        return try? makeDecoder().decode(NetWorthWidgetData.self, from: data)
    }

    func saveHealthScoreData(_ data: HealthScoreWidgetData) throws {
        let encoded = try makeEncoder().encode(data)
        defaults.set(encoded, forKey: WidgetConstants.healthScoreKey)
    }

    func loadHealthScoreData() -> HealthScoreWidgetData? {
        guard let data = defaults.data(forKey: WidgetConstants.healthScoreKey) else { return nil }
        return try? makeDecoder().decode(HealthScoreWidgetData.self, from: data)
    }

    func saveMilestoneData(_ data: MilestoneWidgetData) throws {
        let encoded = try makeEncoder().encode(data)
        defaults.set(encoded, forKey: WidgetConstants.milestoneKey)
    }

    func loadMilestoneData() -> MilestoneWidgetData? {
        guard let data = defaults.data(forKey: WidgetConstants.milestoneKey) else { return nil }
        return try? makeDecoder().decode(MilestoneWidgetData.self, from: data)
    }
}

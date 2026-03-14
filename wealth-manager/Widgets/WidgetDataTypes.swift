import Foundation
import WidgetKit

// MARK: - App Group Constants

/// Shared constants for widget data exchange between the main app and widget extension.
enum WidgetConstants {
    /// App Group identifier shared between main app and widget extension.
    static let appGroupID = "group.com.wealthmanager.shared"

    /// UserDefaults key for net worth widget data.
    static let netWorthKey = "widget.netWorth"

    /// UserDefaults key for health score widget data.
    static let healthScoreKey = "widget.healthScore"

    /// UserDefaults key for next milestone widget data.
    static let milestoneKey = "widget.milestone"
}

// MARK: - Widget Data Transfer Objects

/// Data transfer object for net worth widget display.
struct NetWorthWidgetData: Codable, Equatable, Sendable {
    /// Current net worth as a string-encoded Decimal.
    let netWorth: String
    /// Daily change amount as a string-encoded Decimal.
    let dailyChange: String
    /// Daily change percentage as a string-encoded Decimal (e.g., "0.0234" for 2.34%).
    let dailyChangePercent: String
    /// Whether the daily change is positive or zero.
    let isPositive: Bool
    /// ISO 8601 timestamp of when this data was last updated.
    let lastUpdated: Date

    /// Decimal value of net worth, falling back to zero on parse failure.
    var netWorthDecimal: Decimal {
        Decimal(string: netWorth) ?? Decimal.zero
    }

    /// Decimal value of daily change, falling back to zero on parse failure.
    var dailyChangeDecimal: Decimal {
        Decimal(string: dailyChange) ?? Decimal.zero
    }

    /// Decimal value of daily change percent, falling back to zero on parse failure.
    var dailyChangePercentDecimal: Decimal {
        Decimal(string: dailyChangePercent) ?? Decimal.zero
    }
}

/// Data transfer object for health score widget display.
struct HealthScoreWidgetData: Codable, Equatable, Sendable {
    /// Overall financial health score (0-100).
    let overallScore: Int
    /// Human-readable label for the score tier (e.g., "Excellent", "Good").
    let scoreLabel: String
    /// ISO 8601 timestamp of when this data was last updated.
    let lastUpdated: Date

    /// The score as a fraction of 100 for ring display (0.0 to 1.0).
    var scoreFraction: Double {
        Double(overallScore) / 100.0
    }

    /// Returns the tier label based on overall score.
    static func tierLabel(for score: Int) -> String {
        switch score {
        case 90...100: return "Excellent"
        case 75..<90: return "Great"
        case 60..<75: return "Good"
        case 40..<60: return "Fair"
        default: return "Needs Work"
        }
    }
}

/// Data transfer object for milestone/goal widget display.
struct MilestoneWidgetData: Codable, Equatable, Sendable {
    /// Goal display name.
    let goalName: String
    /// Goal type raw value for icon selection.
    let goalTypeRawValue: String
    /// Target amount as a string-encoded Decimal.
    let targetAmount: String
    /// Current amount as a string-encoded Decimal.
    let currentAmount: String
    /// Progress fraction (0.0 to 1.0) as a string-encoded Decimal.
    let progressPercent: String
    /// Optional target date for the goal.
    let targetDate: Date?
    /// ISO 8601 timestamp of when this data was last updated.
    let lastUpdated: Date

    /// Decimal value of target amount.
    var targetAmountDecimal: Decimal {
        Decimal(string: targetAmount) ?? Decimal.zero
    }

    /// Decimal value of current amount.
    var currentAmountDecimal: Decimal {
        Decimal(string: currentAmount) ?? Decimal.zero
    }

    /// Remaining amount toward the goal, clamped to zero (never negative).
    var remainingDecimal: Decimal {
        max(targetAmountDecimal - currentAmountDecimal, Decimal.zero)
    }

    /// Progress as a Double for SwiftUI views, clamped to 0.0...1.0.
    var progressDouble: Double {
        guard let d = Decimal(string: progressPercent) else { return 0 }
        return min(NSDecimalNumber(decimal: d).doubleValue, 1.0)
    }
}

// MARK: - Widget Timeline Entries

/// Timeline entry for the net worth widget.
struct NetWorthWidgetEntry: TimelineEntry {
    let date: Date
    let data: NetWorthWidgetData?
}

/// Timeline entry for the health score widget.
struct HealthScoreWidgetEntry: TimelineEntry {
    let date: Date
    let data: HealthScoreWidgetData?
}

/// Timeline entry for the milestone widget.
struct MilestoneWidgetEntry: TimelineEntry {
    let date: Date
    let data: MilestoneWidgetData?
}

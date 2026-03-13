import Foundation

// MARK: - NotificationRouter

/// Routes incoming push notification payloads to the appropriate app section.
///
/// This is a pure-function struct with no framework dependencies, making it
/// fully testable in isolation.
struct NotificationRouter {

    /// Routes a push notification payload to the correct app section.
    ///
    /// Reads the `"type"` key from `userInfo` and maps known values:
    /// - `"briefing"` → `.reports`
    /// - `"alert"`    → `.aiAdvisor`
    /// - `"account"`  → `.accounts`
    /// - `"goal"`     → `.goals`
    /// - anything else / missing → `.dashboard`
    ///
    /// - Parameter userInfo: The `[AnyHashable: Any]` dictionary delivered by APNs.
    /// - Returns: The `AppSection` the app should navigate to.
    static func route(from userInfo: [AnyHashable: Any]) -> AppSection {
        guard let type_ = userInfo["type"] as? String else {
            return .dashboard
        }
        switch type_ {
        case "briefing": return .reports
        case "alert":    return .aiAdvisor
        case "account":  return .accounts
        case "goal":     return .goals
        default:         return .dashboard
        }
    }
}

import Testing
import Foundation

@testable import wealth_manager

// MARK: - NotificationRouter Tests

@Suite("NotificationRouter")
struct NotificationRouterTests {

    // MARK: Known type routing

    @Test("briefing payload routes to reports")
    func route_briefingPayload_returnsReports() {
        let userInfo: [AnyHashable: Any] = ["type": "briefing"]
        let section = NotificationRouter.route(from: userInfo)
        #expect(section == .reports)
    }

    @Test("alert payload routes to aiAdvisor")
    func route_alertPayload_returnsAIAdvisor() {
        let userInfo: [AnyHashable: Any] = ["type": "alert"]
        let section = NotificationRouter.route(from: userInfo)
        #expect(section == .aiAdvisor)
    }

    @Test("account payload routes to accounts")
    func route_accountPayload_returnsAccounts() {
        let userInfo: [AnyHashable: Any] = ["type": "account"]
        let section = NotificationRouter.route(from: userInfo)
        #expect(section == .accounts)
    }

    @Test("goal payload routes to goals")
    func route_goalPayload_returnsGoals() {
        let userInfo: [AnyHashable: Any] = ["type": "goal"]
        let section = NotificationRouter.route(from: userInfo)
        #expect(section == .goals)
    }

    // MARK: Fallback / edge cases

    @Test("unknown type key falls back to dashboard")
    func route_unknownType_returnsDashboard() {
        let userInfo: [AnyHashable: Any] = ["type": "unknown"]
        let section = NotificationRouter.route(from: userInfo)
        #expect(section == .dashboard)
    }

    @Test("empty payload falls back to dashboard")
    func route_emptyPayload_returnsDashboard() {
        let userInfo: [AnyHashable: Any] = [:]
        let section = NotificationRouter.route(from: userInfo)
        #expect(section == .dashboard)
    }

    @Test("payload without type key falls back to dashboard")
    func route_missingTypeKey_returnsDashboard() {
        let userInfo: [AnyHashable: Any] = ["other": "value"]
        let section = NotificationRouter.route(from: userInfo)
        #expect(section == .dashboard)
    }
}

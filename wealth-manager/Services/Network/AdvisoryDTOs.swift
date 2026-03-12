import Foundation

// MARK: - Enums

/// Severity of a proactive financial alert.
enum AlertSeverity: String, Codable {
    case info = "info"
    case warning = "warning"
    case action = "action"

    /// Sort priority — action is most urgent.
    var sortOrder: Int {
        switch self {
        case .action: return 0
        case .warning: return 1
        case .info: return 2
        }
    }
}

// MARK: - Alert DTO

/// A proactive financial alert from the backend.
struct ProactiveAlertDTO: Codable, Identifiable {
    let id: UUID
    let severity: AlertSeverity
    let title: String
    let message: String
    let ruleName: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, severity, title, message
        case ruleName = "rule_name"
        case createdAt = "created_at"
    }
}

// MARK: - Briefing DTOs

/// A single insight within a CFO briefing.
struct BriefingInsightDTO: Codable {
    let title: String
    let detail: String
    let impact: String  // "positive" | "negative" | "neutral"
}

/// Goal progress snapshot returned inside a CFO briefing.
struct GoalProgressDTO: Codable {
    let goalName: String
    let goalType: String
    let targetAmount: Decimal
    let currentAmount: Decimal

    enum CodingKeys: String, CodingKey {
        case goalName = "goal_name"
        case goalType = "goal_type"
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
    }
}

/// Full CFO briefing report.
struct CFOBriefingDTO: Codable {
    let period: String
    let generatedAt: Date
    let healthScore: Int
    let summary: String
    let insights: [BriefingInsightDTO]
    let actionItems: [String]
    let goalProgress: [GoalProgressDTO]
    let netWorthChange: Decimal

    enum CodingKeys: String, CodingKey {
        case period
        case generatedAt = "generated_at"
        case healthScore = "health_score"
        case summary, insights
        case actionItems = "action_items"
        case goalProgress = "goal_progress"
        case netWorthChange = "net_worth_change"
    }
}

// MARK: - Health Score DTO

/// Financial health score breakdown with AI narrative.
struct HealthScoreResponseDTO: Codable {
    let overallScore: Int
    let savingsScore: Int
    let debtScore: Int
    let investmentScore: Int
    let emergencyFundScore: Int
    let narrative: String

    enum CodingKeys: String, CodingKey {
        case overallScore = "overall_score"
        case savingsScore = "savings_score"
        case debtScore = "debt_score"
        case investmentScore = "investment_score"
        case emergencyFundScore = "emergency_fund_score"
        case narrative
    }
}

// MARK: - Advisory Service Protocol

/// Abstraction over all AI advisory network calls.
protocol AdvisoryServiceProtocol: Sendable {
    /// Streams chat response chunks from the advisor.
    func streamChat(message: String, conversationId: UUID?) -> AsyncThrowingStream<String, Error>

    /// Fetches the CFO briefing for the given period ("weekly" | "monthly").
    func fetchBriefing(period: String) async throws -> CFOBriefingDTO

    /// Fetches the financial health score breakdown.
    func fetchHealthScore() async throws -> HealthScoreResponseDTO

    /// Fetches proactive financial alerts.
    func fetchAlerts() async throws -> [ProactiveAlertDTO]
}

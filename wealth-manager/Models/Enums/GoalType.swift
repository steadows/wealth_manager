import Foundation

enum GoalType: String, Codable, CaseIterable, Identifiable {
    case retirement
    case emergencyFund
    case homePurchase
    case debtPayoff
    case education
    case travel
    case investment
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .retirement: "Retirement"
        case .emergencyFund: "Emergency Fund"
        case .homePurchase: "Home Purchase"
        case .debtPayoff: "Debt Payoff"
        case .education: "Education"
        case .travel: "Travel"
        case .investment: "Investment"
        case .custom: "Custom"
        }
    }
}

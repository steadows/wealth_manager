import Foundation

enum AccountType: String, Codable, CaseIterable, Identifiable {
    case checking
    case savings
    case creditCard
    case investment
    case loan
    case retirement
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .checking: "Checking"
        case .savings: "Savings"
        case .creditCard: "Credit Card"
        case .investment: "Investment"
        case .loan: "Loan"
        case .retirement: "Retirement"
        case .other: "Other"
        }
    }
}

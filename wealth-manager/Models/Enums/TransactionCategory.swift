import Foundation

enum TransactionCategory: String, Codable, CaseIterable, Identifiable {
    case income
    case housing
    case transportation
    case food
    case utilities
    case healthcare
    case entertainment
    case shopping
    case education
    case personalCare
    case travel
    case gifts
    case fees
    case transfer
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .income: "Income"
        case .housing: "Housing"
        case .transportation: "Transportation"
        case .food: "Food"
        case .utilities: "Utilities"
        case .healthcare: "Healthcare"
        case .entertainment: "Entertainment"
        case .shopping: "Shopping"
        case .education: "Education"
        case .personalCare: "Personal Care"
        case .travel: "Travel"
        case .gifts: "Gifts"
        case .fees: "Fees"
        case .transfer: "Transfer"
        case .other: "Other"
        }
    }
}

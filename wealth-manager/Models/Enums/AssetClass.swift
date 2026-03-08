import Foundation

enum AssetClass: String, Codable, CaseIterable, Identifiable {
    case usEquity
    case intlEquity
    case fixedIncome
    case realEstate
    case commodities
    case cash
    case alternative

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usEquity: "US Equity"
        case .intlEquity: "International Equity"
        case .fixedIncome: "Fixed Income"
        case .realEstate: "Real Estate"
        case .commodities: "Commodities"
        case .cash: "Cash"
        case .alternative: "Alternative"
        }
    }
}

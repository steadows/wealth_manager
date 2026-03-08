import Foundation

enum HoldingType: String, Codable, CaseIterable, Identifiable {
    case stock
    case bond
    case etf
    case mutualFund
    case crypto
    case cash
    case reit
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stock: "Stock"
        case .bond: "Bond"
        case .etf: "ETF"
        case .mutualFund: "Mutual Fund"
        case .crypto: "Crypto"
        case .cash: "Cash"
        case .reit: "REIT"
        case .other: "Other"
        }
    }
}

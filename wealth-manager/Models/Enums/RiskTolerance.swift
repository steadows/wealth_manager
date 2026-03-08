import Foundation

enum RiskTolerance: String, Codable, CaseIterable, Identifiable {
    case conservative
    case moderate
    case aggressive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .conservative: "Conservative"
        case .moderate: "Moderate"
        case .aggressive: "Aggressive"
        }
    }
}

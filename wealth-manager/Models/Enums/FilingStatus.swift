import Foundation

enum FilingStatus: String, Codable, CaseIterable, Identifiable {
    case single
    case marriedJoint
    case marriedSeparate
    case headOfHousehold

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .single: "Single"
        case .marriedJoint: "Married Filing Jointly"
        case .marriedSeparate: "Married Filing Separately"
        case .headOfHousehold: "Head of Household"
        }
    }
}

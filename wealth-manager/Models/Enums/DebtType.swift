import Foundation

enum DebtType: String, Codable, CaseIterable, Identifiable {
    case mortgage
    case auto
    case student
    case creditCard
    case personal
    case medical
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mortgage: "Mortgage"
        case .auto: "Auto"
        case .student: "Student"
        case .creditCard: "Credit Card"
        case .personal: "Personal"
        case .medical: "Medical"
        case .other: "Other"
        }
    }
}

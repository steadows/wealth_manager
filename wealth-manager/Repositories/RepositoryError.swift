import Foundation

enum RepositoryError: Error, LocalizedError {
    case notFound(UUID)
    case duplicateBudgetCategory

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            "Record with ID \(id) not found"
        case .duplicateBudgetCategory:
            "A budget category for this category, month, and year already exists"
        }
    }
}

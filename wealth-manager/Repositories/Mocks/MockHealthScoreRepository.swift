import Foundation

final class MockHealthScoreRepository: HealthScoreRepository {
    var items: [FinancialHealthScore] = []

    func fetchLatest() async throws -> FinancialHealthScore? {
        items
            .sorted { $0.date > $1.date }
            .first
    }

    func fetchByDateRange(_ range: ClosedRange<Date>) async throws -> [FinancialHealthScore] {
        items.filter { range.contains($0.date) }
    }

    func create(_ score: FinancialHealthScore) async throws {
        items.append(score)
    }
}

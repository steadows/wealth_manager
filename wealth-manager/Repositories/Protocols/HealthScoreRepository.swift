import Foundation

protocol HealthScoreRepository {
    func fetchLatest() async throws -> FinancialHealthScore?
    func fetchByDateRange(_ range: ClosedRange<Date>) async throws -> [FinancialHealthScore]
    func create(_ score: FinancialHealthScore) async throws
}

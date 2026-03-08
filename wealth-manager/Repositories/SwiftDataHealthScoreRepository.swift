import Foundation
import SwiftData

@ModelActor
actor SwiftDataHealthScoreRepository: HealthScoreRepository {

    func fetchLatest() async throws -> FinancialHealthScore? {
        var descriptor = FetchDescriptor<FinancialHealthScore>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func fetchByDateRange(_ range: ClosedRange<Date>) async throws -> [FinancialHealthScore] {
        let start = range.lowerBound
        let end = range.upperBound
        let descriptor = FetchDescriptor<FinancialHealthScore>(
            predicate: #Predicate { $0.date >= start && $0.date <= end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func create(_ score: FinancialHealthScore) async throws {
        modelContext.insert(score)
        try modelContext.save()
    }
}

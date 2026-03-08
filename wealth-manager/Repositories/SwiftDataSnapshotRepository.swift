import Foundation
import SwiftData

@ModelActor
actor SwiftDataSnapshotRepository: SnapshotRepository {

    func fetchAll() async throws -> [NetWorthSnapshot] {
        let descriptor = FetchDescriptor<NetWorthSnapshot>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchByDateRange(_ range: ClosedRange<Date>) async throws -> [NetWorthSnapshot] {
        let start = range.lowerBound
        let end = range.upperBound
        let descriptor = FetchDescriptor<NetWorthSnapshot>(
            predicate: #Predicate { $0.date >= start && $0.date <= end },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchLatest() async throws -> NetWorthSnapshot? {
        var descriptor = FetchDescriptor<NetWorthSnapshot>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func create(_ snapshot: NetWorthSnapshot) async throws {
        modelContext.insert(snapshot)
        try modelContext.save()
    }
}

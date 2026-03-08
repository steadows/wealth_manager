import Foundation

final class MockSnapshotRepository: SnapshotRepository {
    var items: [NetWorthSnapshot] = []

    func fetchAll() async throws -> [NetWorthSnapshot] {
        items
    }

    func fetchByDateRange(_ range: ClosedRange<Date>) async throws -> [NetWorthSnapshot] {
        items.filter { range.contains($0.date) }
    }

    func fetchLatest() async throws -> NetWorthSnapshot? {
        items
            .sorted { $0.date > $1.date }
            .first
    }

    func create(_ snapshot: NetWorthSnapshot) async throws {
        items.append(snapshot)
    }
}

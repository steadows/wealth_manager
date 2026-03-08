import Foundation

protocol SnapshotRepository {
    func fetchAll() async throws -> [NetWorthSnapshot]
    func fetchByDateRange(_ range: ClosedRange<Date>) async throws -> [NetWorthSnapshot]
    func fetchLatest() async throws -> NetWorthSnapshot?
    func create(_ snapshot: NetWorthSnapshot) async throws
}

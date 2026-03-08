import Foundation
import Observation

// MARK: - NetWorthService

/// Orchestration service that bridges account/snapshot repositories with net worth calculations.
/// Creates snapshots from current account data and provides historical change analysis.
@Observable final class NetWorthService {

    // MARK: - Dependencies

    private let accountRepo: any AccountRepository
    private let snapshotRepo: any SnapshotRepository

    // MARK: - Init

    /// Create a new `NetWorthService` with the given repositories.
    ///
    /// - Parameters:
    ///   - accountRepo: Repository for fetching account data.
    ///   - snapshotRepo: Repository for persisting and querying snapshots.
    init(accountRepo: any AccountRepository, snapshotRepo: any SnapshotRepository) {
        self.accountRepo = accountRepo
        self.snapshotRepo = snapshotRepo
    }

    // MARK: - Public API

    /// Create a snapshot of the current net worth by summing all account balances.
    /// Persists the snapshot via the snapshot repository and returns it.
    ///
    /// - Returns: A newly created `NetWorthSnapshot`.
    /// - Throws: Repository errors from fetching accounts or persisting the snapshot.
    func createSnapshot() async throws -> NetWorthSnapshot {
        let totalAssets = try await accountRepo.totalAssets()
        let totalLiabilities = try await accountRepo.totalLiabilities()

        let snapshot = NetWorthSnapshot(
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities
        )

        try await snapshotRepo.create(snapshot)
        return snapshot
    }

    /// Fetch historical snapshots within a date range, sorted by date.
    ///
    /// - Parameter dateRange: The closed date range to query.
    /// - Returns: Array of `NetWorthSnapshot` within the range.
    /// - Throws: Repository errors.
    func history(dateRange: ClosedRange<Date>) async throws -> [NetWorthSnapshot] {
        try await snapshotRepo.fetchByDateRange(dateRange)
    }

    /// Calculate the net worth change over a time period.
    ///
    /// - Parameter period: The time period to evaluate.
    /// - Returns: Tuple of absolute change amount and percentage change.
    /// - Throws: Repository errors.
    func change(period: TimePeriod) async throws -> (amount: Decimal, percent: Decimal) {
        let dateRange = period.dateRange(from: Date())
        let snapshots = try await snapshotRepo.fetchByDateRange(dateRange)

        guard let earliest = snapshots.first, let latest = snapshots.last else {
            return (amount: 0, percent: 0)
        }

        let earliestNW = earliest.netWorth
        let latestNW = latest.netWorth
        let amount = latestNW - earliestNW

        let percent: Decimal
        if earliestNW != 0 {
            percent = amount / earliestNW
        } else if amount > 0 {
            percent = 1
        } else {
            percent = 0
        }

        return (amount: amount, percent: percent)
    }
}

import Foundation
import Observation

// MARK: - AssetBreakdownEntry

/// Represents one slice of the asset breakdown by account type.
struct AssetBreakdownEntry: Identifiable, Sendable {
    let id = UUID()
    let type: AccountType
    let amount: Decimal
    let percentage: Decimal
}

// MARK: - NetWorthViewModel

/// ViewModel for the Net Worth screen: current totals, history chart, asset breakdown, milestones.
@Observable
final class NetWorthViewModel {

    // MARK: - Published State

    var netWorth: Decimal = 0
    var totalAssets: Decimal = 0
    var totalLiabilities: Decimal = 0
    var changeAmount: Decimal = 0
    var changePercent: Decimal = 0
    var history: [NetWorthSnapshot] = []
    var assetBreakdown: [AssetBreakdownEntry] = []
    var milestones: [(milestone: Decimal, date: Date)] = []
    var selectedTimePeriod: TimePeriod = .year
    var isLoading: Bool = false
    var error: Error?

    // MARK: - Dependencies

    private let netWorthService: NetWorthService
    private let projectionService: ProjectionService
    private let accountRepo: any AccountRepository
    private let profileRepo: any UserProfileRepository

    // MARK: - Init

    init(
        netWorthService: NetWorthService,
        projectionService: ProjectionService,
        accountRepo: any AccountRepository,
        profileRepo: any UserProfileRepository
    ) {
        self.netWorthService = netWorthService
        self.projectionService = projectionService
        self.accountRepo = accountRepo
        self.profileRepo = profileRepo
    }

    // MARK: - Data Loading

    /// Loads all net worth data: totals, history, breakdown, milestones.
    func loadData() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        do {
            // Fetch accounts for totals and breakdown
            let accounts = try await accountRepo.fetchAll()
            let assets = accounts.filter(\.isAsset).reduce(Decimal.zero) { $0 + $1.currentBalance }
            let liabilities = accounts.filter(\.isLiability).reduce(Decimal.zero) { $0 + $1.currentBalance }

            totalAssets = assets
            totalLiabilities = liabilities
            netWorth = assets - liabilities

            // Asset breakdown by type
            assetBreakdown = buildAssetBreakdown(accounts: accounts, totalAssets: assets)

            // History from snapshots
            let dateRange = selectedTimePeriod.dateRange(from: Date())
            history = try await netWorthService.history(dateRange: dateRange)

            // Change calculation
            let change = try await netWorthService.change(period: selectedTimePeriod)
            changeAmount = change.amount
            changePercent = change.percent

            // Milestones (needs profile)
            let profile = try await profileRepo.fetch()
            if let profile {
                milestones = await projectionService.milestones(
                    currentNetWorth: netWorth,
                    profile: profile
                )
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Private Helpers

    private func buildAssetBreakdown(accounts: [Account], totalAssets: Decimal) -> [AssetBreakdownEntry] {
        let assetAccounts = accounts.filter(\.isAsset)
        var byType: [AccountType: Decimal] = [:]

        for account in assetAccounts {
            byType[account.accountType, default: 0] += account.currentBalance
        }

        return byType.map { type, amount in
            let percentage = totalAssets > 0 ? amount / totalAssets : 0
            return AssetBreakdownEntry(type: type, amount: amount, percentage: percentage)
        }.sorted { $0.amount > $1.amount }
    }
}

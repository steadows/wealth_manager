import Foundation

// MARK: - SyncService

/// Manages bidirectional delta sync between iOS client and backend.
/// Pull: fetches changes since last sync and upserts into local repositories.
/// Push: sends locally-created manual entries to the backend.
final class SyncService: @unchecked Sendable {
    private let apiClient: APIClientProtocol
    private let accountRepo: AccountRepository
    private let goalRepo: GoalRepository
    private let debtRepo: DebtRepository

    private let defaults: UserDefaults
    private let lastSyncedAtKey: String

    /// The timestamp of the last successful sync.
    var lastSyncedAt: Date? {
        get { defaults.object(forKey: lastSyncedAtKey) as? Date }
        set { defaults.set(newValue, forKey: lastSyncedAtKey) }
    }

    init(
        apiClient: APIClientProtocol,
        accountRepo: AccountRepository,
        goalRepo: GoalRepository,
        debtRepo: DebtRepository,
        defaults: UserDefaults = .standard,
        lastSyncedAtKey: String = "com.wealthmanager.lastSyncedAt"
    ) {
        self.apiClient = apiClient
        self.accountRepo = accountRepo
        self.goalRepo = goalRepo
        self.debtRepo = debtRepo
        self.defaults = defaults
        self.lastSyncedAtKey = lastSyncedAtKey
    }

    // MARK: - Pull Changes

    /// Fetches all data modified since the last sync and upserts locally.
    func pullChanges() async throws {
        let endpoint = Endpoint.syncPull(since: lastSyncedAt)
        let response: SyncResponseDTO = try await apiClient.request(endpoint)

        // Upsert accounts
        for accountDTO in response.accounts {
            let account = accountDTO.toModel()
            try await accountRepo.upsert(account)
        }

        // Update sync timestamp
        lastSyncedAt = response.syncedAt
    }

    // MARK: - Push Changes

    /// Pushes locally-created manual entries to the backend.
    func pushChanges() async throws {
        let allAccounts = try await accountRepo.fetchAll()
        let manualAccounts = allAccounts.filter { $0.isManual && $0.plaidAccountId == nil }

        let accountDTOs = manualAccounts.map { $0.toCreateDTO() }
        let allGoals = try await goalRepo.fetchAll()
        let goalDTOs = allGoals.map { $0.toCreateDTO() }
        let allDebts = try await debtRepo.fetchAll()
        let debtDTOs = allDebts.map { $0.toCreateDTO() }

        let changes = ClientChangesDTO(
            accounts: accountDTOs,
            goals: goalDTOs,
            debts: debtDTOs
        )

        let result: SyncResultDTO = try await apiClient.request(.syncPush(changes))
        lastSyncedAt = result.syncedAt
    }

    // MARK: - Full Sync

    /// Performs a complete bidirectional sync: pull then push.
    func fullSync() async throws {
        try await pullChanges()
        try await pushChanges()
    }
}

// MARK: - DTO ↔ Model Conversion

extension AccountResponseDTO {
    /// Converts a backend account response to a local SwiftData model.
    func toModel() -> Account {
        Account(
            id: id,
            plaidAccountId: plaidAccountId,
            institutionName: institutionName,
            accountName: accountName,
            accountType: AccountType(rawValue: accountType) ?? .other,
            currentBalance: currentBalance,
            availableBalance: availableBalance,
            currency: currency,
            isManual: isManual,
            isHidden: isHidden,
            lastSyncedAt: lastSyncedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

extension Account {
    /// Converts a local account model to a create DTO for pushing to backend.
    func toCreateDTO() -> AccountCreateDTO {
        AccountCreateDTO(
            institutionName: institutionName,
            accountName: accountName,
            accountType: accountType.rawValue,
            currentBalance: currentBalance,
            availableBalance: availableBalance,
            currency: currency,
            isManual: isManual
        )
    }
}

extension FinancialGoal {
    /// Converts a local goal model to a create DTO.
    func toCreateDTO() -> GoalCreateDTO {
        GoalCreateDTO(
            name: goalName,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            targetDate: targetDate
        )
    }
}

extension Debt {
    /// Converts a local debt model to a create DTO.
    func toCreateDTO() -> DebtCreateDTO {
        DebtCreateDTO(
            name: debtName,
            balance: currentBalance,
            interestRate: interestRate,
            minimumPayment: minimumPayment
        )
    }
}

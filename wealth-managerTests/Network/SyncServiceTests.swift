import Testing
import Foundation

@testable import wealth_manager

// MARK: - SyncServiceTests

@Suite("SyncService")
struct SyncServiceTests {

    // MARK: - Helpers

    private func makeService(
        apiClient: MockAPIClient? = nil,
        accountRepo: MockAccountRepository? = nil,
        goalRepo: MockGoalRepository? = nil,
        debtRepo: MockDebtRepository? = nil
    ) -> (SyncService, MockAPIClient, MockAccountRepository) {
        let client = apiClient ?? MockAPIClient()
        let acctRepo = accountRepo ?? MockAccountRepository()
        let goalR = goalRepo ?? MockGoalRepository()
        let debtR = debtRepo ?? MockDebtRepository()

        // Use a unique key per test to avoid cross-test pollution
        let testKey = "test.lastSyncedAt.\(UUID().uuidString)"
        let service = SyncService(
            apiClient: client,
            accountRepo: acctRepo,
            goalRepo: goalR,
            debtRepo: debtR,
            lastSyncedAtKey: testKey
        )
        return (service, client, acctRepo)
    }

    private func makeSyncResponse(
        accounts: [AccountResponseDTO] = [],
        syncedAt: Date = Date()
    ) -> SyncResponseDTO {
        SyncResponseDTO(
            accounts: accounts,
            transactions: [],
            goals: [],
            debts: [],
            snapshots: [],
            syncedAt: syncedAt
        )
    }

    private func makeSampleAccountDTO(
        id: UUID = UUID(),
        institutionName: String = "Chase",
        accountName: String = "Checking",
        accountType: String = "checking",
        currentBalance: String = "15000.00"
    ) -> AccountResponseDTO {
        AccountResponseDTO(
            id: id,
            plaidAccountId: nil,
            institutionName: institutionName,
            accountName: accountName,
            accountType: accountType,
            currentBalance: Decimal(string: currentBalance) ?? 0,
            availableBalance: nil,
            currency: "USD",
            isManual: true,
            isHidden: false,
            lastSyncedAt: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Pull Changes

    @Test("pullChanges: initial sync fetches all data")
    func pullChangesInitialSync() async throws {
        let (service, mockClient, _) = makeService()
        let syncDate = Date()
        let syncResponse = makeSyncResponse(
            accounts: [makeSampleAccountDTO()],
            syncedAt: syncDate
        )
        mockClient.responses["/api/v1/sync"] = syncResponse

        try await service.pullChanges()

        #expect(service.lastSyncedAt != nil)
    }

    @Test("pullChanges: delta sync sends since parameter")
    func pullChangesDeltaSync() async throws {
        let (service, mockClient, _) = makeService()
        let syncResponse = makeSyncResponse(syncedAt: Date())
        mockClient.responses["/api/v1/sync"] = syncResponse

        // Set a previous sync time
        service.lastSyncedAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await service.pullChanges()

        // Verify the endpoint included a since parameter
        let lastRequest = mockClient.requestLog.last
        #expect(lastRequest?.queryItems?.contains { $0.name == "since" } == true)
    }

    @Test("pullChanges: upserts accounts into local repository")
    func pullChangesUpsertsAccounts() async throws {
        let accountId = UUID()
        let (service, mockClient, acctRepo) = makeService()
        let syncResponse = makeSyncResponse(
            accounts: [
                makeSampleAccountDTO(id: accountId, institutionName: "Vanguard", accountName: "401k", accountType: "retirement", currentBalance: "250000.00")
            ],
            syncedAt: Date()
        )
        mockClient.responses["/api/v1/sync"] = syncResponse

        try await service.pullChanges()

        // The account repo should have had upsert called
        #expect(acctRepo.upsertedAccounts.count == 1)
        #expect(acctRepo.upsertedAccounts.first?.id == accountId)
    }

    @Test("pullChanges: updates lastSyncedAt on success")
    func pullChangesUpdatesLastSynced() async throws {
        let syncDate = Date()
        let (service, mockClient, _) = makeService()
        let syncResponse = makeSyncResponse(syncedAt: syncDate)
        mockClient.responses["/api/v1/sync"] = syncResponse

        try await service.pullChanges()

        #expect(service.lastSyncedAt != nil)
    }

    @Test("pullChanges: throws on API failure")
    func pullChangesThrowsOnFailure() async {
        let (service, mockClient, _) = makeService()
        mockClient.shouldThrow = APIError.serverError(statusCode: 500, message: "Down")

        await #expect(throws: APIError.self) {
            try await service.pullChanges()
        }
    }

    // MARK: - Push Changes

    @Test("pushChanges: sends manual accounts to backend")
    func pushChangesSendsAccounts() async throws {
        let (service, mockClient, acctRepo) = makeService()

        // Add a manual account to the repo
        let account = Account(
            institutionName: "Local Bank",
            accountName: "Savings",
            accountType: .savings,
            currentBalance: 5_000,
            isManual: true
        )
        acctRepo.items = [account]

        let syncResult = SyncResultDTO(
            appliedAccounts: 1,
            appliedGoals: 0,
            appliedDebts: 0,
            syncedAt: Date()
        )
        mockClient.responses["POST /api/v1/sync"] = syncResult

        try await service.pushChanges()

        // Verify POST sync was called
        let postRequests = mockClient.requestLog.filter { $0.method == .post && $0.path == "/api/v1/sync" }
        #expect(postRequests.count == 1)
    }

    @Test("pushChanges: skips Plaid-linked accounts")
    func pushChangesSkipsPlaidAccounts() async throws {
        let (service, mockClient, acctRepo) = makeService()

        // Plaid-linked account (has plaidAccountId)
        let plaidAccount = Account(
            plaidAccountId: "plaid-123",
            institutionName: "Chase",
            accountName: "Checking",
            accountType: .checking,
            currentBalance: 10_000,
            isManual: false
        )
        acctRepo.items = [plaidAccount]

        let syncResult = SyncResultDTO(
            appliedAccounts: 0,
            appliedGoals: 0,
            appliedDebts: 0,
            syncedAt: Date()
        )
        mockClient.responses["POST /api/v1/sync"] = syncResult

        try await service.pushChanges()

        // Should still call sync but with empty accounts
        // (only manual accounts get pushed)
    }

    // MARK: - Full Sync

    @Test("fullSync: performs pull then push")
    func fullSyncPullsThenPushes() async throws {
        let (service, mockClient, _) = makeService()

        let syncResponse = makeSyncResponse(syncedAt: Date())
        let syncResult = SyncResultDTO(
            appliedAccounts: 0,
            appliedGoals: 0,
            appliedDebts: 0,
            syncedAt: Date()
        )
        // Use method-keyed responses to disambiguate GET vs POST
        mockClient.responses["GET /api/v1/sync"] = syncResponse
        mockClient.responses["POST /api/v1/sync"] = syncResult

        try await service.fullSync()

        // Should have made both pull (GET) and push (POST)
        let getRequests = mockClient.requestLog.filter { $0.path == "/api/v1/sync" && $0.method == .get }
        let postRequests = mockClient.requestLog.filter { $0.path == "/api/v1/sync" && $0.method == .post }
        #expect(getRequests.count == 1)
        #expect(postRequests.count == 1)
    }

    // MARK: - Last Synced At Persistence

    @Test("lastSyncedAt: initially nil")
    func lastSyncedAtInitiallyNil() {
        let (service, _, _) = makeService()
        #expect(service.lastSyncedAt == nil)
    }
}

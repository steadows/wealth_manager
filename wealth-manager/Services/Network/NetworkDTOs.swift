import Foundation

// MARK: - API Response Envelope

/// Matches backend's APIResponse[T] envelope.
struct APIResponseEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: String?
}

// MARK: - Health DTO

struct HealthResponseDTO: Codable {
    let status: String
}

// MARK: - Auth DTOs

struct LoginResponseDTO: Codable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

struct TokenResponseDTO: Codable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

struct UserResponseDTO: Codable {
    let id: UUID
    let email: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email
        case createdAt = "created_at"
    }
}

// MARK: - Account DTOs

struct AccountResponseDTO: Codable {
    let id: UUID
    let plaidAccountId: String?
    let institutionName: String
    let accountName: String
    let accountType: String
    let currentBalance: Decimal
    let availableBalance: Decimal?
    let currency: String
    let isManual: Bool
    let isHidden: Bool
    let lastSyncedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case plaidAccountId = "plaid_account_id"
        case institutionName = "institution_name"
        case accountName = "account_name"
        case accountType = "account_type"
        case currentBalance = "current_balance"
        case availableBalance = "available_balance"
        case currency
        case isManual = "is_manual"
        case isHidden = "is_hidden"
        case lastSyncedAt = "last_synced_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct AccountCreateDTO: Codable {
    let institutionName: String
    let accountName: String
    let accountType: String
    let currentBalance: Decimal
    let availableBalance: Decimal?
    let currency: String
    let isManual: Bool

    enum CodingKeys: String, CodingKey {
        case institutionName = "institution_name"
        case accountName = "account_name"
        case accountType = "account_type"
        case currentBalance = "current_balance"
        case availableBalance = "available_balance"
        case currency
        case isManual = "is_manual"
    }
}

// MARK: - Sync DTOs

struct SyncResponseDTO: Codable {
    let accounts: [AccountResponseDTO]
    let transactions: [TransactionResponseDTO]
    let goals: [GoalResponseDTO]
    let debts: [DebtResponseDTO]
    let snapshots: [SnapshotResponseDTO]
    let syncedAt: Date

    enum CodingKeys: String, CodingKey {
        case accounts, transactions, goals, debts, snapshots
        case syncedAt = "synced_at"
    }
}

struct ClientChangesDTO: Codable {
    let accounts: [AccountCreateDTO]
    let goals: [GoalCreateDTO]
    let debts: [DebtCreateDTO]
}

struct SyncResultDTO: Codable {
    let appliedAccounts: Int
    let appliedGoals: Int
    let appliedDebts: Int
    let syncedAt: Date

    enum CodingKeys: String, CodingKey {
        case appliedAccounts = "applied_accounts"
        case appliedGoals = "applied_goals"
        case appliedDebts = "applied_debts"
        case syncedAt = "synced_at"
    }
}

// MARK: - Plaid DTOs

struct PlaidLinkResponseDTO: Codable {
    let linkToken: String

    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
    }
}

struct PlaidExchangeResponseDTO: Codable {
    let accounts: [AccountResponseDTO]
}

/// Response from `POST /api/v1/plaid/hosted-link-token`.
struct PlaidHostedLinkResponseDTO: Codable {
    let linkToken: String
    let hostedLinkUrl: String

    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
        case hostedLinkUrl = "hosted_link_url"
    }
}

/// Response from `POST /api/v1/plaid/resolve-session`.
struct PlaidResolveSessionResponseDTO: Codable {
    let status: String
    let accounts: [AccountResponseDTO]?
}

// MARK: - Stub DTOs for sync sub-entities
// These match the backend schemas; full fields added as needed.

struct TransactionResponseDTO: Codable {
    let id: UUID
    let accountId: UUID
    let plaidTransactionId: String?
    let amount: Decimal
    let date: Date
    let merchantName: String?
    let category: String
    let subcategory: String?
    let note: String?
    let isRecurring: Bool
    let isPending: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case accountId = "account_id"
        case plaidTransactionId = "plaid_transaction_id"
        case amount, date
        case merchantName = "merchant_name"
        case category, subcategory, note
        case isRecurring = "is_recurring"
        case isPending = "is_pending"
        case createdAt = "created_at"
    }
}

/// Response from `GET /api/v1/transactions/{account_id}`.
struct TransactionListResponseDTO: Codable {
    let transactions: [TransactionResponseDTO]
    let total: Int
    let limit: Int
    let offset: Int
}

struct GoalResponseDTO: Codable {
    let id: UUID
    let name: String
    let targetAmount: Decimal
    let currentAmount: Decimal
    let targetDate: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
        case targetDate = "target_date"
        case createdAt = "created_at"
    }
}

struct GoalCreateDTO: Codable {
    let name: String
    let targetAmount: Decimal
    let currentAmount: Decimal
    let targetDate: Date?

    enum CodingKeys: String, CodingKey {
        case name
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
        case targetDate = "target_date"
    }
}

struct DebtResponseDTO: Codable {
    let id: UUID
    let name: String
    let balance: Decimal
    let interestRate: Decimal
    let minimumPayment: Decimal
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, balance
        case interestRate = "interest_rate"
        case minimumPayment = "minimum_payment"
        case createdAt = "created_at"
    }
}

struct DebtCreateDTO: Codable {
    let name: String
    let balance: Decimal
    let interestRate: Decimal
    let minimumPayment: Decimal

    enum CodingKeys: String, CodingKey {
        case name, balance
        case interestRate = "interest_rate"
        case minimumPayment = "minimum_payment"
    }
}

struct SnapshotResponseDTO: Codable {
    let id: UUID
    let date: Date
    let totalAssets: Decimal
    let totalLiabilities: Decimal
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, date
        case totalAssets = "total_assets"
        case totalLiabilities = "total_liabilities"
        case createdAt = "created_at"
    }
}

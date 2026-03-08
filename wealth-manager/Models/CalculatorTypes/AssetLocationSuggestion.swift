import Foundation

nonisolated struct AssetLocationSuggestion: Sendable, Equatable, Identifiable {
    let id: UUID
    let holdingId: UUID
    let currentAccountId: UUID
    let suggestedAccountType: AccountType
    let reason: String
    let estimatedAnnualTaxSavings: Decimal

    init(
        id: UUID = UUID(),
        holdingId: UUID,
        currentAccountId: UUID,
        suggestedAccountType: AccountType,
        reason: String,
        estimatedAnnualTaxSavings: Decimal
    ) {
        self.id = id
        self.holdingId = holdingId
        self.currentAccountId = currentAccountId
        self.suggestedAccountType = suggestedAccountType
        self.reason = reason
        self.estimatedAnnualTaxSavings = estimatedAnnualTaxSavings
    }
}

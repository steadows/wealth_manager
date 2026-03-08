import Foundation
import SwiftData

@Model
final class FinancialHealthScore {
    @Attribute(.unique) var id: UUID
    var date: Date
    var overallScore: Int
    var savingsScore: Int
    var debtScore: Int
    var investmentScore: Int
    var emergencyFundScore: Int
    var insuranceScore: Int

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        overallScore: Int,
        savingsScore: Int,
        debtScore: Int,
        investmentScore: Int,
        emergencyFundScore: Int,
        insuranceScore: Int
    ) {
        precondition((0...100).contains(overallScore), "overallScore must be 0–100, got \(overallScore)")
        precondition((0...100).contains(savingsScore), "savingsScore must be 0–100, got \(savingsScore)")
        precondition((0...100).contains(debtScore), "debtScore must be 0–100, got \(debtScore)")
        precondition((0...100).contains(investmentScore), "investmentScore must be 0–100, got \(investmentScore)")
        precondition((0...100).contains(emergencyFundScore), "emergencyFundScore must be 0–100, got \(emergencyFundScore)")
        precondition((0...100).contains(insuranceScore), "insuranceScore must be 0–100, got \(insuranceScore)")

        self.id = id
        self.date = date
        self.overallScore = overallScore
        self.savingsScore = savingsScore
        self.debtScore = debtScore
        self.investmentScore = investmentScore
        self.emergencyFundScore = emergencyFundScore
        self.insuranceScore = insuranceScore
    }
}

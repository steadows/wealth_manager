import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var dateOfBirth: Date?
    var annualIncome: Decimal?
    var monthlyExpenses: Decimal?
    var filingStatus: FilingStatus = FilingStatus.single
    var stateOfResidence: String?
    var retirementAge: Int = 65
    var riskTolerance: RiskTolerance = RiskTolerance.moderate
    var dependents: Int = 0
    var hasSpouse: Bool = false
    var spouseIncome: Decimal?
    var createdAt: Date
    var updatedAt: Date

    var age: Int? {
        guard let dateOfBirth else { return nil }
        let components = Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date())
        return components.year
    }

    var yearsToRetirement: Int? {
        guard let currentAge = age else { return nil }
        return max(0, retirementAge - currentAge)
    }

    var householdIncome: Decimal? {
        guard let income = annualIncome else { return nil }
        if hasSpouse, let spouseIncome {
            return income + spouseIncome
        }
        return income
    }

    init(
        id: UUID = UUID(),
        dateOfBirth: Date? = nil,
        annualIncome: Decimal? = nil,
        monthlyExpenses: Decimal? = nil,
        filingStatus: FilingStatus = .single,
        stateOfResidence: String? = nil,
        retirementAge: Int = 65,
        riskTolerance: RiskTolerance = .moderate,
        dependents: Int = 0,
        hasSpouse: Bool = false,
        spouseIncome: Decimal? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dateOfBirth = dateOfBirth
        self.annualIncome = annualIncome
        self.monthlyExpenses = monthlyExpenses
        self.filingStatus = filingStatus
        self.stateOfResidence = stateOfResidence
        self.retirementAge = retirementAge
        self.riskTolerance = riskTolerance
        self.dependents = dependents
        self.hasSpouse = hasSpouse
        self.spouseIncome = spouseIncome
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

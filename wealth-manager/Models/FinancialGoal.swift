import Foundation
import SwiftData

@Model
final class FinancialGoal {
    @Attribute(.unique) var id: UUID
    var goalName: String
    var goalTypeRawValue: String

    @Transient var goalType: GoalType {
        get { GoalType(rawValue: goalTypeRawValue) ?? .custom }
        set { goalTypeRawValue = newValue.rawValue }
    }

    var targetAmount: Decimal
    var currentAmount: Decimal
    var targetDate: Date?
    var monthlyContribution: Decimal?
    var priority: Int
    var isActive: Bool = true
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    var progressPercent: Decimal {
        guard targetAmount != 0 else { return 0 }
        return currentAmount / targetAmount
    }

    var remainingAmount: Decimal {
        targetAmount - currentAmount
    }

    var isOnTrack: Bool {
        guard let targetDate else { return true }
        guard let contribution = monthlyContribution, contribution > 0 else {
            return currentAmount >= targetAmount
        }
        let calendar = Calendar.current
        let now = Date()
        guard targetDate > now else {
            return currentAmount >= targetAmount
        }
        let components = calendar.dateComponents([.month], from: now, to: targetDate)
        let monthsRemaining = Decimal(components.month ?? 0)
        let projectedTotal = currentAmount + (contribution * monthsRemaining)
        return projectedTotal >= targetAmount
    }

    init(
        id: UUID = UUID(),
        goalName: String,
        goalType: GoalType,
        targetAmount: Decimal,
        currentAmount: Decimal = 0,
        targetDate: Date? = nil,
        monthlyContribution: Decimal? = nil,
        priority: Int,
        isActive: Bool = true,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.goalName = goalName
        self.goalTypeRawValue = goalType.rawValue
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.targetDate = targetDate
        self.monthlyContribution = monthlyContribution
        self.priority = priority
        self.isActive = isActive
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

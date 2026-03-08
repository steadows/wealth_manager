import Foundation
import SwiftData

@ModelActor
actor SwiftDataUserProfileRepository: UserProfileRepository {

    func fetch() async throws -> UserProfile? {
        var descriptor = FetchDescriptor<UserProfile>()
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func createOrUpdate(_ profile: UserProfile) async throws {
        if let existing = try await fetch() {
            existing.dateOfBirth = profile.dateOfBirth
            existing.annualIncome = profile.annualIncome
            existing.monthlyExpenses = profile.monthlyExpenses
            existing.filingStatus = profile.filingStatus
            existing.stateOfResidence = profile.stateOfResidence
            existing.retirementAge = profile.retirementAge
            existing.riskTolerance = profile.riskTolerance
            existing.dependents = profile.dependents
            existing.hasSpouse = profile.hasSpouse
            existing.spouseIncome = profile.spouseIncome
            existing.updatedAt = profile.updatedAt
        } else {
            modelContext.insert(profile)
        }
        try modelContext.save()
    }
}

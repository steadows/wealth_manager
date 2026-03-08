import Foundation

/// ViewModel for the goals list view.
@Observable
final class GoalsViewModel {

    // MARK: - Published State

    var goals: [FinancialGoal] = []
    var isLoading: Bool = false
    var error: Error?

    // MARK: - Dependencies

    private let goalRepo: GoalRepository

    // MARK: - Init

    init(goalRepo: GoalRepository) {
        self.goalRepo = goalRepo
    }

    // MARK: - Computed

    /// Active (non-completed) goals.
    var activeGoals: [FinancialGoal] {
        goals.filter { $0.isActive && $0.currentAmount < $0.targetAmount }
    }

    /// Completed goals (met target).
    var completedGoals: [FinancialGoal] {
        goals.filter { $0.currentAmount >= $0.targetAmount }
    }

    // MARK: - Actions

    /// Loads all goals from the repository.
    func loadGoals() async {
        isLoading = true
        error = nil

        do {
            goals = try await goalRepo.fetchAll()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    /// Adds a new goal.
    func addGoal(_ goal: FinancialGoal) async throws {
        try await goalRepo.create(goal)
        await loadGoals()
    }

    /// Deletes a goal.
    func deleteGoal(_ goal: FinancialGoal) async throws {
        try await goalRepo.delete(goal)
        await loadGoals()
    }
}

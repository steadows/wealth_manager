import SwiftUI

/// Content column displaying a scrollable list of financial goals.
struct GoalsListView: View {
    @Bindable var viewModel: GoalsViewModel
    @Binding var selectedGoal: FinancialGoal?
    @State private var showingAddGoal = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.activeGoals.isEmpty {
                emptyState
            } else {
                goalsList
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddGoal = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add Goal")
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            AddGoalView { newGoal in
                Task {
                    do {
                        try await viewModel.addGoal(newGoal)
                    } catch {
                        viewModel.error = error
                    }
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "An error occurred.")
        }
        .task {
            await viewModel.loadGoals()
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack {
            ProgressView()
                .controlSize(.large)
            Text("Loading goals...")
                .wmMuted()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "target",
            title: "No Goals Yet",
            description: "Set financial goals to track your progress toward retirement, savings, and more.",
            actionLabel: "Add Your First Goal"
        ) {
            showingAddGoal = true
        }
        .padding()
    }

    private var goalsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.activeGoals) { goal in
                    GoalRowView(goal: goal)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedGoal = goal
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    selectedGoal?.id == goal.id
                                        ? WMColors.primary.opacity(0.5)
                                        : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .contextMenu {
                            Button("Edit") {
                                selectedGoal = goal
                            }
                            Button("Delete", role: .destructive) {
                                Task {
                                    do {
                                        try await viewModel.deleteGoal(goal)
                                    } catch {
                                        viewModel.error = error
                                    }
                                }
                            }
                        }
                }

                if !viewModel.completedGoals.isEmpty {
                    completedSection
                }
            }
            .padding()
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completed")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textMuted)
                .padding(.top, 8)

            ForEach(viewModel.completedGoals) { goal in
                GoalRowView(goal: goal)
                    .opacity(0.7)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedGoal = goal
                    }
            }
        }
    }
}

// MARK: - Goal Row

/// A single goal row within the goals list.
private struct GoalRowView: View {
    let goal: FinancialGoal

    var body: some View {
        HStack(spacing: 14) {
            ProgressRing(
                progress: NSDecimalNumber(decimal: goal.progressPercent).doubleValue,
                size: 44,
                lineWidth: 4
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(goal.goalName)
                        .font(WMTypography.subheading)
                        .foregroundStyle(WMColors.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    trackingIndicator
                }

                HStack(spacing: 4) {
                    CurrencyText(
                        amount: goal.currentAmount,
                        font: WMTypography.body
                    )

                    Text("/")
                        .wmMuted()

                    CurrencyText(
                        amount: goal.targetAmount,
                        font: WMTypography.body
                    )
                }

                if let targetDate = goal.targetDate {
                    Text("Target: \(targetDate, format: .dateTime.month().year())")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                }
            }
        }
        .padding(14)
        .glassCard()
    }

    private var trackingIndicator: some View {
        Group {
            if goal.isOnTrack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(WMColors.positive)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.yellow)
            }
        }
        .font(.system(size: 16))
    }
}

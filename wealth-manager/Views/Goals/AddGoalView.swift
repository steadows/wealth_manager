import SwiftUI

/// Modal sheet for creating a new financial goal.
struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (FinancialGoal) -> Void

    // MARK: - Form State

    @State private var goalName: String = ""
    @State private var goalType: GoalType = GoalType.retirement
    @State private var targetAmountText: String = ""
    @State private var hasTargetDate: Bool = false
    @State private var targetDate: Date = Calendar.current.date(
        byAdding: .year, value: 1, to: Date()
    ) ?? Date()
    @State private var monthlyContributionText: String = ""
    @State private var priority: Int = 5
    @State private var notes: String = ""

    // MARK: - Validation

    private var isValid: Bool {
        !goalName.trimmingCharacters(in: .whitespaces).isEmpty
            && parsedTargetAmount > 0
    }

    private var parsedTargetAmount: Decimal {
        Decimal(string: targetAmountText) ?? 0
    }

    private var parsedMonthlyContribution: Decimal? {
        let text = monthlyContributionText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return Decimal(string: text)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(WMColors.glassBorder)
            formContent
            Divider().overlay(WMColors.glassBorder)
            footer
        }
        #if os(macOS)
        .frame(width: 480, height: 560)
        #endif
        .background(WMColors.backgroundStart)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Text("New Goal")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Spacer()
        }
        .padding()
    }

    private var formContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                goalTypeField
                goalNameField
                targetAmountField
                targetDateField
                monthlyContributionField
                priorityField
                notesField
            }
            .padding()
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(WMColors.textMuted)

            Spacer()

            GlassButton(label: "Save Goal", icon: "checkmark") {
                saveGoal()
            }
            .disabled(!isValid)
            .opacity(isValid ? 1.0 : 0.5)
        }
        .padding()
    }

    // MARK: - Form Fields

    private var goalTypeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Goal Type")
            Picker("Goal Type", selection: $goalType) {
                ForEach(GoalType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .labelsHidden()
        }
        .padding(12)
        .glassCard(cornerRadius: 10)
    }

    private var goalNameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Goal Name")
            TextField("e.g. Retirement Fund", text: $goalName)
                .textFieldStyle(.plain)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
        }
        .padding(12)
        .glassCard(cornerRadius: 10)
    }

    private var targetAmountField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Target Amount")
            HStack {
                Text("$")
                    .foregroundStyle(WMColors.textMuted)
                TextField("0.00", text: $targetAmountText)
                    .textFieldStyle(.plain)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 10)
    }

    private var targetDateField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                fieldLabel("Target Date")
                Spacer()
                Toggle("", isOn: $hasTargetDate)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            if hasTargetDate {
                DatePicker(
                    "Target Date",
                    selection: $targetDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .labelsHidden()
                #if os(macOS)
                .datePickerStyle(.field)
                #endif
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 10)
    }

    private var monthlyContributionField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Monthly Contribution (Optional)")
            HStack {
                Text("$")
                    .foregroundStyle(WMColors.textMuted)
                TextField("0.00", text: $monthlyContributionText)
                    .textFieldStyle(.plain)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 10)
    }

    private var priorityField: some View {
        HStack {
            fieldLabel("Priority")
            Spacer()
            Stepper("\(priority)", value: $priority, in: 1...10)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
        }
        .padding(12)
        .glassCard(cornerRadius: 10)
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("Notes (Optional)")
            TextEditor(text: $notes)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60, maxHeight: 100)
        }
        .padding(12)
        .glassCard(cornerRadius: 10)
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(WMTypography.caption)
            .foregroundStyle(WMColors.textMuted)
    }

    private func saveGoal() {
        let goal = FinancialGoal(
            goalName: goalName.trimmingCharacters(in: .whitespaces),
            goalType: goalType,
            targetAmount: parsedTargetAmount,
            targetDate: hasTargetDate ? targetDate : nil,
            monthlyContribution: parsedMonthlyContribution,
            priority: priority,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty
                ? nil
                : notes.trimmingCharacters(in: .whitespaces)
        )
        onSave(goal)
        dismiss()
    }
}

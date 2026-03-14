import SwiftUI

/// Detail column showing full information about a single financial goal.
struct GoalDetailView: View {
    let goal: FinancialGoal

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                progressSection
                amountsSection
                detailsSection
                notesSection
                aiSection
            }
            .padding()
        }
    }

    // MARK: - Sections

    private var progressSection: some View {
        VStack(spacing: 16) {
            ProgressRing(
                progress: NSDecimalNumber(decimal: goal.progressPercent).doubleValue,
                size: 120,
                lineWidth: 10
            )

            Text(goal.goalName)
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            HStack(spacing: 8) {
                typeBadge
                priorityBadge
                trackingBadge
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
    }

    private var amountsSection: some View {
        VStack(spacing: 12) {
            amountRow(label: "Current Amount", amount: goal.currentAmount)
            Divider().overlay(WMColors.glassBorder)
            amountRow(label: "Target Amount", amount: goal.targetAmount)
            Divider().overlay(WMColors.glassBorder)
            amountRow(label: "Remaining", amount: goal.remainingAmount)

            if let contribution = goal.monthlyContribution {
                Divider().overlay(WMColors.glassBorder)
                amountRow(label: "Monthly Contribution", amount: contribution)
            }
        }
        .padding(16)
        .glassCard()
    }

    private var detailsSection: some View {
        VStack(spacing: 12) {
            if let targetDate = goal.targetDate {
                detailRow(
                    label: "Target Date",
                    value: targetDate.formatted(.dateTime.month(.wide).year())
                )
            }

            detailRow(
                label: "Status",
                value: goal.isOnTrack ? "On Track" : "Needs Attention"
            )

            if !goal.isOnTrack {
                statusExplanation
            }
        }
        .padding(16)
        .glassCard()
    }

    @ViewBuilder
    private var notesSection: some View {
        if let notes = goal.notes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)

                Text(notes)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .glassCard()
        }
    }

    private var aiSection: some View {
        AIInsightCard(message: "Projection analysis coming in Sprint 3")
    }

    // MARK: - Components

    private var typeBadge: some View {
        GlassPill(text: goal.goalType.displayName)
    }

    private var priorityBadge: some View {
        GlassPill(text: "Priority \(goal.priority)")
    }

    private var trackingBadge: some View {
        HStack(spacing: 4) {
            if goal.isOnTrack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(WMColors.positive)
                    .accessibilityHidden(true)
                Text("On Track")
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.yellow)
                    .accessibilityHidden(true)
                Text("Off Track")
            }
        }
        .font(WMTypography.caption)
        .foregroundStyle(WMColors.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            goal.isOnTrack
                ? WMColors.positive.opacity(0.15)
                : Color.yellow.opacity(0.15)
        )
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Status: \(goal.isOnTrack ? "On Track" : "Off Track")")
    }

    private func amountRow(label: String, amount: Decimal) -> some View {
        HStack {
            Text(label)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
            Spacer()
            CurrencyText(amount: amount, font: WMTypography.subheading)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
            Spacer()
            Text(value)
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)
        }
    }

    private var statusExplanation: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.yellow)

            Text("At the current contribution rate, this goal may not be met by the target date. Consider increasing monthly contributions.")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
        }
        .padding(12)
        .background(Color.yellow.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

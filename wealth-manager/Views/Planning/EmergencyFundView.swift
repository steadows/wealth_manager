import SwiftUI

// MARK: - EmergencyFundView

/// Emergency fund tracker: progress ring toward 6-month target,
/// current vs target amounts, monthly contribution needed, and tips.
struct EmergencyFundView: View {

    let viewModel: InsuranceViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                progressRingCard
                monthlyContributionCard
                tipsSection
            }
            .padding()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Emergency Fund")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Text("Build a 6-month financial safety net")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Progress Ring Card

    private var progressRingCard: some View {
        let monthsCovered = NSDecimalNumber(decimal: viewModel.emergencyFundMonthsCovered).doubleValue
        let progress = min(monthsCovered / 6.0, 1.0)
        let ringColor = progressColor(months: monthsCovered)

        return VStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(WMColors.glassBg, lineWidth: 12)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [ringColor, ringColor.opacity(0.6)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress)

                VStack(spacing: 2) {
                    Text(String(format: "%.1f", monthsCovered))
                        .font(WMTypography.heading)
                        .foregroundStyle(WMColors.textPrimary)
                    Text("months")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                }
            }

            Text("Target: 6 months")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)

            if viewModel.emergencyFundShortfall > 0 {
                Text("Shortfall: \(formatCurrency(viewModel.emergencyFundShortfall))")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.negative)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(WMColors.positive)
                    Text("Goal reached!")
                        .font(WMTypography.subheading)
                        .foregroundStyle(WMColors.positive)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard()
    }

    // MARK: - Monthly Contribution Card

    @ViewBuilder
    private var monthlyContributionCard: some View {
        if viewModel.emergencyFundShortfall > 0 {
            let monthlyNeeded = viewModel.emergencyFundShortfall / 12

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundStyle(WMColors.secondary)
                    Text("12-Month Plan")
                        .font(WMTypography.subheading)
                        .foregroundStyle(WMColors.textPrimary)
                }

                HStack {
                    Text("Monthly contribution needed")
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.textMuted)
                    Spacer()
                    Text(formatCurrency(monthlyNeeded))
                        .font(WMTypography.subheading)
                        .foregroundStyle(WMColors.secondary)
                }

                Text("to reach your 6-month emergency fund goal in 12 months")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
            }
            .padding(16)
            .glassCard()
        }
    }

    // MARK: - Tips Section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Building Your Fund")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            ForEach(tips, id: \.title) { tip in
                tipCard(icon: tip.icon, title: tip.title, body: tip.body)
            }
        }
    }

    private func tipCard(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(WMColors.tertiary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
                Text(body)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Data

    private let tips: [(icon: String, title: String, body: String)] = [
        (
            icon: "building.columns.fill",
            title: "Use a High-Yield Savings Account",
            body: "Park your emergency fund in an HYSA to earn 4-5% interest while keeping it liquid."
        ),
        (
            icon: "arrow.clockwise",
            title: "Automate Contributions",
            body: "Set up automatic transfers on payday so saving happens before spending."
        ),
        (
            icon: "arrow.down.circle.fill",
            title: "Direct Windfalls Here First",
            body: "Tax refunds, bonuses, and gifts can rapidly accelerate your emergency fund."
        ),
        (
            icon: "lock.shield.fill",
            title: "Keep It Separate",
            body: "A dedicated account prevents accidental spending and makes the fund feel real."
        ),
    ]

    // MARK: - Helpers

    private func progressColor(months: Double) -> Color {
        if months >= 6 { return WMColors.positive }
        if months >= 3 { return WMColors.glow }
        return WMColors.negative
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

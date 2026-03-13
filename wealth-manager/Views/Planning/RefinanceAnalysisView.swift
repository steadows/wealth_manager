import SwiftUI

// MARK: - RefinanceAnalysisView

/// Refinance calculator: enter current loan details and proposed refinance terms;
/// see break-even months, monthly savings, and visual timeline.
struct RefinanceAnalysisView: View {

    // MARK: - Local State

    @State private var currentBalance: String = ""
    @State private var currentRatePercent: String = ""
    @State private var newRatePercent: String = ""
    @State private var closingCosts: String = ""
    @State private var remainingMonths: String = "360"

    // Computed result
    @State private var result: RefinanceResult = .notCalculated

    private enum RefinanceResult {
        case notCalculated
        case neverworthit
        case breakeven(months: Int, monthlySavings: Decimal)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                inputSection
                resultSection
                timelineSection
            }
            .padding()
        }
        .onChange(of: currentBalance) { _, _ in recalculate() }
        .onChange(of: currentRatePercent) { _, _ in recalculate() }
        .onChange(of: newRatePercent) { _, _ in recalculate() }
        .onChange(of: closingCosts) { _, _ in recalculate() }
        .onChange(of: remainingMonths) { _, _ in recalculate() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Refinance Analysis")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            Text("Calculate how long until refinancing savings exceed closing costs")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Loan Details")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            inputField(label: "Current Balance", placeholder: "250,000", value: $currentBalance, prefix: "$")
            inputField(label: "Current Rate", placeholder: "6.5", value: $currentRatePercent, suffix: "%")
            inputField(label: "New Rate", placeholder: "5.5", value: $newRatePercent, suffix: "%")
            inputField(label: "Closing Costs", placeholder: "5,000", value: $closingCosts, prefix: "$")
            inputField(label: "Months Remaining", placeholder: "360", value: $remainingMonths)
        }
        .padding(16)
        .glassCard()
    }

    private func inputField(
        label: String,
        placeholder: String,
        value: Binding<String>,
        prefix: String? = nil,
        suffix: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)

            HStack(spacing: 4) {
                if let prefix {
                    Text(prefix)
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.textMuted)
                }
                TextField(placeholder, text: value)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
                    .textFieldStyle(.plain)
                if let suffix {
                    Text(suffix)
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.textMuted)
                }
            }
            .padding(10)
            .background(WMColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(WMColors.glassBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Result Section

    @ViewBuilder
    private var resultSection: some View {
        switch result {
        case .notCalculated:
            resultPlaceholder

        case .neverworthit:
            notWorthItCard

        case .breakeven(let months, let savings):
            breakevenCard(months: months, monthlySavings: savings)
        }
    }

    private var resultPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 32))
                .foregroundStyle(WMColors.textMuted)
            Text("Enter loan details to see break-even analysis")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard()
    }

    private var notWorthItCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(WMColors.negative)

            Text("Not Worth It")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.negative)

            Text("Refinancing never breaks even within the remaining loan term. "
                 + "The new rate is too close to the current rate, or closing costs are too high.")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(WMColors.negative.opacity(0.3), lineWidth: 1)
        )
    }

    private func breakevenCard(months: Int, monthlySavings: Decimal) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                metricBlock(
                    label: "Break-Even",
                    value: monthsLabel(months),
                    color: WMColors.primary
                )
                Divider()
                    .frame(height: 48)
                    .background(WMColors.glassBorder)
                metricBlock(
                    label: "Monthly Savings",
                    value: formatCurrency(monthlySavings),
                    color: WMColors.positive
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(WMColors.positive.opacity(0.3), lineWidth: 1)
        )
    }

    private func metricBlock(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(WMTypography.heroNumber)
                .foregroundStyle(color)
            Text(label)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Timeline Section

    @ViewBuilder
    private var timelineSection: some View {
        if case .breakeven(let months, _) = result {
            let remaining = Int(remainingMonths) ?? 360
            let progress = min(Double(months) / Double(max(remaining, 1)), 1.0)

            VStack(alignment: .leading, spacing: 12) {
                Text("Break-Even Timeline")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(WMColors.glassBg)
                            .frame(height: 12)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [WMColors.primary, WMColors.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress, height: 12)
                    }
                }
                .frame(height: 12)

                HStack {
                    Text("Now")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                    Spacer()
                    Text("Break-even: \(monthsLabel(months))")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.primary)
                    Spacer()
                    Text("\(monthsLabel(remaining)) remaining")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    // MARK: - Calculation

    private func recalculate() {
        guard
            let balance = parseDecimal(currentBalance),
            let currentRate = parsePercent(currentRatePercent),
            let newRate = parsePercent(newRatePercent),
            let costs = parseDecimal(closingCosts),
            let months = Int(remainingMonths),
            balance > 0,
            costs > 0
        else {
            result = .notCalculated
            return
        }

        if let breakevenMonths = DebtCalculator.refinanceBreakeven(
            currentBalance: balance,
            currentRate: currentRate,
            newRate: newRate,
            closingCosts: costs,
            remainingMonths: months
        ) {
            let currentMonthlyInterest = balance * currentRate / 12
            let newMonthlyInterest = balance * newRate / 12
            let savings = currentMonthlyInterest - newMonthlyInterest
            result = .breakeven(months: breakevenMonths, monthlySavings: savings)
        } else {
            result = .neverworthit
        }
    }

    // MARK: - Helpers

    private func parseDecimal(_ text: String) -> Decimal? {
        let cleaned = text.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned)
    }

    private func parsePercent(_ text: String) -> Decimal? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
        guard let value = Decimal(string: cleaned) else { return nil }
        return value / 100
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }

    private func monthsLabel(_ months: Int) -> String {
        let years = months / 12
        let rem = months % 12
        if years == 0 { return "\(rem)mo" }
        if rem == 0 { return "\(years)yr" }
        return "\(years)yr \(rem)mo"
    }
}

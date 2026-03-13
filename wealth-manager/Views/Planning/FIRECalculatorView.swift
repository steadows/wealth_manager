import SwiftUI

// MARK: - FIRECalculatorView

/// Interactive FIRE (Financial Independence, Retire Early) calculator.
/// Users adjust sliders to see live-updated FIRE number and timeline.
struct FIRECalculatorView: View {

    // MARK: - State

    @State private var currentPortfolio: Double = 250_000
    @State private var annualExpenses: Double = 60_000
    @State private var annualContribution: Double = 30_000
    @State private var expectedReturn: Double = 7.0

    // MARK: - Computed

    private var fireNumber: Decimal {
        RetirementCalculator.fireNumber(
            annualExpenses: Decimal(annualExpenses),
            withdrawalRate: Decimal(string: "0.04")!
        )
    }

    private var yearsToFIRE: Int? {
        RetirementCalculator.yearsToFIRE(
            currentPortfolio: Decimal(currentPortfolio),
            annualContribution: Decimal(annualContribution),
            annualExpenses: Decimal(annualExpenses),
            expectedReturn: Decimal(expectedReturn / 100)
        )
    }

    private var progressToFIRE: Double {
        guard fireNumber > 0 else { return 0 }
        let ratio = currentPortfolio / NSDecimalNumber(decimal: fireNumber).doubleValue
        return min(ratio, 1.0)
    }

    private var savingsRate: Double {
        let income = annualContribution + annualExpenses
        guard income > 0 else { return 0 }
        return (annualContribution / income) * 100
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                resultsCard
                progressCard
                inputsCard
                savingsRateCard
            }
            .padding()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FIRE Calculator")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Text("Adjust the inputs to model your path to financial independence")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Results Card

    private var resultsCard: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("FIRE Number")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                Text(formatCurrency(fireNumber))
                    .font(WMTypography.heroNumber)
                    .foregroundStyle(WMColors.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            Divider()
                .background(WMColors.glassBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Years to FIRE")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                if let years = yearsToFIRE {
                    Text("\(years)")
                        .font(WMTypography.heroNumber)
                        .foregroundStyle(WMColors.primary)
                    Text("years")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                } else {
                    Text("Already FI")
                        .font(WMTypography.subheading)
                        .foregroundStyle(WMColors.positive)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress to FIRE")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)
                Spacer()
                Text("\(Int(progressToFIRE * 100))%")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(WMColors.glassBorder)
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [WMColors.primary, WMColors.secondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progressToFIRE, height: 12)
                        .animation(.easeInOut(duration: 0.5), value: progressToFIRE)
                }
            }
            .frame(height: 12)

            HStack {
                Text(formatCurrency(Decimal(currentPortfolio)))
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                Spacer()
                Text(formatCurrency(fireNumber))
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Inputs Card

    private var inputsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Assumptions")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            inputSlider(
                label: "Current Portfolio",
                value: $currentPortfolio,
                range: 0...5_000_000,
                step: 10_000,
                format: { formatCurrency(Decimal($0)) }
            )

            inputSlider(
                label: "Annual Expenses",
                value: $annualExpenses,
                range: 20_000...300_000,
                step: 1_000,
                format: { formatCurrency(Decimal($0)) }
            )

            inputSlider(
                label: "Annual Contribution",
                value: $annualContribution,
                range: 0...200_000,
                step: 1_000,
                format: { formatCurrency(Decimal($0)) }
            )

            inputSlider(
                label: "Expected Return",
                value: $expectedReturn,
                range: 1...15,
                step: 0.5,
                format: { String(format: "%.1f%%", $0) }
            )
        }
        .padding(20)
        .glassCard()
    }

    private func inputSlider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
                Spacer()
                Text(format(value.wrappedValue))
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.primary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
                .tint(WMColors.primary)
        }
    }

    // MARK: - Savings Rate Card

    private var savingsRateCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Savings Rate")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                Text(String(format: "%.0f%%", savingsRate))
                    .font(WMTypography.subheading)
                    .foregroundStyle(savingsRate >= 50 ? WMColors.positive : WMColors.primary)
            }

            Spacer()

            Text(savingsRateLabel)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
                .multilineTextAlignment(.trailing)
        }
        .padding(16)
        .glassCard()
    }

    private var savingsRateLabel: String {
        switch savingsRate {
        case 70...: return "Extreme FIRE track"
        case 50..<70: return "Strong FIRE track"
        case 25..<50: return "Moderate savings"
        default: return "Increase savings rate\nto accelerate FIRE"
        }
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

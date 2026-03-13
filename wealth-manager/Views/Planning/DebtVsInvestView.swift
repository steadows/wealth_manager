import SwiftUI

// MARK: - DebtVsInvestView

/// Compares the net benefit of paying off debt versus investing the same amount.
struct DebtVsInvestView: View {

    // MARK: - Local State

    @State private var debtBalance: String = ""
    @State private var debtRatePercent: String = ""
    @State private var investReturnPercent: String = "7"
    @State private var monthlyAmount: String = ""
    @State private var years: String = "10"

    @State private var comparison: ComparisonResult = .notCalculated

    private struct ComparisonResult {
        var payDebtBenefit: Decimal = 0
        var investBenefit: Decimal = 0
        var recommendation: String = ""

        static let notCalculated = ComparisonResult()

        var isCalculated: Bool { payDebtBenefit > 0 || investBenefit > 0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                inputSection
                if comparison.isCalculated {
                    comparisonCards
                    recommendationBanner
                }
            }
            .padding()
        }
        .onChange(of: debtBalance) { _, _ in recalculate() }
        .onChange(of: debtRatePercent) { _, _ in recalculate() }
        .onChange(of: investReturnPercent) { _, _ in recalculate() }
        .onChange(of: monthlyAmount) { _, _ in recalculate() }
        .onChange(of: years) { _, _ in recalculate() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Debt vs Invest")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            Text("Should you pay off debt or invest? See the numbers.")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Parameters")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            inputField(label: "Debt Balance", placeholder: "10,000", value: $debtBalance, prefix: "$")
            inputField(label: "Debt Interest Rate", placeholder: "18.9", value: $debtRatePercent, suffix: "%")
            inputField(label: "Expected Investment Return", placeholder: "7", value: $investReturnPercent, suffix: "%")
            inputField(label: "Monthly Amount", placeholder: "500", value: $monthlyAmount, prefix: "$")
            inputField(label: "Time Horizon (years)", placeholder: "10", value: $years)
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

    // MARK: - Comparison Cards

    private var comparisonCards: some View {
        HStack(spacing: 12) {
            benefitCard(
                title: "Pay Debt",
                icon: "creditcard.fill",
                color: WMColors.tertiary,
                benefit: comparison.payDebtBenefit,
                description: "Interest saved"
            )

            benefitCard(
                title: "Invest",
                icon: "chart.line.uptrend.xyaxis",
                color: WMColors.primary,
                benefit: comparison.investBenefit,
                description: "Investment gain"
            )
        }
    }

    private func benefitCard(
        title: String,
        icon: String,
        color: Color,
        benefit: Decimal,
        description: String
    ) -> some View {
        let isWinner = benefit >= (title == "Pay Debt" ? comparison.investBenefit : comparison.payDebtBenefit)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)
                if isWinner {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(WMColors.positive)
                        .font(.system(size: 14))
                }
            }

            Text(formatCurrency(benefit))
                .font(WMTypography.heroNumber)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(description)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isWinner ? color.opacity(0.4) : WMColors.glassBorder, lineWidth: isWinner ? 1.5 : 1)
        )
    }

    // MARK: - Recommendation Banner

    private var recommendationBanner: some View {
        let isPayDebt = comparison.payDebtBenefit >= comparison.investBenefit
        let bannerColor = isPayDebt ? WMColors.tertiary : WMColors.primary

        return HStack(spacing: 12) {
            Image(systemName: isPayDebt ? "creditcard.fill" : "chart.line.uptrend.xyaxis")
                .foregroundStyle(bannerColor)
                .font(.system(size: 20))

            Text(comparison.recommendation)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(bannerColor.opacity(0.35), lineWidth: 1.5)
        )
    }

    // MARK: - Calculation

    private func recalculate() {
        guard
            let balance = parseDecimal(debtBalance),
            let debtRate = parsePercent(debtRatePercent),
            let investReturn = parsePercent(investReturnPercent),
            let monthly = parseDecimal(monthlyAmount),
            let yearCount = Int(years),
            balance > 0,
            monthly > 0,
            yearCount > 0
        else {
            comparison = .notCalculated
            return
        }

        let result = DebtCalculator.debtVsInvest(
            debtBalance: balance,
            debtRate: debtRate,
            investmentReturn: investReturn,
            monthlyAmount: monthly,
            years: yearCount
        )
        comparison = ComparisonResult(
            payDebtBenefit: result.payDebtBenefit,
            investBenefit: result.investBenefit,
            recommendation: result.recommendation
        )
    }

    // MARK: - Helpers

    private func parseDecimal(_ text: String) -> Decimal? {
        let cleaned = text.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned)
    }

    private func parsePercent(_ text: String) -> Decimal? {
        guard let value = Decimal(string: text.trimmingCharacters(in: .whitespaces)) else { return nil }
        return value / 100
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

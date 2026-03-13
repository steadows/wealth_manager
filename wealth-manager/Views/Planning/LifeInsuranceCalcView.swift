import SwiftUI

// MARK: - LifeInsuranceCalcView

/// DIME method life insurance calculator: enter debt, income, mortgage, and
/// education costs; see a live breakdown of total need vs existing coverage.
struct LifeInsuranceCalcView: View {

    // MARK: - Local State

    @State private var totalDebt: String = ""
    @State private var annualIncome: String = ""
    @State private var yearsToReplace: String = "10"
    @State private var mortgageBalance: String = ""
    @State private var educationCosts: String = ""
    @State private var existingCoverage: String = ""

    @State private var result: InsuranceResult = InsuranceResult()

    private struct InsuranceResult {
        var totalNeed: Decimal = 0
        var gap: Decimal = 0
        var debtComponent: Decimal = 0
        var incomeComponent: Decimal = 0
        var mortgageComponent: Decimal = 0
        var educationComponent: Decimal = 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                dimeExplanation
                inputSection
                if result.totalNeed > 0 {
                    breakdownSection
                    summarySection
                }
            }
            .padding()
        }
        .onChange(of: totalDebt) { _, _ in recalculate() }
        .onChange(of: annualIncome) { _, _ in recalculate() }
        .onChange(of: yearsToReplace) { _, _ in recalculate() }
        .onChange(of: mortgageBalance) { _, _ in recalculate() }
        .onChange(of: educationCosts) { _, _ in recalculate() }
        .onChange(of: existingCoverage) { _, _ in recalculate() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Life Insurance Calculator")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Text("DIME method: Debt + Income + Mortgage + Education")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - DIME Explanation

    private var dimeExplanation: some View {
        HStack(spacing: 0) {
            ForEach(["D\nDebt", "I\nIncome", "M\nMortgage", "E\nEducation"], id: \.self) { label in
                let parts = label.components(separatedBy: "\n")
                VStack(spacing: 4) {
                    Text(parts[0])
                        .font(WMTypography.heading)
                        .foregroundStyle(WMColors.primary)
                    Text(parts[1])
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                }
                .frame(maxWidth: .infinity)
                if label != "E\nEducation" {
                    Text("+")
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.textMuted)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Input Section

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Numbers")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            inputField(label: "Total Debt (D)", placeholder: "20,000", value: $totalDebt, prefix: "$")
            inputField(label: "Annual Income (I)", placeholder: "80,000", value: $annualIncome, prefix: "$")
            inputField(label: "Years Income Replacement", placeholder: "10", value: $yearsToReplace)
            inputField(label: "Mortgage Balance (M)", placeholder: "250,000", value: $mortgageBalance, prefix: "$")
            inputField(label: "Education Costs (E)", placeholder: "100,000", value: $educationCosts, prefix: "$")
            inputField(label: "Existing Coverage", placeholder: "0", value: $existingCoverage, prefix: "$")
        }
        .padding(16)
        .glassCard()
    }

    private func inputField(
        label: String,
        placeholder: String,
        value: Binding<String>,
        prefix: String? = nil
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

    // MARK: - Breakdown Section

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DIME Breakdown")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            dimeRow(letter: "D", label: "Debt", amount: result.debtComponent)
            dimeRow(letter: "I", label: "Income Replacement", amount: result.incomeComponent)
            dimeRow(letter: "M", label: "Mortgage", amount: result.mortgageComponent)
            dimeRow(letter: "E", label: "Education", amount: result.educationComponent)

            Divider()
                .background(WMColors.glassBorder)

            HStack {
                Text("Total Need")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)
                Spacer()
                Text(formatCurrency(result.totalNeed))
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)
            }
        }
        .padding(16)
        .glassCard()
    }

    private func dimeRow(letter: String, label: String, amount: Decimal) -> some View {
        HStack {
            Text(letter)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.primary)
                .frame(width: 20)
            Text(label)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
            Spacer()
            Text(formatCurrency(amount))
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
        }
    }

    // MARK: - Summary Section

    private var summarySection: some View {
        let hasGap = result.gap > 0
        let gapColor = hasGap ? WMColors.negative : WMColors.positive

        return VStack(spacing: 12) {
            Text(hasGap ? formatCurrency(result.gap) : "Fully Covered")
                .font(WMTypography.heroNumber)
                .foregroundStyle(gapColor)

            Text(hasGap ? "Coverage Gap" : "No Gap")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)

            if hasGap {
                Text("Consider a term life insurance policy to close this gap.")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(gapColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Calculation

    private func recalculate() {
        let debt = parseDecimal(totalDebt) ?? 0
        let income = parseDecimal(annualIncome) ?? 0
        let years = Int(yearsToReplace) ?? 0
        let mortgage = parseDecimal(mortgageBalance) ?? 0
        let education = parseDecimal(educationCosts) ?? 0
        let existing = parseDecimal(existingCoverage) ?? 0

        guard income > 0 || debt > 0 || mortgage > 0 else {
            result = InsuranceResult()
            return
        }

        let calculated = InsuranceCalculator.lifeInsuranceNeed(
            totalDebt: debt,
            annualIncome: income,
            yearsToReplace: years,
            mortgageBalance: mortgage,
            educationCosts: education,
            existingCoverage: existing
        )

        result = InsuranceResult(
            totalNeed: calculated.totalNeed,
            gap: calculated.gap,
            debtComponent: debt,
            incomeComponent: income * Decimal(max(years, 0)),
            mortgageComponent: mortgage,
            educationComponent: education
        )
    }

    // MARK: - Helpers

    private func parseDecimal(_ text: String) -> Decimal? {
        let cleaned = text.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
        return Decimal(string: cleaned)
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

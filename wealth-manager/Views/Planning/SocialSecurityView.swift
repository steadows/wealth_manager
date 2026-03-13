import SwiftUI

// MARK: - SocialSecurityView

/// Social Security claiming strategy view. Shows estimated benefits for each
/// claiming age (62–70) and break-even analysis for delay strategies.
struct SocialSecurityView: View {

    // MARK: - State

    @State private var fraMonthlyBenefit: Double = 2_500
    @State private var selectedAge: Int = 67

    // MARK: - Computed

    private var estimates: [Int: Decimal] {
        var result: [Int: Decimal] = [:]
        for age in 62...70 {
            result[age] = RetirementCalculator.socialSecurityEstimate(
                fullRetirementBenefit: Decimal(fraMonthlyBenefit),
                claimingAge: age
            )
        }
        return result
    }

    private var maxBenefit: Decimal {
        estimates.values.max() ?? 1
    }

    private var breakeven: (delayTo67Breakeven: Int, delayTo70Breakeven: Int) {
        let benefit62 = estimates[62] ?? 0
        let benefit67 = estimates[67] ?? 0
        let benefit70 = estimates[70] ?? 0
        return RetirementCalculator.socialSecurityBreakeven(
            age62Benefit: benefit62,
            age67Benefit: benefit67,
            age70Benefit: benefit70
        )
    }

    private var selectedBenefit: Decimal {
        estimates[selectedAge] ?? 0
    }

    private var selectedAnnualBenefit: Decimal {
        selectedBenefit * 12
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                inputCard
                benefitChartCard
                selectedAgeCard
                breakevenCard
                recommendationCard
            }
            .padding()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Social Security")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Text("Optimize your claiming strategy")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Input Card

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimated FRA Monthly Benefit")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            HStack {
                Text("Full Retirement Age (67) Benefit")
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textMuted)
                Spacer()
                Text(formatCurrency(Decimal(fraMonthlyBenefit)) + "/mo")
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.primary)
                    .monospacedDigit()
            }

            Slider(value: $fraMonthlyBenefit, in: 500...4_000, step: 50)
                .tint(WMColors.primary)

            Text("Find your estimated benefit at ssa.gov/myaccount")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Benefit Chart Card

    private var benefitChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Monthly Benefit by Claiming Age")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(62...70, id: \.self) { age in
                    benefitBar(age: age)
                }
            }
            .frame(height: 140)

            HStack {
                Text("Claim Early (62)")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                Spacer()
                Text("Max Delay (70)")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
            }
        }
        .padding(20)
        .glassCard()
    }

    private func benefitBar(age: Int) -> some View {
        let benefit = estimates[age] ?? 0
        let maxDouble = NSDecimalNumber(decimal: maxBenefit).doubleValue
        let benefitDouble = NSDecimalNumber(decimal: benefit).doubleValue
        let heightRatio = maxDouble > 0 ? benefitDouble / maxDouble : 0
        let isSelected = age == selectedAge

        return VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    isSelected
                        ? LinearGradient(
                            colors: [WMColors.primary, WMColors.secondary],
                            startPoint: .bottom,
                            endPoint: .top
                          )
                        : LinearGradient(
                            colors: [WMColors.glassBorder, WMColors.glassBorder],
                            startPoint: .bottom,
                            endPoint: .top
                          )
                )
                .frame(height: max(CGFloat(heightRatio) * 120, 4))
                .overlay(
                    isSelected
                        ? RoundedRectangle(cornerRadius: 4)
                            .stroke(WMColors.glow, lineWidth: 1)
                        : nil
                )

            Text("\(age)")
                .font(WMTypography.caption)
                .foregroundStyle(isSelected ? WMColors.primary : WMColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { selectedAge = age }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    // MARK: - Selected Age Card

    private var selectedAgeCard: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Age \(selectedAge)")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                Text(formatCurrency(selectedBenefit) + "/mo")
                    .font(WMTypography.heroNumber)
                    .foregroundStyle(WMColors.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            Divider().background(WMColors.glassBorder)

            VStack(alignment: .leading, spacing: 4) {
                Text("Annual Total")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                Text(formatCurrency(selectedAnnualBenefit))
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.primary)

                let pctOfFRA = fraMonthlyBenefit > 0
                    ? NSDecimalNumber(decimal: selectedBenefit).doubleValue / fraMonthlyBenefit * 100
                    : 100.0
                Text(String(format: "%.0f%% of FRA benefit", pctOfFRA))
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    // MARK: - Break-even Card

    private var breakevenCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Break-even Analysis")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            breakevenRow(
                label: "Delay 62 → 67",
                breakevenAge: breakeven.delayTo67Breakeven,
                description: "You break even by collecting more from age 67 at age \(breakeven.delayTo67Breakeven)"
            )

            Divider().background(WMColors.glassBorder)

            breakevenRow(
                label: "Delay 62 → 70",
                breakevenAge: breakeven.delayTo70Breakeven,
                description: "Maximum delay pays off if you live past age \(breakeven.delayTo70Breakeven)"
            )
        }
        .padding(20)
        .glassCard()
    }

    private func breakevenRow(label: String, breakevenAge: Int, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
                Text(description)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Age \(breakevenAge)")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.secondary)
            }
        }
    }

    // MARK: - Recommendation Card

    private var recommendationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(WMColors.primary)
                Text("Claiming Strategy Insight")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)
            }

            Text(recommendationText)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassCard()
    }

    private var recommendationText: String {
        let benefit62 = NSDecimalNumber(decimal: estimates[62] ?? 0).doubleValue
        let benefit70 = NSDecimalNumber(decimal: estimates[70] ?? 0).doubleValue
        let lifetimeGainFrom70 = (benefit70 - benefit62) * 12
        let formattedGain = formatCurrency(Decimal(lifetimeGainFrom70))

        return "Delaying from age 62 to 70 increases your monthly benefit by \(formattedGain)/year. " +
               "If you expect to live past age \(breakeven.delayTo70Breakeven), delaying to 70 maximizes lifetime benefits. " +
               "Consider your health, other income sources, and spousal benefits when choosing a strategy."
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

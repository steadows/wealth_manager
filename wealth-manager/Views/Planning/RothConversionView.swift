import SwiftUI

/// Roth conversion analyzer — shows conversion opportunity within current bracket,
/// tax cost vs projected savings, and backdoor Roth eligibility indicator.
struct RothConversionView: View {
    @State private var viewModel: TaxViewModel?

    private let accountRepo: any AccountRepository
    private let profileRepo: any UserProfileRepository
    private let holdingRepo: any InvestmentHoldingRepository

    init(
        accountRepo: any AccountRepository,
        profileRepo: any UserProfileRepository,
        holdingRepo: any InvestmentHoldingRepository
    ) {
        self.accountRepo = accountRepo
        self.profileRepo = profileRepo
        self.holdingRepo = holdingRepo
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                loadedBody(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            let vm = TaxViewModel(
                accountRepo: accountRepo,
                profileRepo: profileRepo,
                holdingRepo: holdingRepo
            )
            viewModel = vm
            await vm.loadTaxData()
        }
    }

    // MARK: - Loaded Body

    @ViewBuilder
    private func loadedBody(vm: TaxViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                conversionOpportunityCard(vm: vm)
                analysisCard(vm: vm)
                insightCard(vm: vm)
            }
            .padding()
        }
        .background(WMColors.background)
        .navigationTitle("Roth Conversion")
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Roth Conversion Analyzer")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Text("Convert traditional IRA funds to Roth while minimizing taxes")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Conversion Opportunity Card

    @ViewBuilder
    private func conversionOpportunityCard(vm: TaxViewModel) -> some View {
        if let opp = vm.rothConversionOpportunity {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 20))
                        .foregroundStyle(WMColors.primary)
                    Text("Conversion Opportunity")
                        .font(WMTypography.subheading)
                        .foregroundStyle(WMColors.textPrimary)
                }

                HStack(spacing: 0) {
                    opportunityMetric(
                        label: "Suggested Amount",
                        value: opp.suggestedConversionAmount,
                        color: opp.suggestedConversionAmount > 0 ? WMColors.primary : WMColors.textMuted
                    )
                    Divider()
                        .background(WMColors.glassBorder)
                        .frame(height: 40)
                    rateMetric(
                        label: "Marginal Rate",
                        rate: opp.marginalRate
                    )
                }

                Text(opp.reason)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .glassCard()
        } else {
            noDataCard(
                icon: "arrow.triangle.2.circlepath",
                message: "Load your profile to see Roth conversion opportunities."
            )
        }
    }

    // MARK: - Analysis Card

    @ViewBuilder
    private func analysisCard(vm: TaxViewModel) -> some View {
        if let opp = vm.rothConversionOpportunity, opp.suggestedConversionAmount > 0 {
            // Estimate tax cost and retirement savings for the suggested amount
            let taxCostResult = TaxCalculator.rothConversionAnalysis(
                conversionAmount: opp.suggestedConversionAmount,
                currentTaxableIncome: vm.estimatedAnnualTax / max(vm.effectiveTaxRate, Decimal(string: "0.01")!),
                filingStatus: .single,
                yearsToRetirement: 20,
                expectedRetirementTaxRate: Decimal(string: "0.22")!
            )

            VStack(alignment: .leading, spacing: 14) {
                Text("Conversion Trade-Off")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)

                HStack(spacing: 0) {
                    tradeOffMetric(
                        label: "Tax Cost Now",
                        amount: taxCostResult.taxCostNow,
                        color: WMColors.negative
                    )
                    Divider()
                        .background(WMColors.glassBorder)
                        .frame(height: 40)
                    tradeOffMetric(
                        label: "Projected Savings",
                        amount: taxCostResult.projectedTaxSavings,
                        color: WMColors.positive
                    )
                    Divider()
                        .background(WMColors.glassBorder)
                        .frame(height: 40)
                    tradeOffMetric(
                        label: "Net Benefit",
                        amount: taxCostResult.netBenefit,
                        color: taxCostResult.netBenefit >= 0 ? WMColors.positive : WMColors.negative
                    )
                }
            }
            .padding(16)
            .glassCard()
        }
    }

    // MARK: - Insight Card

    private func insightCard(vm: TaxViewModel) -> some View {
        AIInsightCard(message: buildInsight(vm: vm))
    }

    // MARK: - Helpers

    private func opportunityMetric(label: String, value: Decimal, color: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            CurrencyText(amount: value, font: WMTypography.subheading)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func rateMetric(label: String, rate: Decimal) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            Text(percentString(rate))
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func tradeOffMetric(label: String, amount: Decimal, color: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
                .multilineTextAlignment(.center)
            CurrencyText(amount: amount, font: WMTypography.body)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private func noDataCard(icon: String, message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(WMColors.textMuted)
            Text(message)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .padding(16)
        .glassCard()
    }

    private func percentString(_ decimal: Decimal) -> String {
        let pct = NSDecimalNumber(decimal: decimal * 100).doubleValue
        return String(format: "%.0f%%", pct)
    }

    private func buildInsight(vm: TaxViewModel) -> String {
        guard let opp = vm.rothConversionOpportunity else {
            return "Add your financial profile to unlock personalized Roth conversion analysis."
        }
        if opp.suggestedConversionAmount > 0 {
            return "Converting now while in a lower bracket can generate significant tax-free growth. "
                + "Consider converting the suggested amount each year to gradually fill up lower brackets."
        }
        return opp.reason
    }
}

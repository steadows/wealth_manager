import SwiftUI

/// Tax Intelligence hub — shows estimated tax liability, rates,
/// standard deduction, and navigation links to detailed tax tools.
struct TaxDashboardView: View {
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
                heroCard(vm: vm)
                ratesRow(vm: vm)
                deductionCard(vm: vm)
                toolsGrid(vm: vm)
                aiInsightCard(vm: vm)
            }
            .padding()
        }
        .background(WMColors.background)
        .overlay {
            if vm.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tax Intelligence")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Text("Federal tax estimates and optimization strategies for 2025")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero Card

    private func heroCard(vm: TaxViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(WMColors.secondary)
                Text("Estimated Annual Tax")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textMuted)
            }

            CurrencyText(
                amount: vm.estimatedAnnualTax,
                font: WMTypography.heroNumber
            )

            Text("Federal income tax estimate based on your profile income")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
    }

    // MARK: - Rates Row

    private func ratesRow(vm: TaxViewModel) -> some View {
        HStack(spacing: 16) {
            rateCard(
                label: "Effective Rate",
                rate: vm.effectiveTaxRate,
                color: WMColors.primary
            )
            rateCard(
                label: "Marginal Rate",
                rate: vm.marginalTaxRate,
                color: WMColors.secondary
            )
        }
    }

    private func rateCard(label: String, rate: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)

            Text(percentString(rate))
                .font(WMTypography.subheading)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    // MARK: - Deduction Card

    private func deductionCard(vm: TaxViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Standard Deduction")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)
                Text("Applied to your estimated tax calculation")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
            }
            Spacer()
            CurrencyText(amount: vm.standardDeduction, font: WMTypography.subheading)
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Tools Grid

    private func toolsGrid(vm: TaxViewModel) -> some View {
        VStack(spacing: 12) {
            Text("Tax Optimization Tools")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            NavigationLink {
                HarvestingOppsView(
                    accountRepo: accountRepo,
                    profileRepo: profileRepo,
                    holdingRepo: holdingRepo
                )
            } label: {
                toolRow(
                    icon: "arrow.down.left.circle.fill",
                    title: "Tax-Loss Harvesting",
                    subtitle: "\(vm.harvestingOpportunities.count) opportunities found",
                    color: WMColors.tertiary
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                RothConversionView(
                    accountRepo: accountRepo,
                    profileRepo: profileRepo,
                    holdingRepo: holdingRepo
                )
            } label: {
                toolRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Roth Conversion Analyzer",
                    subtitle: rothConversionSubtitle(vm: vm),
                    color: WMColors.primary
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                AssetLocationView(
                    accountRepo: accountRepo,
                    profileRepo: profileRepo,
                    holdingRepo: holdingRepo
                )
            } label: {
                toolRow(
                    icon: "building.columns.fill",
                    title: "Asset Location Optimizer",
                    subtitle: "\(vm.assetLocationSuggestions.count) placement suggestions",
                    color: WMColors.secondary
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func toolRow(
        icon: String,
        title: String,
        subtitle: String,
        color: Color
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
                Text(subtitle)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(WMColors.textMuted)
        }
        .padding(14)
        .glassCard()
    }

    // MARK: - AI Insight Card

    private func aiInsightCard(vm: TaxViewModel) -> some View {
        let message = buildInsightMessage(vm: vm)
        return AIInsightCard(message: message)
    }

    // MARK: - Helpers

    private func percentString(_ decimal: Decimal) -> String {
        let pct = NSDecimalNumber(decimal: decimal * 100).doubleValue
        return String(format: "%.1f%%", pct)
    }

    private func rothConversionSubtitle(vm: TaxViewModel) -> String {
        guard let opp = vm.rothConversionOpportunity,
              opp.suggestedConversionAmount > 0 else {
            return "Review your conversion eligibility"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(
            from: opp.suggestedConversionAmount as NSDecimalNumber
        ) ?? "\(opp.suggestedConversionAmount)"
        return "Up to \(formatted) conversion opportunity"
    }

    private func buildInsightMessage(vm: TaxViewModel) -> String {
        var tips: [String] = []

        if !vm.harvestingOpportunities.isEmpty {
            tips.append("You have \(vm.harvestingOpportunities.count) holding(s) eligible for tax-loss harvesting.")
        }

        if let opp = vm.rothConversionOpportunity, opp.suggestedConversionAmount > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.maximumFractionDigits = 0
            let amt = formatter.string(from: opp.suggestedConversionAmount as NSDecimalNumber)
                ?? "\(opp.suggestedConversionAmount)"
            tips.append("Consider a Roth conversion of up to \(amt) this year to lock in low rates.")
        }

        if !vm.assetLocationSuggestions.isEmpty {
            tips.append(
                "\(vm.assetLocationSuggestions.count) asset location adjustment(s) could reduce annual tax drag."
            )
        }

        if tips.isEmpty {
            return "Your tax picture looks optimized. Review annually as income and rates change."
        }

        return tips.joined(separator: " ")
    }
}

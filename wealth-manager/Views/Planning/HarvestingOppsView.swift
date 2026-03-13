import SwiftUI

/// Tax-loss harvesting opportunities — lists holdings with unrealized losses,
/// estimated tax savings, and a wash-sale rule reminder.
struct HarvestingOppsView: View {
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
                washSaleWarning
                summaryCard(vm: vm)
                opportunitiesList(vm: vm)
            }
            .padding()
        }
        .background(WMColors.background)
        .navigationTitle("Tax-Loss Harvesting")
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tax-Loss Harvesting")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Text("Holdings with unrealized losses that can offset gains")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Wash-Sale Warning Banner

    private var washSaleWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.yellow)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text("Wash-Sale Rule")
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
                Text(
                    "Do not repurchase the same (or substantially identical) security "
                    + "within 30 days before or after selling to claim a tax loss."
                )
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .glassCard()
    }

    // MARK: - Summary Card

    private func summaryCard(vm: TaxViewModel) -> some View {
        let totalLoss = vm.harvestingOpportunities.reduce(Decimal.zero) {
            $0 + $1.unrealizedLoss
        }
        let totalSavings = vm.harvestingOpportunities.reduce(Decimal.zero) {
            $0 + $1.estimatedTaxSavings
        }

        return HStack(spacing: 0) {
            summaryMetric(
                label: "Total Harvestable Loss",
                amount: totalLoss,
                color: WMColors.negative
            )
            Divider()
                .background(WMColors.glassBorder)
                .frame(height: 40)
            summaryMetric(
                label: "Potential Tax Savings",
                amount: totalSavings,
                color: WMColors.positive
            )
        }
        .padding(16)
        .glassCard()
    }

    private func summaryMetric(label: String, amount: Decimal, color: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
                .multilineTextAlignment(.center)
            CurrencyText(amount: amount, font: WMTypography.subheading)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Opportunities List

    @ViewBuilder
    private func opportunitiesList(vm: TaxViewModel) -> some View {
        if vm.harvestingOpportunities.isEmpty {
            emptyState
        } else {
            VStack(spacing: 10) {
                ForEach(vm.harvestingOpportunities, id: \.holding.id) { opp in
                    harvestingRow(opp: opp)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(WMColors.positive)
            Text("No Harvesting Opportunities")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)
            Text("All your holdings are currently at a gain or break-even.")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .glassCard()
    }

    private func harvestingRow(
        opp: (holding: InvestmentHolding, unrealizedLoss: Decimal, estimatedTaxSavings: Decimal)
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(opp.holding.securityName)
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.textPrimary)
                    if let ticker = opp.holding.tickerSymbol {
                        Text(ticker)
                            .font(WMTypography.caption)
                            .foregroundStyle(WMColors.textMuted)
                    }
                }
                Spacer()
                CurrencyText(amount: opp.holding.currentValue, font: WMTypography.body)
            }

            HStack {
                labeledMetric(
                    label: "Unrealized Loss",
                    value: opp.unrealizedLoss,
                    color: WMColors.negative
                )
                Spacer()
                labeledMetric(
                    label: "Est. Tax Savings",
                    value: opp.estimatedTaxSavings,
                    color: WMColors.positive
                )
            }
        }
        .padding(14)
        .glassCard()
    }

    private func labeledMetric(label: String, value: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            CurrencyText(amount: value, font: WMTypography.body)
                .foregroundStyle(color)
        }
    }
}

import SwiftUI

/// Asset location optimizer — shows which holdings belong in taxable vs.
/// tax-advantaged accounts to minimize annual tax drag.
struct AssetLocationView: View {
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
                savingsSummaryCard(vm: vm)
                suggestionsList(vm: vm)
                educationCard
            }
            .padding()
        }
        .background(WMColors.background)
        .navigationTitle("Asset Location")
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Asset Location Optimizer")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Text("Place assets in the right account type to reduce tax drag")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Savings Summary Card

    private func savingsSummaryCard(vm: TaxViewModel) -> some View {
        let totalSavings = vm.assetLocationSuggestions.reduce(Decimal.zero) {
            $0 + $1.estimatedAnnualTaxSavings
        }
        let count = vm.assetLocationSuggestions.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(WMColors.secondary)
                Text("Potential Tax Drag Savings")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textMuted)
            }

            CurrencyText(amount: totalSavings, font: WMTypography.heroNumber)

            Text("\(count) placement adjustment\(count == 1 ? "" : "s") identified")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard()
    }

    // MARK: - Suggestions List

    @ViewBuilder
    private func suggestionsList(vm: TaxViewModel) -> some View {
        if vm.assetLocationSuggestions.isEmpty {
            emptyState
        } else {
            VStack(spacing: 10) {
                Text("Suggestions")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(vm.assetLocationSuggestions) { suggestion in
                    suggestionRow(suggestion: suggestion)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(WMColors.positive)
            Text("Assets Well-Located")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)
            Text("Your holdings appear to be in optimal account types.")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .glassCard()
    }

    private func suggestionRow(suggestion: AssetLocationSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                accountTypeIcon(suggestion.suggestedAccountType)
                    .foregroundStyle(WMColors.secondary)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Move to \(suggestion.suggestedAccountType.taxContextLabel)")
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.textPrimary)
                    Text(suggestion.reason)
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Text("Est. Annual Savings")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                Spacer()
                CurrencyText(
                    amount: suggestion.estimatedAnnualTaxSavings,
                    font: WMTypography.caption
                )
                .foregroundStyle(WMColors.positive)
            }
        }
        .padding(14)
        .glassCard()
    }

    // MARK: - Education Card

    private var educationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Asset Location Principles")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            educationRow(
                icon: "xmark.circle.fill",
                color: WMColors.negative,
                title: "Tax-Inefficient (hold in IRA/401k)",
                body: "Bonds, REITs, actively managed funds — generate ordinary income taxed annually."
            )

            educationRow(
                icon: "checkmark.circle.fill",
                color: WMColors.positive,
                title: "Tax-Efficient (ok in taxable)",
                body: "Index equity funds, ETFs, municipal bonds — minimal distributions; gains only on sale."
            )
        }
        .padding(16)
        .glassCard()
    }

    private func educationRow(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 16))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
                Text(body)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Helpers

    private func accountTypeIcon(_ type: AccountType) -> Image {
        switch type {
        case .retirement:
            return Image(systemName: "shield.fill")
        case .investment:
            return Image(systemName: "chart.bar.fill")
        default:
            return Image(systemName: "building.columns.fill")
        }
    }
}

// MARK: - AccountType Tax-Context Label

private extension AccountType {
    /// A tax-context–aware label used in asset location suggestions.
    var taxContextLabel: String {
        switch self {
        case .checking:   return "Checking"
        case .savings:    return "Savings"
        case .investment: return "Taxable Brokerage"
        case .retirement: return "Tax-Advantaged (IRA/401k)"
        case .creditCard: return "Credit Card"
        case .loan:       return "Loan"
        case .other:      return "Other"
        }
    }
}

import SwiftUI

// MARK: - ContributionOptimizerView

/// Shows IRS contribution limits for the current year, the user's gap to maximum,
/// and models the impact of increasing contributions on the FIRE timeline.
struct ContributionOptimizerView: View {

    // MARK: - State

    @State private var viewModel: RetirementViewModel?
    @State private var increasePercent: Double = 10
    @State private var currentPortfolio: Double = 250_000
    @State private var annualExpenses: Double = 60_000
    @State private var currentContribution: Double = 20_000

    private let accountRepo: any AccountRepository
    private let profileRepo: any UserProfileRepository

    // MARK: - Init

    init(accountRepo: any AccountRepository, profileRepo: any UserProfileRepository) {
        self.accountRepo = accountRepo
        self.profileRepo = profileRepo
    }

    // MARK: - Computed

    private var limits: (traditional401k: Decimal, catchUp401k: Decimal, ira: Decimal, catchUpIra: Decimal)? {
        viewModel?.contributionLimits
    }

    private var total401kLimit: Decimal {
        guard let l = limits else { return 23_500 }
        return l.traditional401k + l.catchUp401k
    }

    private var totalIraLimit: Decimal {
        guard let l = limits else { return 7_000 }
        return l.ira + l.catchUpIra
    }

    private var contributionImpact: (originalYears: Int, newYears: Int, yearsSaved: Int) {
        RetirementCalculator.contributionImpact(
            currentContribution: Decimal(currentContribution),
            increasePercent: Decimal(increasePercent / 100),
            currentPortfolio: Decimal(currentPortfolio),
            annualExpenses: Decimal(annualExpenses),
            expectedReturn: Decimal(string: "0.07")!
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                limitsCard
                gapCard
                impactCard
            }
            .padding()
        }
        .task {
            let vm = RetirementViewModel(accountRepo: accountRepo, profileRepo: profileRepo)
            viewModel = vm
            await vm.loadRetirementData()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Contribution Optimizer")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Text("Maximize tax-advantaged retirement savings")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Limits Card

    private var limitsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("2025 IRS Contribution Limits")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)
                Spacer()
                if let vm = viewModel {
                    let age = vm.contributionLimits != nil ? "—" : ""
                    let _ = age  // suppress unused warning
                    if vm.contributionLimits?.catchUp401k ?? 0 > 0 {
                        Text("Catch-up Eligible")
                            .font(WMTypography.caption)
                            .foregroundStyle(WMColors.positive)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(WMColors.positive.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }

            limitRow(
                icon: "building.columns.fill",
                title: "401(k) / 403(b)",
                base: limits?.traditional401k ?? 23_500,
                catchUp: limits?.catchUp401k ?? 0,
                color: WMColors.primary
            )

            Divider().background(WMColors.glassBorder)

            limitRow(
                icon: "person.fill",
                title: "IRA (Traditional / Roth)",
                base: limits?.ira ?? 7_000,
                catchUp: limits?.catchUpIra ?? 0,
                color: WMColors.secondary
            )

            Divider().background(WMColors.glassBorder)

            HStack {
                Text("Total Tax-Advantaged")
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textMuted)
                Spacer()
                Text(formatCurrency(total401kLimit + totalIraLimit))
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)
            }
        }
        .padding(20)
        .glassCard()
    }

    private func limitRow(
        icon: String,
        title: String,
        base: Decimal,
        catchUp: Decimal,
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
                if catchUp > 0 {
                    Text("Base: \(formatCurrency(base))  +  Catch-up: \(formatCurrency(catchUp))")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                }
            }

            Spacer()

            Text(formatCurrency(base + catchUp))
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)
        }
    }

    // MARK: - Gap Card

    private var gapCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Contribution Gap")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Current Annual Contribution")
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.textMuted)
                    Spacer()
                    Text(formatCurrency(Decimal(currentContribution)))
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.textPrimary)
                }

                Slider(value: $currentContribution, in: 0...100_000, step: 500)
                    .tint(WMColors.primary)
            }

            let maxContrib = total401kLimit + totalIraLimit
            let gap = max(maxContrib - Decimal(currentContribution), 0)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gap to Maximum")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                    Text(formatCurrency(gap))
                        .font(WMTypography.subheading)
                        .foregroundStyle(gap > 0 ? WMColors.negative : WMColors.positive)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Max Allowed")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                    Text(formatCurrency(maxContrib))
                        .font(WMTypography.subheading)
                        .foregroundStyle(WMColors.textPrimary)
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    // MARK: - Impact Card

    private var impactCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Contribution Impact Simulator")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Increase contributions by")
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.textMuted)
                    Spacer()
                    Text(String(format: "%.0f%%", increasePercent))
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.primary)
                        .monospacedDigit()
                }
                Slider(value: $increasePercent, in: 5...100, step: 5)
                    .tint(WMColors.primary)
            }

            let impact = contributionImpact

            HStack(spacing: 0) {
                impactStat(
                    label: "Current Timeline",
                    value: "\(impact.originalYears) yrs",
                    color: WMColors.textMuted
                )
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(WMColors.primary)
                Spacer()
                impactStat(
                    label: "New Timeline",
                    value: "\(impact.newYears) yrs",
                    color: WMColors.primary
                )
                Spacer()
                impactStat(
                    label: "Years Saved",
                    value: "\(impact.yearsSaved)",
                    color: WMColors.positive
                )
            }
            .padding(.top, 8)
        }
        .padding(20)
        .glassCard()
    }

    private func impactStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(WMTypography.subheading)
                .foregroundStyle(color)
            Text(label)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
                .multilineTextAlignment(.center)
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

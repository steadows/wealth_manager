import SwiftUI

// MARK: - DebtStrategyView

/// Debt payoff hub: avalanche vs snowball comparison, extra payment slider,
/// recommended strategy card, and AI insight.
struct DebtStrategyView: View {

    @State private var viewModel: DebtStrategyViewModel?

    // MARK: - Dependencies (injected for preview / DI)

    private let debtRepo: any DebtRepository
    private let accountRepo: any AccountRepository
    private let profileRepo: any UserProfileRepository

    init(
        debtRepo: any DebtRepository,
        accountRepo: any AccountRepository,
        profileRepo: any UserProfileRepository
    ) {
        self.debtRepo = debtRepo
        self.accountRepo = accountRepo
        self.profileRepo = profileRepo
    }

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            let vm = DebtStrategyViewModel(
                debtRepo: debtRepo,
                accountRepo: accountRepo,
                profileRepo: profileRepo
            )
            viewModel = vm
            await vm.loadDebtData()
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func content(vm: DebtStrategyViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                totalDebtHero(vm: vm)
                strategyComparison(vm: vm)
                extraPaymentSlider(vm: vm)
                recommendationCard(vm: vm)
                AIInsightCard(message: aiInsightMessage(vm: vm))
            }
            .padding()
        }
        .overlay {
            if vm.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(WMColors.glassBg)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Debt Strategy")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            Text("Compare payoff strategies and find your fastest path to debt freedom")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Total Debt Hero

    private func totalDebtHero(vm: DebtStrategyViewModel) -> some View {
        VStack(spacing: 8) {
            Text(formatCurrency(vm.totalDebt))
                .font(WMTypography.heroNumber)
                .foregroundStyle(vm.totalDebt > 0 ? WMColors.negative : WMColors.positive)

            Text("Total Outstanding Debt")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    vm.totalDebt > 0
                        ? WMColors.negative.opacity(0.3)
                        : WMColors.positive.opacity(0.3),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Strategy Comparison Cards

    private func strategyComparison(vm: DebtStrategyViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Strategy Comparison")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            HStack(spacing: 12) {
                strategyCard(
                    title: "Avalanche",
                    subtitle: "Highest rate first",
                    icon: "flame.fill",
                    color: WMColors.negative,
                    plan: vm.avalanchePlan
                )

                strategyCard(
                    title: "Snowball",
                    subtitle: "Smallest balance first",
                    icon: "snowflake",
                    color: WMColors.secondary,
                    plan: vm.snowballPlan
                )
            }
        }
    }

    private func strategyCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        plan: DebtCalculator.PayoffPlan?
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)
            }

            Text(subtitle)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)

            Divider()
                .background(WMColors.glassBorder)

            if let plan {
                VStack(alignment: .leading, spacing: 6) {
                    metricRow(
                        label: "Payoff",
                        value: monthsToYearsMonths(plan.totalMonths)
                    )
                    metricRow(
                        label: "Total Interest",
                        value: formatCurrency(plan.totalInterestPaid)
                    )
                }
            } else {
                Text("—")
                    .foregroundStyle(WMColors.textMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func metricRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            Text(value)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
        }
    }

    // MARK: - Extra Payment Slider

    private func extraPaymentSlider(vm: DebtStrategyViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Extra Monthly Payment")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)
                Spacer()
                Text(formatCurrency(vm.extraMonthlyPayment))
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.primary)
            }

            Slider(
                value: Binding(
                    get: { Double(truncating: vm.extraMonthlyPayment as NSDecimalNumber) },
                    set: { newValue in
                        Task { await vm.updateExtraPayment(Decimal(newValue)) }
                    }
                ),
                in: 0...1000,
                step: 25
            )
            .tint(WMColors.primary)

            HStack {
                Text("$0")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                Spacer()
                Text("$1,000/mo")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Recommendation Card

    private func recommendationCard(vm: DebtStrategyViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(WMColors.glow)
                Text("Recommendation")
                    .font(WMTypography.subheading)
                    .foregroundStyle(WMColors.textPrimary)
            }

            Text(vm.recommendedStrategy.isEmpty ? "Load your debts to see a recommendation." : vm.recommendedStrategy)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(WMColors.glow.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func aiInsightMessage(vm: DebtStrategyViewModel) -> String {
        guard vm.totalDebt > 0 else {
            return "You have no outstanding debt — an excellent financial position."
        }
        if let plan = vm.avalanchePlan, plan.totalMonths > 0 {
            return "At your current rate, you'll be debt-free in \(monthsToYearsMonths(plan.totalMonths)). "
                + "Extra payments have a compounding impact — even $50/mo makes a difference."
        }
        return "Review your debt strategy to minimize interest and accelerate payoff."
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }

    private func monthsToYearsMonths(_ months: Int) -> String {
        guard months > 0 else { return "Paid off" }
        let years = months / 12
        let remaining = months % 12
        if years == 0 { return "\(remaining)mo" }
        if remaining == 0 { return "\(years)yr" }
        return "\(years)yr \(remaining)mo"
    }
}

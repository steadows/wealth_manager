import SwiftUI

// MARK: - InsuranceDashboardView

/// Insurance hub: life insurance gap, emergency fund status, disability coverage,
/// quick navigation to detail views, and AI insight.
struct InsuranceDashboardView: View {

    @State private var viewModel: InsuranceViewModel?
    @State private var showLifeInsurance = false
    @State private var showEmergencyFund = false
    @State private var showEstatePlanning = false

    private let accountRepo: any AccountRepository
    private let profileRepo: any UserProfileRepository

    init(
        accountRepo: any AccountRepository,
        profileRepo: any UserProfileRepository
    ) {
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
            let vm = InsuranceViewModel(accountRepo: accountRepo, profileRepo: profileRepo)
            viewModel = vm
            await vm.loadInsuranceData()
        }
        .sheet(isPresented: $showLifeInsurance) {
            LifeInsuranceCalcView()
        }
        .sheet(isPresented: $showEmergencyFund) {
            if let vm = viewModel {
                EmergencyFundView(viewModel: vm)
            }
        }
        .sheet(isPresented: $showEstatePlanning) {
            if let vm = viewModel {
                EstatePlanningChecklistView(viewModel: vm)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(vm: InsuranceViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                lifeInsuranceCard(vm: vm)
                emergencyFundCard(vm: vm)
                disabilityCard(vm: vm)
                quickNavRow(vm: vm)
                AIInsightCard(message: aiInsightMessage(vm: vm))
            }
            .padding()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Insurance Analysis")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            Text("Protect what matters with comprehensive coverage analysis")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Life Insurance Card

    private func lifeInsuranceCard(vm: InsuranceViewModel) -> some View {
        let isCritical = vm.lifeInsuranceGap > 100_000
        let statusColor = isCritical ? WMColors.negative : WMColors.positive
        let statusText = isCritical ? "Significant Gap" : (vm.lifeInsuranceGap > 0 ? "Some Gap" : "Well Covered")

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(statusColor)
                    Text("Life Insurance")
                        .font(WMTypography.subheading)
                        .foregroundStyle(WMColors.textPrimary)
                }
                Spacer()
                statusBadge(text: statusText, color: statusColor)
            }

            HStack(spacing: 24) {
                metricBlock(label: "Total Need", value: formatCurrency(vm.lifeInsuranceTotalNeed))
                metricBlock(label: "Gap", value: formatCurrency(vm.lifeInsuranceGap), color: isCritical ? WMColors.negative : WMColors.textPrimary)
            }
        }
        .padding(16)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCritical ? WMColors.negative.opacity(0.3) : WMColors.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Emergency Fund Card

    private func emergencyFundCard(vm: InsuranceViewModel) -> some View {
        let monthsCovered = NSDecimalNumber(decimal: vm.emergencyFundMonthsCovered).doubleValue
        let progress = min(monthsCovered / 6.0, 1.0)
        let isHealthy = monthsCovered >= 6
        let statusColor = isHealthy ? WMColors.positive : (monthsCovered >= 3 ? WMColors.glow : WMColors.negative)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "umbrella.fill")
                        .foregroundStyle(statusColor)
                    Text("Emergency Fund")
                        .font(WMTypography.subheading)
                        .foregroundStyle(WMColors.textPrimary)
                }
                Spacer()
                Text(String(format: "%.1f / 6 months", monthsCovered))
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
            }

            ProgressView(value: progress)
                .tint(statusColor)
                .background(WMColors.glassBg)
                .clipShape(Capsule())

            if vm.emergencyFundShortfall > 0 {
                Text("Shortfall: \(formatCurrency(vm.emergencyFundShortfall))")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.negative)
            } else {
                Text("Emergency fund goal met")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.positive)
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Disability Card

    private func disabilityCard(vm: InsuranceViewModel) -> some View {
        let hasGap = vm.disabilityCoverageGap > 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "figure.stand")
                        .foregroundStyle(hasGap ? WMColors.glow : WMColors.positive)
                    Text("Disability Coverage")
                        .font(WMTypography.subheading)
                        .foregroundStyle(WMColors.textPrimary)
                }
                Spacer()
                statusBadge(
                    text: hasGap ? "Gap Detected" : "Covered",
                    color: hasGap ? WMColors.glow : WMColors.positive
                )
            }

            metricBlock(
                label: "Annual Coverage Gap",
                value: formatCurrency(vm.disabilityCoverageGap),
                color: hasGap ? WMColors.glow : WMColors.positive
            )

            Text("Recommendation: 65% of annual income in disability coverage")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Quick Nav Row

    private func quickNavRow(vm: InsuranceViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tools")
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            HStack(spacing: 12) {
                navButton(
                    title: "Life Ins. Calc",
                    icon: "calculator",
                    color: WMColors.secondary
                ) { showLifeInsurance = true }

                navButton(
                    title: "Emergency Fund",
                    icon: "umbrella",
                    color: WMColors.tertiary
                ) { showEmergencyFund = true }

                navButton(
                    title: "Estate Plan",
                    icon: "doc.text.fill",
                    color: WMColors.glow
                ) { showEstatePlanning = true }
            }
        }
    }

    private func navButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                Text(title)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .glassCard()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(WMTypography.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func metricBlock(label: String, value: String, color: Color = WMColors.textPrimary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            Text(value)
                .font(WMTypography.subheading)
                .foregroundStyle(color)
        }
    }

    private func aiInsightMessage(vm: InsuranceViewModel) -> String {
        if vm.lifeInsuranceGap > 100_000 {
            return "You have a significant life insurance gap of \(formatCurrency(vm.lifeInsuranceGap)). "
                + "Consider term life insurance to protect your dependents."
        }
        if vm.emergencyFundShortfall > 0 {
            return "Building your emergency fund to 6 months of expenses provides a critical financial buffer. "
                + "You need \(formatCurrency(vm.emergencyFundShortfall)) more to reach the target."
        }
        return "Your insurance coverage looks solid. Review annually and after major life events."
    }

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0"
    }
}

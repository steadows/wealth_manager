import SwiftUI

// MARK: - RetirementDashboardView

/// Top-level retirement planning hub. Shows readiness score, FIRE number,
/// years to FIRE, and provides navigation to detailed retirement tools.
struct RetirementDashboardView: View {

    @State private var viewModel: RetirementViewModel?

    private let accountRepo: any AccountRepository
    private let profileRepo: any UserProfileRepository

    // MARK: - Init

    init(accountRepo: any AccountRepository, profileRepo: any UserProfileRepository) {
        self.accountRepo = accountRepo
        self.profileRepo = profileRepo
    }

    // MARK: - Body

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
            let vm = RetirementViewModel(accountRepo: accountRepo, profileRepo: profileRepo)
            viewModel = vm
            await vm.loadRetirementData()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(vm: RetirementViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                readinessHero(vm: vm)
                metricsRow(vm: vm)
                navigationGrid(vm: vm)
                AIInsightCard(message: retirementInsight(vm: vm))
            }
            .padding()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Retirement Planning")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Text("Your path to financial independence")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Readiness Hero

    private func readinessHero(vm: RetirementViewModel) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(WMColors.glassBorder, lineWidth: 12)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: CGFloat(vm.readinessScore) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [WMColors.primary, WMColors.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: vm.readinessScore)

                VStack(spacing: 2) {
                    Text("\(vm.readinessScore)%")
                        .font(WMTypography.heroNumber)
                        .foregroundStyle(WMColors.textPrimary)
                    Text("Readiness")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                }
            }

            Text(readinessLabel(score: vm.readinessScore))
                .font(WMTypography.subheading)
                .foregroundStyle(readinessColor(score: vm.readinessScore))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard()
    }

    // MARK: - Metrics Row

    private func metricsRow(vm: RetirementViewModel) -> some View {
        HStack(spacing: 16) {
            metricCard(
                title: "FIRE Number",
                value: formatCurrency(vm.fireNumber),
                icon: "flame.fill",
                color: WMColors.primary
            )

            metricCard(
                title: "Years to FIRE",
                value: vm.yearsToFIRE.map { "\($0)" } ?? "—",
                icon: "hourglass",
                color: WMColors.secondary
            )

            metricCard(
                title: "Retirement Age",
                value: "\(vm.retirementAge)",
                icon: "person.fill",
                color: WMColors.tertiary
            )
        }
    }

    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)

            Text(value)
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    // MARK: - Navigation Grid

    private func navigationGrid(vm: RetirementViewModel) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
            spacing: 16
        ) {
            navCard(
                icon: "flame.fill",
                title: "FIRE Calculator",
                subtitle: "Interactive goal simulator",
                color: WMColors.primary
            )

            navCard(
                icon: "chart.bar.fill",
                title: "Contribution Optimizer",
                subtitle: "Maximize tax-advantaged savings",
                color: WMColors.secondary
            )

            navCard(
                icon: "person.2.fill",
                title: "Social Security",
                subtitle: "Claiming strategy analysis",
                color: WMColors.tertiary
            )

            navCard(
                icon: "arrow.counterclockwise",
                title: "RMD Planner",
                subtitle: vm.projectedRMD > 0
                    ? "Est. \(formatCurrency(vm.projectedRMD))/yr"
                    : "Required at age 73",
                color: WMColors.glow
            )
        }
    }

    private func navCard(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(color)

            Text(title)
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            Text(subtitle)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(16)
        .glassCard()
    }

    // MARK: - Helpers

    private func readinessLabel(score: Int) -> String {
        switch score {
        case 80...100: return "On Track"
        case 50..<80: return "Making Progress"
        case 20..<50: return "Needs Attention"
        default: return "Behind Schedule"
        }
    }

    private func readinessColor(score: Int) -> Color {
        switch score {
        case 80...100: return WMColors.positive
        case 50..<80: return WMColors.secondary
        default: return WMColors.negative
        }
    }

    private func retirementInsight(vm: RetirementViewModel) -> String {
        if vm.readinessScore >= 80 {
            return "You're on track for retirement. Consider optimizing contribution timing and Social Security claiming age."
        } else if let years = vm.yearsToFIRE {
            return "At your current savings rate, you could reach financial independence in \(years) years. Increasing contributions accelerates this."
        } else {
            return "Link your accounts and complete your profile to receive personalized retirement insights."
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }
}

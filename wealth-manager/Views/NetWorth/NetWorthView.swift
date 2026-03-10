import SwiftUI
import Charts

// MARK: - NetWorthView

/// Net Worth screen: hero number, history chart, asset breakdown, milestones.
struct NetWorthView: View {

    @State private var viewModel: NetWorthViewModel?

    let accountRepo: any AccountRepository
    let snapshotRepo: any SnapshotRepository
    let profileRepo: any UserProfileRepository

    var body: some View {
        Group {
            if let vm = viewModel {
                netWorthContent(vm)
            } else {
                ProgressView()
            }
        }
        .task {
            let netWorthService = NetWorthService(accountRepo: accountRepo, snapshotRepo: snapshotRepo)
            let projectionService = ProjectionService()
            let vm = NetWorthViewModel(
                netWorthService: netWorthService,
                projectionService: projectionService,
                accountRepo: accountRepo,
                profileRepo: profileRepo
            )
            viewModel = vm
            await vm.loadData()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func netWorthContent(_ vm: NetWorthViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection(vm)
                historyChartSection(vm)
                assetBreakdownSection(vm)
                milestoneSection(vm)
            }
            .padding(24)
        }
        .background(WMColors.background)
        .navigationTitle("Net Worth")
    }

    // MARK: - Hero Section

    @ViewBuilder
    private func heroSection(_ vm: NetWorthViewModel) -> some View {
        VStack(spacing: 12) {
            Text("Net Worth")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)

            CurrencyText(amount: vm.netWorth, font: WMTypography.heroNumber)

            HStack(spacing: 16) {
                changeIndicator(amount: vm.changeAmount, percent: vm.changePercent)
            }

            HStack(spacing: 32) {
                VStack(spacing: 4) {
                    Text("Assets")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                    CurrencyText(amount: vm.totalAssets)
                        .foregroundStyle(WMColors.positive)
                }

                VStack(spacing: 4) {
                    Text("Liabilities")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                    CurrencyText(amount: vm.totalLiabilities)
                        .foregroundStyle(WMColors.negative)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard()
    }

    // MARK: - History Chart

    @ViewBuilder
    private func historyChartSection(_ vm: NetWorthViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("History")
                    .font(WMTypography.heading)
                    .foregroundStyle(WMColors.textPrimary)

                Spacer()

                timePeriodPicker(vm)
            }

            if vm.history.isEmpty {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No History Yet",
                    description: "Snapshots will appear as your data grows."
                )
            } else {
                Chart(vm.history, id: \.id) { snapshot in
                    LineMark(
                        x: .value("Date", snapshot.date),
                        y: .value("Net Worth", snapshot.netWorth)
                    )
                    .foregroundStyle(WMColors.primary)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", snapshot.date),
                        y: .value("Net Worth", snapshot.netWorth)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [WMColors.primary.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let decimal = value.as(Decimal.self) {
                                CurrencyText(amount: decimal, font: WMTypography.caption)
                            }
                        }
                        AxisGridLine()
                            .foregroundStyle(WMColors.glassBorder)
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                        AxisGridLine()
                            .foregroundStyle(WMColors.glassBorder)
                    }
                }
                .frame(height: 250)
            }
        }
        .padding(24)
        .glassCard()
    }

    // MARK: - Asset Breakdown

    @ViewBuilder
    private func assetBreakdownSection(_ vm: NetWorthViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Asset Allocation")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            if vm.assetBreakdown.isEmpty {
                EmptyStateView(
                    icon: "chart.pie",
                    title: "No Assets",
                    description: "Add accounts to see your allocation."
                )
            } else {
                ForEach(vm.assetBreakdown) { entry in
                    HStack {
                        Circle()
                            .fill(colorForAccountType(entry.type))
                            .frame(width: 10, height: 10)

                        Text(entry.type.rawValue.capitalized)
                            .font(WMTypography.body)
                            .foregroundStyle(WMColors.textPrimary)

                        Spacer()

                        CurrencyText(amount: entry.amount, font: WMTypography.body)

                        Text(formatPercent(entry.percentage))
                            .font(WMTypography.caption)
                            .foregroundStyle(WMColors.textMuted)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(24)
        .glassCard()
    }

    // MARK: - Milestones

    @ViewBuilder
    private func milestoneSection(_ vm: NetWorthViewModel) -> some View {
        if !vm.milestones.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("Milestones")
                    .font(WMTypography.heading)
                    .foregroundStyle(WMColors.textPrimary)

                ForEach(Array(vm.milestones.enumerated()), id: \.offset) { _, milestone in
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(WMColors.secondary)

                        CurrencyText(amount: milestone.milestone, font: WMTypography.body)

                        Spacer()

                        Text(milestone.date, style: .date)
                            .font(WMTypography.caption)
                            .foregroundStyle(WMColors.textMuted)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(24)
            .glassCard()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func changeIndicator(amount: Decimal, percent: Decimal) -> some View {
        let isPositive = amount >= 0
        HStack(spacing: 4) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
            CurrencyText(amount: abs(amount), font: WMTypography.caption)
            Text("(\(formatPercent(abs(percent))))")
                .font(WMTypography.caption)
        }
        .foregroundStyle(isPositive ? WMColors.positive : WMColors.negative)
    }

    @ViewBuilder
    private func timePeriodPicker(_ vm: NetWorthViewModel) -> some View {
        HStack(spacing: 8) {
            periodButton("1M", period: .month, vm: vm)
            periodButton("3M", period: .quarter, vm: vm)
            periodButton("1Y", period: .year, vm: vm)
        }
    }

    @ViewBuilder
    private func periodButton(_ label: String, period: TimePeriod, vm: NetWorthViewModel) -> some View {
        Button(label) {
            vm.selectedTimePeriod = period
            Task { await vm.loadData() }
        }
        .buttonStyle(.plain)
        .font(WMTypography.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(WMColors.glassBg)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(WMColors.glassBorder, lineWidth: 1))
    }

    private func formatPercent(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value * 100)
        return "\(number.doubleValue.formatted(.number.precision(.fractionLength(1))))%"
    }

    private func colorForAccountType(_ type: AccountType) -> Color {
        switch type {
        case .checking: return WMColors.primary
        case .savings: return WMColors.secondary
        case .investment: return WMColors.tertiary
        case .retirement: return WMColors.glow
        default: return WMColors.textMuted
        }
    }
}

import SwiftUI
import Charts

// MARK: - ProjectionView

/// Projection screen: multi-scenario chart, Monte Carlo bands, FIRE summary.
struct ProjectionView: View {

    @State private var viewModel: ProjectionViewModel?

    let accountRepo: any AccountRepository
    let profileRepo: any UserProfileRepository

    var body: some View {
        Group {
            if let vm = viewModel {
                projectionContent(vm)
            } else {
                ProgressView()
            }
        }
        .task {
            let vm = ProjectionViewModel(
                projectionService: ProjectionService(),
                accountRepo: accountRepo,
                profileRepo: profileRepo
            )
            viewModel = vm
            await vm.loadProjections()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func projectionContent(_ vm: ProjectionViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                scenarioChartSection(vm)
                monteCarloSection(vm)
                fireSection(vm)
                horizonPicker(vm)
            }
            .padding(24)
        }
        .background(WMColors.background)
        .navigationTitle("Projections")
    }

    // MARK: - Scenario Chart

    @ViewBuilder
    private func scenarioChartSection(_ vm: ProjectionViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Net Worth Projections")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            if vm.scenarios.isEmpty {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No Projections",
                    description: "Add accounts to see projections."
                )
            } else {
                Chart {
                    ForEach(vm.scenarios, id: \.label) { scenario in
                        ForEach(scenario.points, id: \.year) { point in
                            LineMark(
                                x: .value("Year", point.year),
                                y: .value("Net Worth", point.netWorth)
                            )
                            .foregroundStyle(by: .value("Scenario", scenario.label))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "Conservative": WMColors.secondary,
                    "Moderate": WMColors.primary,
                    "Aggressive": WMColors.positive,
                ])
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
                .frame(height: 300)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Net worth projection chart showing \(vm.scenarios.count) scenarios over \(vm.projectionYears) years")

                // Legend with final values
                VStack(spacing: 8) {
                    ForEach(vm.scenarios, id: \.label) { scenario in
                        HStack {
                            Circle()
                                .fill(colorForScenario(scenario.label))
                                .frame(width: 8, height: 8)

                            Text(scenario.label)
                                .font(WMTypography.caption)
                                .foregroundStyle(WMColors.textMuted)

                            Spacer()

                            CurrencyText(amount: scenario.finalNetWorth, font: WMTypography.body)
                        }
                    }
                }
            }
        }
        .padding(24)
        .glassCard()
    }

    // MARK: - Monte Carlo

    @ViewBuilder
    private func monteCarloSection(_ vm: ProjectionViewModel) -> some View {
        if let mc = vm.monteCarloResult {
            VStack(alignment: .leading, spacing: 16) {
                Text("Monte Carlo Simulation")
                    .font(WMTypography.heading)
                    .foregroundStyle(WMColors.textPrimary)

                Text("1,000 simulations with random market returns")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)

                Chart {
                    // 10th-90th percentile band
                    ForEach(Array(mc.percentile10.enumerated()), id: \.offset) { i, p10 in
                        let p90 = mc.percentile90[i]
                        AreaMark(
                            x: .value("Year", p10.year),
                            yStart: .value("P10", p10.netWorth),
                            yEnd: .value("P90", p90.netWorth)
                        )
                        .foregroundStyle(WMColors.primary.opacity(0.15))
                    }

                    // 25th-75th percentile band
                    ForEach(Array(mc.percentile25.enumerated()), id: \.offset) { i, p25 in
                        let p75 = mc.percentile75[i]
                        AreaMark(
                            x: .value("Year", p25.year),
                            yStart: .value("P25", p25.netWorth),
                            yEnd: .value("P75", p75.netWorth)
                        )
                        .foregroundStyle(WMColors.primary.opacity(0.3))
                    }

                    // Median line
                    ForEach(mc.median, id: \.year) { point in
                        LineMark(
                            x: .value("Year", point.year),
                            y: .value("Median", point.netWorth)
                        )
                        .foregroundStyle(WMColors.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
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
                .frame(height: 250)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Monte Carlo simulation chart. 1,000 simulations showing probability distribution of net worth")

                HStack {
                    Label {
                        Text("Success Rate")
                            .font(WMTypography.caption)
                            .foregroundStyle(WMColors.textMuted)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(WMColors.positive)
                    }

                    Spacer()

                    Text(formatPercent(mc.successRate))
                        .font(WMTypography.heading)
                        .foregroundStyle(WMColors.positive)
                }
            }
            .padding(24)
            .glassCard()
        }
    }

    // MARK: - FIRE Section

    @ViewBuilder
    private func fireSection(_ vm: ProjectionViewModel) -> some View {
        if let fire = vm.fireResult {
            VStack(alignment: .leading, spacing: 16) {
                Text("FIRE Analysis")
                    .font(WMTypography.heading)
                    .foregroundStyle(WMColors.textPrimary)

                HStack(spacing: 24) {
                    fireMetric(
                        label: "FIRE Number",
                        value: fire.fireNumber
                    )

                    if let years = fire.yearsToFIRE {
                        VStack(spacing: 4) {
                            Text("Years to FIRE")
                                .font(WMTypography.caption)
                                .foregroundStyle(WMColors.textMuted)
                            Text("\(years)")
                                .font(WMTypography.heading)
                                .foregroundStyle(WMColors.glow)
                        }
                    }

                    fireMetric(
                        label: "Monthly Needed",
                        value: fire.monthlyContributionNeeded
                    )

                    fireMetric(
                        label: "Retirement Income",
                        value: fire.projectedRetirementIncome
                    )
                }
            }
            .padding(24)
            .glassCard()
        }
    }

    // MARK: - Horizon Picker

    @ViewBuilder
    private func horizonPicker(_ vm: ProjectionViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Projection Horizon: \(vm.projectionYears) years")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)

            HStack(spacing: 8) {
                ForEach([10, 20, 30, 40], id: \.self) { years in
                    Button("\(years)y") {
                        vm.projectionYears = years
                        Task { await vm.loadProjections() }
                    }
                    .buttonStyle(.plain)
                    .font(WMTypography.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        vm.projectionYears == years
                            ? WMColors.primary.opacity(0.3)
                            : WMColors.glassBg
                    )
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(WMColors.glassBorder, lineWidth: 1))
                    .accessibilityLabel("\(years) year projection")
                    .accessibilityValue(vm.projectionYears == years ? "Selected" : "")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .glassCard()
    }

    // MARK: - Helpers

    @ViewBuilder
    private func fireMetric(label: String, value: Decimal) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            CurrencyText(amount: value, font: WMTypography.body)
        }
    }

    private func formatPercent(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value * 100)
        return "\(number.doubleValue.formatted(.number.precision(.fractionLength(1))))%"
    }

    private func colorForScenario(_ label: String) -> Color {
        switch label {
        case "Conservative": return WMColors.secondary
        case "Moderate": return WMColors.primary
        case "Aggressive": return WMColors.positive
        default: return WMColors.textMuted
        }
    }
}

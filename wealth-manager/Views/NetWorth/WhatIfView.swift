import SwiftUI
import Charts

// MARK: - WhatIfView

/// What-If screen: interactive scenario comparison against baseline projection.
struct WhatIfView: View {

    @State private var viewModel: WhatIfViewModel?

    // Adjustment inputs
    @State private var selectedAdjustment: AdjustmentType = .increaseSavings
    @State private var adjustmentAmount: String = ""
    @State private var sabbaticalMonths: String = "6"

    let accountRepo: any AccountRepository
    let profileRepo: any UserProfileRepository

    var body: some View {
        Group {
            if let vm = viewModel {
                whatIfContent(vm)
            } else {
                ProgressView()
            }
        }
        .task {
            let vm = WhatIfViewModel(
                accountRepo: accountRepo,
                profileRepo: profileRepo
            )
            viewModel = vm
            await vm.loadBaseline()
        }
    }

    // MARK: - Adjustment Type

    enum AdjustmentType: String, CaseIterable, Identifiable {
        case increaseSavings = "Increase Savings"
        case payOffMortgage = "Pay Off Mortgage"
        case sabbatical = "Take Sabbatical"
        case sellRSUs = "Sell RSUs"

        var id: String { rawValue }
    }

    // MARK: - Content

    @ViewBuilder
    private func whatIfContent(_ vm: WhatIfViewModel) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                comparisonChartSection(vm)
                adjustmentControls(vm)
                impactSummary(vm)
            }
            .padding(24)
        }
        .background(WMColors.background)
        .navigationTitle("What If?")
    }

    // MARK: - Comparison Chart

    @ViewBuilder
    private func comparisonChartSection(_ vm: WhatIfViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scenario Comparison")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            Chart {
                // Baseline
                ForEach(vm.baselinePoints, id: \.year) { point in
                    LineMark(
                        x: .value("Year", point.year),
                        y: .value("Net Worth", point.netWorth)
                    )
                    .foregroundStyle(by: .value("Scenario", "Baseline"))
                    .interpolationMethod(.catmullRom)
                }

                // Adjusted (if present)
                if !vm.adjustedPoints.isEmpty {
                    ForEach(vm.adjustedPoints, id: \.year) { point in
                        LineMark(
                            x: .value("Year", point.year),
                            y: .value("Net Worth", point.netWorth)
                        )
                        .foregroundStyle(by: .value("Scenario", "What If"))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 3]))
                    }
                }
            }
            .chartForegroundStyleScale([
                "Baseline": WMColors.textMuted,
                "What If": WMColors.primary,
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
            .accessibilityLabel("What-if scenario comparison chart showing baseline versus adjusted net worth projection")
        }
        .padding(24)
        .glassCard()
    }

    // MARK: - Adjustment Controls

    @ViewBuilder
    private func adjustmentControls(_ vm: WhatIfViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Adjust Your Scenario")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            Picker("Adjustment", selection: $selectedAdjustment) {
                ForEach(AdjustmentType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            switch selectedAdjustment {
            case .increaseSavings:
                amountField(label: "Additional Annual Savings", placeholder: "12000")
            case .payOffMortgage:
                amountField(label: "Mortgage Balance", placeholder: "200000")
            case .sabbatical:
                HStack {
                    Text("Months")
                        .font(WMTypography.body)
                        .foregroundStyle(WMColors.textMuted)
                    TextField("6", text: $sabbaticalMonths)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            case .sellRSUs:
                amountField(label: "RSU Value", placeholder: "50000")
            }

            HStack(spacing: 12) {
                Button("Apply") {
                    Task { await applyCurrentAdjustment(vm) }
                }
                .buttonStyle(.borderedProminent)
                .tint(WMColors.primary)

                if !vm.adjustedPoints.isEmpty {
                    Button("Clear") {
                        vm.clearAdjustment()
                        adjustmentAmount = ""
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(24)
        .glassCard()
    }

    // MARK: - Impact Summary

    @ViewBuilder
    private func impactSummary(_ vm: WhatIfViewModel) -> some View {
        if !vm.adjustedPoints.isEmpty {
            VStack(spacing: 12) {
                Text("Impact After \(vm.projectionYears) Years")
                    .font(WMTypography.heading)
                    .foregroundStyle(WMColors.textPrimary)

                let isPositive = vm.impactAmount >= 0
                HStack(spacing: 8) {
                    Image(systemName: isPositive ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .font(.title2)
                        .accessibilityHidden(true)
                    CurrencyText(amount: abs(vm.impactAmount), font: WMTypography.heading)
                }
                .foregroundStyle(isPositive ? WMColors.positive : WMColors.negative)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Impact: \(isPositive ? "positive" : "negative")")

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("Baseline")
                            .font(WMTypography.caption)
                            .foregroundStyle(WMColors.textMuted)
                        CurrencyText(amount: vm.baselinePoints.last?.netWorth ?? 0, font: WMTypography.body)
                    }

                    VStack(spacing: 4) {
                        Text("With Change")
                            .font(WMTypography.caption)
                            .foregroundStyle(WMColors.textMuted)
                        CurrencyText(amount: vm.adjustedPoints.last?.netWorth ?? 0, font: WMTypography.body)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .glassCard()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func amountField(label: String, placeholder: String) -> some View {
        HStack {
            Text(label)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
            TextField(placeholder, text: $adjustmentAmount)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)
        }
    }

    private func applyCurrentAdjustment(_ vm: WhatIfViewModel) async {
        let adjustment: WhatIfAdjustment
        switch selectedAdjustment {
        case .increaseSavings:
            let amount = Decimal(string: adjustmentAmount) ?? 12_000
            adjustment = .increaseSavings(amount)
        case .payOffMortgage:
            let amount = Decimal(string: adjustmentAmount) ?? 200_000
            adjustment = .payOffMortgage(amount)
        case .sabbatical:
            let months = Int(sabbaticalMonths) ?? 6
            adjustment = .sabbatical(months: months)
        case .sellRSUs:
            let amount = Decimal(string: adjustmentAmount) ?? 50_000
            adjustment = .sellRSUs(amount)
        }
        await vm.applyAdjustment(adjustment)
    }
}

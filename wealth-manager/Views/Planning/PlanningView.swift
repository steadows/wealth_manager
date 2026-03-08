import SwiftUI

/// Placeholder hub view for financial planning modules.
struct PlanningView: View {
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                planningGrid
                aiInsight
            }
            .padding()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Financial Planning")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            Text("Comprehensive tools to optimize your financial future")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Planning Grid

    private var planningGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            planningCard(
                icon: "target",
                title: "Retirement Planning",
                metric: "\u{2014}",
                metricLabel: "Years to retirement",
                color: WMColors.primary
            )

            planningCard(
                icon: "doc.text.fill",
                title: "Tax Intelligence",
                metric: "\u{2014}",
                metricLabel: "Estimated tax liability",
                color: WMColors.secondary
            )

            planningCard(
                icon: "chart.line.downtrend.xyaxis",
                title: "Debt Strategy",
                metric: "\u{2014}",
                metricLabel: "Total debt balance",
                color: WMColors.tertiary
            )

            planningCard(
                icon: "shield.fill",
                title: "Insurance Analysis",
                metric: "\u{2014}",
                metricLabel: "Coverage status",
                color: WMColors.glow
            )
        }
    }

    private func planningCard(
        icon: String,
        title: String,
        metric: String,
        metricLabel: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                Spacer()
            }

            Text(title)
                .font(WMTypography.subheading)
                .foregroundStyle(WMColors.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text(metric)
                    .font(WMTypography.heroNumber)
                    .foregroundStyle(WMColors.textPrimary)

                Text(metricLabel)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
            }

            Spacer()

            Button {} label: {
                HStack(spacing: 4) {
                    Text("Explore")
                    Image(systemName: "arrow.right")
                }
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            }
            .buttonStyle(.plain)
            .disabled(true)
            .help("Coming in Sprint 8")
        }
        .padding(20)
        .frame(minHeight: 200)
        .glassCard()
    }

    // MARK: - AI Insight

    private var aiInsight: some View {
        AIInsightCard(message: "Holistic financial planning available after account linking")
    }
}

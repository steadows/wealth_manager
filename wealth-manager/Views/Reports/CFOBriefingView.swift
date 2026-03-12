import SwiftUI

// MARK: - CFOBriefingView

/// Weekly/monthly CFO briefing with health score, insights, and action items.
struct CFOBriefingView: View {
    @State var viewModel: CFOBriefingViewModel
    @State private var selectedPeriod: String = "weekly"

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                periodPicker
                if viewModel.isLoading {
                    ProgressView("Loading briefing...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let briefing = viewModel.briefing {
                    healthScoreSection(briefing: briefing)
                    summarySection(briefing: briefing)
                    insightsSection(briefing: briefing)
                    actionItemsSection(briefing: briefing)
                } else if let error = viewModel.errorMessage {
                    errorView(message: error)
                }
            }
            .padding(24)
        }
        .background(WMColors.background)
        .navigationTitle("CFO Briefing")
        .task { await loadAll() }
        .onChange(of: selectedPeriod) {
            Task { await viewModel.loadBriefing(period: selectedPeriod) }
        }
    }

    // MARK: - Subviews

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            Text("Weekly").tag("weekly")
            Text("Monthly").tag("monthly")
        }
        .pickerStyle(.segmented)
    }

    private func healthScoreSection(briefing: CFOBriefingDTO) -> some View {
        VStack(spacing: 8) {
            Text("Financial Health")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            ZStack {
                Circle()
                    .stroke(WMColors.glassBorder, lineWidth: 12)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: CGFloat(briefing.healthScore) / 100)
                    .stroke(scoreColor(briefing.healthScore), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                Text("\(briefing.healthScore)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(WMColors.textPrimary)
            }
            if let hs = viewModel.healthScore {
                Text(hs.narrative)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .background(WMColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func summarySection(briefing: CFOBriefingDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            Text(briefing.summary)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(WMColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func insightsSection(briefing: CFOBriefingDTO) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Insights")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            ForEach(Array(briefing.insights.enumerated()), id: \.offset) { _, insight in
                InsightRow(insight: insight)
            }
        }
    }

    private func actionItemsSection(briefing: CFOBriefingDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Action Items")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            ForEach(Array(briefing.actionItems.enumerated()), id: \.offset) { _, item in
                Label(item, systemImage: "checkmark.circle")
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(WMColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(WMColors.negative)
            Text(message)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return WMColors.positive
        case 60..<80: return WMColors.secondary
        default: return WMColors.negative
        }
    }

    private func loadAll() async {
        async let briefingLoad: () = viewModel.loadBriefing(period: selectedPeriod)
        async let scoreLoad: () = viewModel.loadHealthScore()
        _ = await (briefingLoad, scoreLoad)
    }
}

// MARK: - InsightRow

private struct InsightRow: View {
    let insight: BriefingInsightDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: impactIcon)
                .foregroundStyle(impactColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textPrimary)
                Text(insight.detail)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
            }
            Spacer()
        }
        .padding(12)
        .background(WMColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var impactIcon: String {
        switch insight.impact {
        case "positive": return "arrow.up.circle.fill"
        case "negative": return "arrow.down.circle.fill"
        default: return "minus.circle.fill"
        }
    }

    private var impactColor: Color {
        switch insight.impact {
        case "positive": return WMColors.positive
        case "negative": return WMColors.negative
        default: return WMColors.textMuted
        }
    }
}

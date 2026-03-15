import SwiftUI

// MARK: - CFOBriefingView

/// Weekly/monthly CFO briefing with animated health gauge, AI analysis,
/// net worth change, insights, goal progress, and action items.
struct CFOBriefingView: View {
    @State var viewModel: CFOBriefingViewModel
    @State private var selectedPeriod: String = "weekly"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showNarrative: Bool = false
    @State private var hasAppeared: Bool = false
    @State private var animatedProgress: Double = 0

    /// Amber / warning color (not in WMColors).
    private let amber = Color(red: 234 / 255, green: 179 / 255, blue: 8 / 255)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                periodPicker

                if viewModel.isLoading {
                    ProgressView("Loading briefing...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let briefing = viewModel.briefing {
                    healthScoreCard(briefing: briefing)
                        .modifier(StaggeredAppearance(index: 0, hasAppeared: hasAppeared, reduceMotion: reduceMotion))

                    aiAnalysisCard
                        .modifier(StaggeredAppearance(index: 1, hasAppeared: hasAppeared, reduceMotion: reduceMotion))

                    netWorthChangeCard(briefing: briefing)
                        .modifier(StaggeredAppearance(index: 2, hasAppeared: hasAppeared, reduceMotion: reduceMotion))

                    summaryCard(briefing: briefing)
                        .modifier(StaggeredAppearance(index: 3, hasAppeared: hasAppeared, reduceMotion: reduceMotion))

                    insightsSection(briefing: briefing)
                        .modifier(StaggeredAppearance(index: 4, hasAppeared: hasAppeared, reduceMotion: reduceMotion))

                    goalProgressCard(briefing: briefing)
                        .modifier(StaggeredAppearance(index: 5, hasAppeared: hasAppeared, reduceMotion: reduceMotion))

                    actionItemsCard(briefing: briefing)
                        .modifier(StaggeredAppearance(index: 6, hasAppeared: hasAppeared, reduceMotion: reduceMotion))
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

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            Text("Weekly").tag("weekly")
            Text("Monthly").tag("monthly")
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Health Score Card

    private func healthScoreCard(briefing: CFOBriefingDTO) -> some View {
        let score = viewModel.healthScore?.overallScore ?? briefing.healthScore

        return VStack(spacing: 16) {
            Text("Financial Health")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)

            // Animated circular gauge
            ZStack {
                Circle()
                    .stroke(WMColors.glassBorder, lineWidth: 14)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            stops: [
                                .init(color: WMColors.negative, location: 0.0),
                                .init(color: amber, location: 0.5),
                                .init(color: WMColors.positive, location: 1.0)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(WMColors.textPrimary)
                    Text("/100")
                        .font(WMTypography.caption)
                        .foregroundStyle(WMColors.textMuted)
                }
            }
            .frame(width: 120, height: 120)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Financial health score: \(score) out of 100")

            // Sub-score breakdown
            if let hs = viewModel.healthScore {
                VStack(spacing: 10) {
                    subScoreBar(label: "Savings", score: hs.savingsScore)
                    subScoreBar(label: "Debt", score: hs.debtScore)
                    subScoreBar(label: "Investment", score: hs.investmentScore)
                    subScoreBar(label: "Emergency Fund", score: hs.emergencyFundScore)
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    /// A single horizontal sub-score bar: label, score value, progress bar.
    @ViewBuilder
    private func subScoreBar(label: String, score: Int) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                Spacer()
                Text("\(score)")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textPrimary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(WMColors.glassBorder)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(scoreColor(score))
                        .frame(width: geo.size.width * CGFloat(min(score, 100)) / 100, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - AI Analysis Card

    @ViewBuilder
    private var aiAnalysisCard: some View {
        if let narrative = viewModel.healthScore?.narrative, !narrative.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.spring()) {
                        showNarrative.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [WMColors.secondary, WMColors.secondary.opacity(0.3)],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 12
                                )
                            )
                            .frame(width: 24, height: 24)
                            .shadow(color: WMColors.secondary.opacity(0.5), radius: 6)

                        Text("AI Analysis")
                            .font(WMTypography.subheading)
                            .foregroundStyle(WMColors.textPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(WMColors.textMuted)
                            .rotationEffect(.degrees(showNarrative ? 90 : 0))
                    }
                }
                .buttonStyle(.plain)

                if showNarrative {
                    MarkdownText(text: narrative)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

    // MARK: - Net Worth Change Card

    private func netWorthChangeCard(briefing: CFOBriefingDTO) -> some View {
        let isPositive = briefing.netWorthChange >= 0
        let arrowIcon = isPositive ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill"
        let arrowColor = isPositive ? WMColors.positive : WMColors.negative

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Net Worth Change")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                CurrencyText(
                    amount: briefing.netWorthChange,
                    showSign: true,
                    font: WMTypography.heading
                )
            }

            Spacer()

            Image(systemName: arrowIcon)
                .font(.system(size: 28))
                .foregroundStyle(arrowColor)
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Summary Card

    private func summaryCard(briefing: CFOBriefingDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
            MarkdownText(text: briefing.summary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    // MARK: - Insights Section

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

    // MARK: - Goal Progress Card

    @ViewBuilder
    private func goalProgressCard(briefing: CFOBriefingDTO) -> some View {
        if !briefing.goalProgress.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Goal Progress")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)

                ForEach(Array(briefing.goalProgress.enumerated()), id: \.offset) { _, goal in
                    goalRow(goal: goal)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

    /// A single goal progress row with name, percentage, bar, and amounts.
    @ViewBuilder
    private func goalRow(goal: GoalProgressDTO) -> some View {
        let progress = goalProgress(current: goal.currentAmount, target: goal.targetAmount)
        let percentage = Int(progress * 100)

        VStack(spacing: 6) {
            HStack {
                Text(goal.goalName)
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
                Spacer()
                Text("\(percentage)%")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(WMColors.glassBorder)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(goalBarColor(percentage: percentage))
                        .frame(width: geo.size.width * CGFloat(min(progress, 1.0)), height: 6)
                }
            }
            .frame(height: 6)

            HStack(spacing: 4) {
                CurrencyText(amount: goal.currentAmount, font: WMTypography.caption)
                Text("of")
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
                CurrencyText(amount: goal.targetAmount, font: WMTypography.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Action Items Card

    private func actionItemsCard(briefing: CFOBriefingDTO) -> some View {
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
        .glassCard()
    }

    // MARK: - Error View

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

    // MARK: - Helpers

    /// Returns a color for a score value: green >= 80, amber 60-79, red < 60.
    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return WMColors.positive
        case 60..<80: return amber
        default: return WMColors.negative
        }
    }

    /// Returns a color for goal progress: green >= 75%, amber >= 40%, blue < 40%.
    private func goalBarColor(percentage: Int) -> Color {
        switch percentage {
        case 75...: return WMColors.positive
        case 40..<75: return amber
        default: return WMColors.primary
        }
    }

    /// Computes goal progress as a 0...1 Double, guarding against zero target.
    private func goalProgress(current: Decimal, target: Decimal) -> Double {
        guard target > 0 else { return 0 }
        let result = NSDecimalNumber(decimal: current)
            .dividing(by: NSDecimalNumber(decimal: target))
        return result.doubleValue
    }

    /// Loads briefing and health score in parallel, then triggers animations.
    private func loadAll() async {
        async let briefingLoad: () = viewModel.loadBriefing(period: selectedPeriod)
        async let scoreLoad: () = viewModel.loadHealthScore()
        _ = await (briefingLoad, scoreLoad)

        // Animate gauge to final score
        let score = viewModel.healthScore?.overallScore
            ?? viewModel.briefing?.healthScore
            ?? 0
        let targetProgress = Double(score) / 100.0

        if reduceMotion {
            animatedProgress = targetProgress
            hasAppeared = true
        } else {
            withAnimation(.spring(duration: 1.0)) {
                animatedProgress = targetProgress
            }
            withAnimation {
                hasAppeared = true
            }
        }
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
                    .font(WMTypography.body)
                    .foregroundStyle(WMColors.textPrimary)
                MarkdownText(
                    text: insight.detail,
                    bodyFont: WMTypography.caption,
                    bodyColor: WMColors.textMuted
                )
            }
            Spacer()
        }
        .padding(12)
        .glassCard(cornerRadius: 10)
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

// MARK: - StaggeredAppearance

/// Animates a view in with staggered delay based on index.
private struct StaggeredAppearance: ViewModifier {
    let index: Int
    let hasAppeared: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || hasAppeared ? 1 : 0)
            .offset(y: reduceMotion || hasAppeared ? 0 : 20)
            .animation(
                reduceMotion
                    ? .none
                    : .spring().delay(Double(index) * 0.08),
                value: hasAppeared
            )
    }
}

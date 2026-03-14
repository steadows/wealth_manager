import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

/// Provides timeline entries for the Health Score widget.
struct HealthScoreTimelineProvider: TimelineProvider {
    private let store: WidgetDataStoreProtocol

    init(store: WidgetDataStoreProtocol = AppGroupWidgetDataStore()) {
        self.store = store
    }

    func placeholder(in context: Context) -> HealthScoreWidgetEntry {
        HealthScoreWidgetEntry(
            date: Date(),
            data: HealthScoreWidgetData(
                overallScore: 82,
                scoreLabel: "Great",
                lastUpdated: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthScoreWidgetEntry) -> Void) {
        let entry = HealthScoreWidgetEntry(
            date: Date(),
            data: store.loadHealthScoreData()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthScoreWidgetEntry>) -> Void) {
        let entry = HealthScoreWidgetEntry(
            date: Date(),
            data: store.loadHealthScoreData()
        )
        // Refresh every hour (health score changes infrequently)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Score Ring View

/// Circular gauge view showing the health score with gradient ring.
struct ScoreRingView: View {
    let score: Int
    let scoreFraction: Double
    var size: CGFloat = 80

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 8)

            // Score arc
            Circle()
                .trim(from: 0, to: scoreFraction)
                .stroke(
                    scoreGradient,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: scoreFraction)

            // Score number
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("/ 100")
                    .font(.system(size: size * 0.12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
    }

    /// Gradient color based on score tier.
    private var scoreGradient: AngularGradient {
        let colors: [Color] = switch score {
        case 90...100:
            [Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255),
             Color(red: 6 / 255, green: 182 / 255, blue: 212 / 255)]
        case 75..<90:
            [Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
             Color(red: 6 / 255, green: 182 / 255, blue: 212 / 255)]
        case 60..<75:
            [Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
             Color(red: 20 / 255, green: 184 / 255, blue: 166 / 255)]
        case 40..<60:
            [Color.orange, Color.yellow]
        default:
            [Color.red, Color.orange]
        }
        return AngularGradient(colors: colors, center: .center)
    }
}

// MARK: - Widget View

/// Small widget showing financial health score as a ring/gauge.
struct HealthScoreWidgetView: View {
    let entry: HealthScoreWidgetEntry

    var body: some View {
        if let data = entry.data {
            VStack(spacing: 6) {
                Text("HEALTH SCORE")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.6))

                ScoreRingView(
                    score: data.overallScore,
                    scoreFraction: data.scoreFraction,
                    size: 72
                )

                Text(data.scoreLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(tierColor(for: data.overallScore))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 8)
            .widgetBackground()
        } else {
            emptyStateView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.text.square")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.4))
            Text("Open app to\nload data")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .widgetBackground()
    }

    /// Returns the accent color for a given score tier.
    private func tierColor(for score: Int) -> Color {
        switch score {
        case 90...100:
            Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255)
        case 75..<90:
            Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
        case 60..<75:
            Color(red: 20 / 255, green: 184 / 255, blue: 166 / 255)
        case 40..<60:
            Color.orange
        default:
            Color.red
        }
    }
}

// MARK: - Widget Definition

/// Small WidgetKit widget displaying financial health score as a ring gauge.
struct HealthScoreWidget: Widget {
    let kind: String = "HealthScoreWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HealthScoreTimelineProvider()) { entry in
            HealthScoreWidgetView(entry: entry)
        }
        .configurationDisplayName("Health Score")
        .description("Shows your financial health score at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget Background Modifier

private extension View {
    /// Applies the Holographic JARVIS dark background for widgets.
    func widgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, *) {
            return self.containerBackground(for: .widget) {
                LinearGradient(
                    colors: [
                        Color(red: 7 / 255, green: 11 / 255, blue: 20 / 255),
                        Color(red: 12 / 255, green: 18 / 255, blue: 32 / 255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        } else {
            return self.background(
                LinearGradient(
                    colors: [
                        Color(red: 7 / 255, green: 11 / 255, blue: 20 / 255),
                        Color(red: 12 / 255, green: 18 / 255, blue: 32 / 255)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    HealthScoreWidget()
} timeline: {
    HealthScoreWidgetEntry(
        date: Date(),
        data: HealthScoreWidgetData(
            overallScore: 85,
            scoreLabel: "Great",
            lastUpdated: Date()
        )
    )
    HealthScoreWidgetEntry(
        date: Date(),
        data: nil
    )
}

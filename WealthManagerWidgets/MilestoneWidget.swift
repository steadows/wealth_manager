import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

/// Provides timeline entries for the Next Milestone widget.
struct MilestoneTimelineProvider: TimelineProvider {
    private let store: WidgetDataStoreProtocol

    init(store: WidgetDataStoreProtocol = AppGroupWidgetDataStore()) {
        self.store = store
    }

    func placeholder(in context: Context) -> MilestoneWidgetEntry {
        MilestoneWidgetEntry(
            date: Date(),
            data: MilestoneWidgetData(
                goalName: "Emergency Fund",
                goalTypeRawValue: "emergencyFund",
                targetAmount: "20000",
                currentAmount: "14500",
                progressPercent: "0.725",
                targetDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
                lastUpdated: Date()
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (MilestoneWidgetEntry) -> Void) {
        let entry = MilestoneWidgetEntry(
            date: Date(),
            data: store.loadMilestoneData()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MilestoneWidgetEntry>) -> Void) {
        let entry = MilestoneWidgetEntry(
            date: Date(),
            data: store.loadMilestoneData()
        )
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View

/// Medium widget showing the closest goal with progress bar.
struct MilestoneWidgetView: View {
    let entry: MilestoneWidgetEntry

    var body: some View {
        if let data = entry.data {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: goalIcon(for: data.goalTypeRawValue))
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
                                    Color(red: 6 / 255, green: 182 / 255, blue: 212 / 255)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEXT MILESTONE")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.6))

                        Text(data.goalName)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(formattedPercent(data.progressDouble))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
                        )
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 8)

                        // Fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
                                        Color(red: 6 / 255, green: 182 / 255, blue: 212 / 255)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(geometry.size.width * data.progressDouble, 4),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)

                // Amount details
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saved")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        Text(formattedCurrency(data.currentAmountDecimal))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Remaining")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        Text(formattedCurrency(data.remainingDecimal))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if let targetDate = data.targetDate {
                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Target")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.5))
                            Text(formattedDate(targetDate))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
            .padding()
            .widgetBackground()
        } else {
            emptyStateView
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "flag.checkered")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.4))
            Text("No active goals.\nOpen app to set one.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .widgetBackground()
    }

    // MARK: - Helpers

    /// Maps goal type raw values to SF Symbol names.
    private func goalIcon(for rawValue: String) -> String {
        switch rawValue {
        case "retirement": return "sunset.fill"
        case "emergencyFund": return "shield.fill"
        case "homePurchase": return "house.fill"
        case "debtPayoff": return "creditcard.fill"
        case "education": return "graduationcap.fill"
        case "travel": return "airplane"
        case "investment": return "chart.line.uptrend.xyaxis"
        default: return "star.fill"
        }
    }

    private func formattedCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: value as NSDecimalNumber) ?? "$0"
    }

    private func formattedPercent(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Widget Definition

/// Medium WidgetKit widget showing closest goal and progress bar.
struct MilestoneWidget: Widget {
    let kind: String = "MilestoneWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MilestoneTimelineProvider()) { entry in
            MilestoneWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Milestone")
        .description("Shows your closest financial goal and progress.")
        .supportedFamilies([.systemMedium])
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

#Preview(as: .systemMedium) {
    MilestoneWidget()
} timeline: {
    MilestoneWidgetEntry(
        date: Date(),
        data: MilestoneWidgetData(
            goalName: "Emergency Fund",
            goalTypeRawValue: "emergencyFund",
            targetAmount: "20000",
            currentAmount: "14500",
            progressPercent: "0.725",
            targetDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
            lastUpdated: Date()
        )
    )
    MilestoneWidgetEntry(
        date: Date(),
        data: nil
    )
}
